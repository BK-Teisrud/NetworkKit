import Foundation
import Network
import os

/// Bounds framework callbacks retained by this experiment; not an OS memory census.
final class FlowBudget: Sendable {
    struct State: Sendable { var contexts = 0; var contextAttempts = 0; var sends = 0; var sent = 0; var received = 0 }
    let state = OSAllocatedUnfairLock(initialState: State())
    func context() throws { try state.withLock { s in s.contextAttempts += 1; try assertion(s.contexts < 4,"flow-limit"); s.contexts += 1 } }
    func send(_ count: Int) throws {
        try state.withLock { s in try assertion(s.sends < 16 && s.sent + count <= 65536,"send-budget"); s.sends += 1; s.sent += count }
    }
    func receive(_ count: Int) throws { try state.withLock { s in try assertion(s.received + count <= 65536,"receive-budget"); s.received += count } }
}
final class ResearchFlow: Sendable {
    let connection: NWConnection
    let ready = Once<Bool>()
    let budget: FlowBudget
    let lease: Lease?
    let datagram: Bool
    let sendOnly: Bool
    let receiveStarted = Once<Bool>()
    let lastReceive = OSAllocatedUnfairLock<Once<Data>?>(initialState: nil)
    private struct Pending: Sendable { var closed = false; var sends: [Once<Bool>] = []; var receives: [Once<Data>] = [] }
    private let pending = OSAllocatedUnfairLock(initialState: Pending())
    init(_ connection: NWConnection, budget: FlowBudget, lease: Lease? = nil, datagram: Bool = false, sendOnly: Bool = false) throws {
        self.connection = connection; self.budget = budget; self.lease = lease; self.datagram = datagram; self.sendOnly = sendOnly
        try budget.context()
    }
    deinit { close() }
    func start(on queue: DispatchQueue) {
        connection.stateUpdateHandler = { [ready, lease] state in
            switch state {
            case .ready: ready.resolve(.success(true))
            case .failed(let e): ready.resolve(.failure(e)); lease?.release()
            case .cancelled: ready.resolve(.failure(ProbeFailure.cancelled)); lease?.release()
            default: break
            }
        }
        connection.start(queue: queue)
    }
    func waitReady(_ seconds: Double = 3) async throws {
        _ = try await bounded(seconds,cancel:{ [connection,ready] in connection.cancel(); ready.resolve(.failure(ProbeFailure.timeout)) }) { [ready] in try await ready.value() }
    }
    func send(_ bytes: Data) async throws {
        let done = Once<Bool>()
        try pending.withLock { s in try assertion(!s.closed && s.sends.isEmpty,"closed/duplicate-send"); s.sends.append(done) }
        defer { pending.withLock { $0.sends.removeAll { $0 === done } } }
        try budget.send(bytes.count)
        connection.send(content:bytes,contentContext:.defaultMessage,isComplete:true,completion:.contentProcessed { error in
            if let error { done.resolve(.failure(error)) } else { done.resolve(.success(true)) }
        })
        _ = try await bounded(3,cancel:{ [connection] in connection.cancel(); done.resolve(.failure(ProbeFailure.timeout)) }) { try await done.value() }
    }
    func receive() async throws -> Data {
        try assertion(!sendOnly,"send-only-receive")
        let done = Once<Data>(); lastReceive.withLock { $0 = done }
        try pending.withLock { s in try assertion(!s.closed && s.receives.isEmpty,"closed/duplicate-receive"); s.receives.append(done) }
        defer { pending.withLock { $0.receives.removeAll { $0 === done } } }
        let callback: @Sendable (Data?,NWConnection.ContentContext?,Bool,NWError?) -> Void = { [budget,datagram] bytes,context,complete,error in
            if let error { done.resolve(.failure(error)); return }
            if datagram && (!complete || context == nil) { done.resolve(.failure(ProbeFailure.failed("incomplete-datagram"))); return }
            let bytes = bytes ?? Data()
            do { try budget.receive(bytes.count); done.resolve(.success(bytes)) } catch { done.resolve(.failure(error)) }
        }
        if datagram { connection.receiveMessage(completion:callback) }
        else { connection.receive(minimumIncompleteLength:1,maximumLength:65536,completion:callback) }
        receiveStarted.resolve(.success(true))
        return try await bounded(3,cancel:{ [connection] in connection.cancel(); done.resolve(.failure(ProbeFailure.timeout)) }) { try await done.value() }
    }
    func read(_ count: Int) async throws -> Data {
        var bytes = Data()
        for _ in 0..<16 { let part = try await receive(); bytes.append(part); if bytes.count >= count || part.isEmpty { return bytes } }
        throw ProbeFailure.failed("bounded-read-count")
    }
    func close() {
        let work = pending.withLock { s in
            s.closed = true; let all = (s.sends,s.receives); s.sends.removeAll(); s.receives.removeAll(); return all
        }
        work.0.forEach { $0.resolve(.failure(ProbeFailure.cancelled)) }
        work.1.forEach { $0.resolve(.failure(ProbeFailure.cancelled)) }
        ready.resolve(.failure(ProbeFailure.cancelled)); connection.cancel(); lease?.release()
    }
    var streamID: UInt64? { (connection.metadata(definition:NWProtocolQUIC.definition) as? NWProtocolQUIC.Metadata)?.streamIdentifier }
    var alpn: String { (connection.metadata(definition:NWProtocolQUIC.definition) as? NWProtocolQUIC.Metadata)?.negotiatedALPN ?? "unavailable" }
}

final class FlowInbox: Sendable {
    struct State: Sendable { var queue: [ResearchFlow] = []; var waiter: Once<ResearchFlow>?; var closed = false }
    let state = OSAllocatedUnfairLock(initialState: State())
    func push(_ flow: ResearchFlow) {
        let action = state.withLock { s -> (Once<ResearchFlow>?,Bool) in
            guard !s.closed && s.queue.count < 4 else { return (nil,false) }
            if let waiter = s.waiter { s.waiter = nil; return (waiter,true) }
            s.queue.append(flow); return (nil,true)
        }
        if !action.1 { flow.close() }; action.0?.resolve(.success(flow))
    }
    func take() async throws -> ResearchFlow {
        let waiter = Once<ResearchFlow>()
        let immediate = try state.withLock { s -> ResearchFlow? in
            guard !s.closed && s.waiter == nil else { throw ProbeFailure.failed("inbox-closed/duplicate") }
            if !s.queue.isEmpty { return s.queue.removeFirst() }
            s.waiter = waiter; return nil
        }
        if let immediate { return immediate }
        return try await bounded(3,cancel:{ [state] in
            let old = state.withLock { s -> Once<ResearchFlow>? in let old = s.waiter; s.waiter = nil; return old }
            old?.resolve(.failure(ProbeFailure.timeout))
        }) { try await waiter.value() }
    }
    func close() {
        let (flows,waiter) = state.withLock { s in
            s.closed = true; let flows = s.queue; let waiter = s.waiter; s.queue.removeAll(); s.waiter = nil; return (flows,waiter)
        }
        flows.forEach { $0.close() }; waiter?.resolve(.failure(ProbeFailure.cancelled))
    }
}
