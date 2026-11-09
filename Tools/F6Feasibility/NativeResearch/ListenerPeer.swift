import Foundation
import Network
import os

final class ListenerPeer: Sendable {
    struct State: Sendable { var pending: [Int: ResearchFlow] = [:]; var deliveries = 0; var rejected = 0; var closed = false }
    let listener: NWListener
    let registry: LeaseRegistry
    let state = OSAllocatedUnfairLock(initialState: State())
    let arrival = Once<Int>()
    let ready = Once<UInt16>()
    let queue = DispatchQueue(label:"f6.179.tcp")
    let budget = FlowBudget()
    init(interface: NWInterface? = nil) throws {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host:"127.0.0.1",port:.any)
        if let interface { parameters.requiredInterface = interface }
        let listener = try NWListener(using:parameters,on:.any)
        self.listener = listener
        registry = LeaseRegistry(maximum:1,onCapacity:{ [weak listener] credit in listener?.newConnectionLimit = credit })
        listener.newConnectionLimit = 1
        listener.stateUpdateHandler = { [ready, weak listener] status in
            if case .ready = status, let port = listener?.port { ready.resolve(.success(port.rawValue)) }
            if case .failed(let e) = status { ready.resolve(.failure(e)) }
            if case .cancelled = status { ready.resolve(.failure(ProbeFailure.cancelled)) }
        }
        listener.newConnectionHandler = { [state,registry,arrival,queue,budget] connection in
            do {
                let id = try registry.reserve()
                let lease = Lease(registry,id)
                let flow = try ResearchFlow(connection,budget:budget,lease:lease)
                let admitted = state.withLock { s -> Bool in
                    guard !s.closed else { return false }
                    s.deliveries += 1; s.pending[id] = flow; return true
                }
                if !admitted { flow.close(); return }
                flow.start(on:queue); arrival.resolve(.success(id))
            } catch {
                state.withLock { $0.rejected += 1 }; connection.cancel()
            }
        }
    }
    func start() async throws -> UInt16 {
        listener.start(queue:queue)
        return try await bounded(3,cancel:{ [listener,ready] in listener.cancel(); ready.resolve(.failure(ProbeFailure.timeout)) }) { [ready] in try await ready.value() }
    }
    func accept() async throws -> ResearchFlow {
        let id = try await bounded(3,cancel:{ [arrival] in arrival.resolve(.failure(ProbeFailure.timeout)) }) { [arrival] in try await arrival.value() }
        guard let flow = state.withLock({ $0.pending[id] }) else { throw ProbeFailure.failed("no-pending") }
        try await flow.waitReady(); try registry.handoff(id)
        _ = state.withLock { $0.pending.removeValue(forKey:id) }
        return flow
    }
    func stop() {
        registry.stop()
        let flows = state.withLock { s in s.closed = true; let all = Array(s.pending.values); s.pending.removeAll(); return all }
        flows.forEach { $0.close() }; listener.cancel(); arrival.resolve(.failure(ProbeFailure.cancelled))
    }
    deinit { stop() }
}

func tcpCase(_ id: String, observedInterface: NWInterface?) async throws -> (ResearchReport,NWInterface?) {
    if id == "N06" && observedInterface == nil { throw ProbeFailure.failed("no-N01-loopback-interface-evidence") }
    let peer = try ListenerPeer(interface:id == "N06" ? observedInterface : nil)
    defer { peer.stop() }
    let port = try await peer.start()
    let queue = DispatchQueue(label:"f6.179.client")
    let connection = NWConnection(host:"127.0.0.1",port:NWEndpoint.Port(rawValue:port)!,using:.tcp)
    let client = try ResearchFlow(connection,budget:FlowBudget()); client.start(on:queue)
    defer { client.close() }; try await client.waitReady()
    var interface = observedInterface
    if id == "N01" { interface = connection.currentPath?.availableInterfaces.first { $0.type == .loopback } }
    var report = ResearchReport(id:id)
    if id == "N02" {
        _ = try await peer.arrival.value()
        let second = try ResearchFlow(NWConnection(host:"127.0.0.1",port:NWEndpoint.Port(rawValue:port)!,using:.tcp),budget:FlowBudget())
        second.start(on:queue); defer { second.close() }
        do { try await second.waitReady(0.5); report.observations["secondNativeReady"] = "true" }
        catch ProbeFailure.timeout { report.observations["secondNativeReady"] = "queued/timeout" }
        let counts = peer.registry.state.withLock { ($0.active.count,$0.pending.count) }
        try assertion(counts.0 == 1 && counts.1 == 1,"capacity-bypassed")
        try assertion(peer.state.withLock { $0.deliveries } == 1 && peer.listener.newConnectionLimit == 0,"native-credit")
        report.observations["activeLeases"] = "\(counts.0)"; report.observations["nativeRemainingCredit"] = "0"
    } else if id == "N03" {
        _ = try await peer.arrival.value(); peer.stop()
        do { _ = try await peer.accept(); throw ProbeFailure.failed("stopped-handoff") }
        catch ProbeFailure.cancelled {} catch ProbeFailure.failed(let label) { try assertion(label == "no-pending","wrong-stop-error") }
        try assertion(peer.registry.state.withLock { $0.active.isEmpty },"pending-lease-leak")
        report.observations["unhandedLeaseReleased"] = "true"
    } else if id == "N05" {
        var accepted: ResearchFlow? = try await peer.accept()
        weak let weakAccepted = accepted
        accepted = nil
        try assertion(weakAccepted == nil && peer.registry.state.withLock { $0.active.isEmpty },"registry-retain-cycle")
        report.observations["wrapperReleased"] = "true"
    } else {
        let accepted = try await peer.accept(); defer { accepted.close() }
        if id == "N04" { peer.stop() }
        try await client.send(Data("ping".utf8)); let incoming = try await accepted.read(4)
        try assertion(incoming == Data("ping".utf8),"tcp-payload")
        try await accepted.send(Data("pong".utf8)); let reply = try await client.read(4)
        try assertion(reply == Data("pong".utf8),"tcp-reply")
        accepted.close()
        try assertion(peer.registry.state.withLock { $0.active.isEmpty },"lease-release")
        report.observations["handoffExchange"] = "true"
        if id == "N01" { report.observations["loopbackInterfaceObserved"] = String(interface != nil) }
        if id == "N06" { try assertion(connection.currentPath?.usesInterfaceType(.loopback) == true,"loopback-path"); report.observations["requiredInterfaceApplied"] = "true" }
    }
    report.observations["nativeDeliveries"] = String(peer.state.withLock { $0.deliveries })
    report.observations["leaseReleases"] = String(peer.registry.state.withLock { $0.releases })
    return (report,interface)
}
