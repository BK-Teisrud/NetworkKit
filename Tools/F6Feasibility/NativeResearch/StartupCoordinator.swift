import Foundation
import os

/// Isolated experiment: the callback owner survives connection handoff.
final class StartupCoordinator: Sendable {
    enum Outcome: String, Error, Sendable { case admitted, trustRejected, alpnRejected, missingALPN, contextMismatch, transport, timeout, cancelled, handlerLimit }
    typealias Reply = @Sendable (Bool) -> Void
    struct Snapshot: Sendable {
        let phase: String; let registered: Int; let completed: Int; let pending: Int
        let accepted: Int; let rejected: Int; let ignoredLate: Int; let handoffs: Int; let data: Int; let stops: Int
    }
    private struct State: Sendable {
        var phase = "preparing"; var ready = false; var trusted = false
        var registered = 0; var completed = 0; var accepted = 0; var rejected = 0; var ignored = 0
        var handoffs = 0; var data = 0; var stops = 0
        var handlers: [Int:Reply] = [:]; var stop: (@Sendable () -> Void)?
    }
    private struct Actions: Sendable { var replies: [(Reply,Bool)] = []; var outcome: Outcome?; var stop: (@Sendable () -> Void)? }
    private let state = OSAllocatedUnfairLock(initialState:State())
    let context: UUID
    let alpn: String
    private let deadline: ContinuousClock.Instant?
    private var expired: Bool { deadline.map { ContinuousClock.now >= $0 } ?? false }
    let result = Once<Outcome>()
    init(context: UUID = UUID(), alpn: String = researchALPN, timeout: Double? = nil) { self.context = context; self.alpn = alpn; self.deadline = timeout.map { ContinuousClock.now.advanced(by:.seconds($0)) } }
    private static func seal(_ s: inout State, _ outcome: Outcome) -> Actions {
        guard s.phase != "terminal" else { return Actions() }
        let preparing = s.phase == "preparing"; s.phase = "terminal"
        let replies = s.handlers.values.map { ($0,false) }; s.completed += replies.count; s.rejected += replies.count; s.handlers.removeAll()
        let stop = s.stop; s.stop = nil; if stop != nil { s.stops += 1 }
        return Actions(replies:replies,outcome:preparing ? outcome : nil,stop:stop)
    }
    private static func admit(_ s: inout State) -> Outcome? {
        guard s.phase == "preparing", s.ready, s.trusted, s.handlers.isEmpty else { return nil }
        s.phase = "admitted"; s.handoffs += 1; return .admitted
    }
    private func dispatch(_ action: Actions) {
        // Logical ownership is decided under the lock; callbacks run outside it.
        action.replies.forEach { $0.0($0.1) }; action.stop?()
        if let outcome = action.outcome { result.resolve(.success(outcome)) }
    }
    func setStop(_ stop: @escaping @Sendable () -> Void) {
        let immediate = state.withLock { s in
            if s.phase == "terminal" { s.stops += 1; return true }
            s.stop = stop; return false
        }
        if immediate { stop() }
    }
    func admitNativeWork() -> Bool {
        let (allowed,action) = state.withLock { s -> (Bool,Actions) in
            if s.phase == "preparing" && expired { return (false,Self.seal(&s,.timeout)) }
            return (s.phase == "preparing",Actions())
        }
        dispatch(action); return allowed
    }
    func register(context: UUID, reply: @escaping Reply) -> Int? {
        let (token,action) = state.withLock { s -> (Int?,Actions) in
            s.registered += 1
            if s.phase == "terminal" {
                s.completed += 1; s.rejected += 1; return (nil,Actions(replies:[(reply,false)]))
            }
            if s.phase == "preparing" && expired {
                var action = Self.seal(&s,.timeout); s.completed += 1; s.rejected += 1
                action.replies.append((reply,false)); return (nil,action)
            }
            if s.registered > 4 || context != self.context {
                var action = Self.seal(&s,context != self.context ? .contextMismatch : .handlerLimit)
                s.completed += 1; s.rejected += 1; action.replies.append((reply,false)); return (nil,action)
            }
            s.handlers[s.registered] = reply; return (s.registered,Actions())
        }
        dispatch(action); return token
    }
    func evaluated(_ token: Int, valid: Bool) {
        let action = state.withLock { s -> Actions in
            if s.phase == "preparing" && expired { return Self.seal(&s,.timeout) }
            guard let reply = s.handlers.removeValue(forKey:token) else { s.ignored += 1; return Actions() }
            s.completed += 1
            if !valid {
                s.rejected += 1; var action = Self.seal(&s,.trustRejected); action.replies.insert((reply,false),at:0); return action
            }
            s.accepted += 1; s.trusted = true
            return Actions(replies:[(reply,true)],outcome:Self.admit(&s))
        }
        dispatch(action)
    }
    func nativeReady(alpn: String?) {
        let action = state.withLock { s -> Actions in
            guard s.phase == "preparing" else { return Actions() }
            if expired { return Self.seal(&s,.timeout) }
            guard let alpn else { return Self.seal(&s,.missingALPN) }
            guard alpn == self.alpn else { return Self.seal(&s,.alpnRejected) }
            s.ready = true; return Actions(outcome:Self.admit(&s))
        }
        dispatch(action)
    }
    func expireStartup() { dispatch(state.withLock { s in s.phase == "preparing" ? Self.seal(&s,.timeout) : Actions() }) }
    func terminate(_ outcome: Outcome) { dispatch(state.withLock { Self.seal(&$0,outcome) }) }
    func admitData() -> Bool { state.withLock { s in guard s.phase == "admitted" else { return false }; s.data += 1; return true } }
    var snapshot: Snapshot { state.withLock { s in Snapshot(phase:s.phase,registered:s.registered,completed:s.completed,pending:s.handlers.count,accepted:s.accepted,rejected:s.rejected,ignoredLate:s.ignored,handoffs:s.handoffs,data:s.data,stops:s.stops) } }
}

final class StartupWitness: Sendable {
    struct State: Sendable { var replies = 0; var trueReplies = 0; var stops = 0; var work = 0 }
    let state = OSAllocatedUnfairLock(initialState:State())
    func reply(_ valid: Bool) { state.withLock { $0.replies += 1; if valid { $0.trueReplies += 1 } } }
}

func startupPure(_ id: String) async throws -> ResearchReport {
    let gate = StartupCoordinator(); let witness = StartupWitness()
    gate.setStop { witness.state.withLock { $0.stops += 1 } }
    func register(_ context: UUID? = nil) -> Int? { gate.register(context:context ?? gate.context) { witness.reply($0) } }
    switch id {
    case "L01":
        gate.terminate(.cancelled); if gate.admitNativeWork() { witness.state.withLock { $0.work += 1 } }
        try assertion(witness.state.withLock { $0.work == 0 },"cancelled-work")
    case "L02":
        gate.nativeReady(alpn:researchALPN); try assertion(gate.snapshot.handoffs == 0 && gate.result.resolutionCount == 0,"ready-alone"); gate.terminate(.cancelled)
    case "L03":
        let token = register()!; gate.nativeReady(alpn:researchALPN); gate.evaluated(token,valid:true); gate.nativeReady(alpn:researchALPN)
        try assertion(gate.snapshot.handoffs == 1 && witness.state.withLock { $0.trueReplies == 1 },"positive-handoff")
    case "L04":
        let token = register()!; gate.evaluated(token,valid:false); gate.nativeReady(alpn:researchALPN)
        try assertion(gate.snapshot.handoffs == 0 && !gate.admitData(),"rejection-ready")
    case "L05":
        _ = register(); _ = register(); gate.terminate(.timeout)
        let out = try await gate.result.value(); try assertion(out == .timeout && witness.state.withLock { $0.replies == 2 && $0.trueReplies == 0 },"timeout-drain")
    case "L06":
        let token = register()!; gate.terminate(.cancelled); gate.evaluated(token,valid:true); gate.nativeReady(alpn:researchALPN)
        try assertion(gate.snapshot.handoffs == 0 && gate.snapshot.ignoredLate == 1,"late-revival")
    case "L07": gate.nativeReady(alpn:"wrong"); let out = try await gate.result.value(); try assertion(out == .alpnRejected,"mismatch")
    case "L08": gate.nativeReady(alpn:nil); let out = try await gate.result.value(); try assertion(out == .missingALPN,"missing")
    case "L09":
        gate.terminate(.transport); let absent = StartupCoordinator(); absent.terminate(.timeout)
        let a = try await gate.result.value(), b = try await absent.result.value(); try assertion(a == .transport && b == .timeout,"honest-errors")
    case "L10":
        let token = register()!; gate.terminate(.cancelled); gate.evaluated(token,valid:true)
        try assertion(witness.state.withLock { $0.replies == 1 && $0.trueReplies == 0 } && gate.snapshot.pending == 0,"late-reply")
    case "L11":
        try assertion(register(UUID()) == nil,"foreign-context"); gate.nativeReady(alpn:researchALPN)
        try assertion(gate.snapshot.handoffs == 0 && witness.state.withLock { $0.trueReplies == 0 },"borrowed-trust")
    case "L12":
        let token = register()!; gate.evaluated(token,valid:true); gate.nativeReady(alpn:researchALPN)
        let later = register()!; gate.evaluated(later,valid:false)
        try assertion(gate.snapshot.handoffs == 1 && gate.snapshot.phase == "terminal" && witness.state.withLock { $0.replies == 2 && $0.trueReplies == 1 && $0.stops == 1 },"post-handoff-owner")
    default: throw ProbeFailure.failed("pure-input")
    }
    try assertion(gate.result.resolutionCount == 1 && gate.snapshot.pending == 0,"terminal-count")
    return ResearchReport(id:id,observations:["evidence":"actual Swift coordinator, fixed schedule","callerResults":String(gate.result.resolutionCount),"callbackReplies":String(witness.state.withLock { $0.replies })])
}
