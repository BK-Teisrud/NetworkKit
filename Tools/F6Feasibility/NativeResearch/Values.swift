import Foundation
import Network
import os

struct ResearchReport: Codable, Sendable {
    let id: String
    var status = "pass"
    var observations: [String: String] = [:]
}
func assertion(_ value: @autoclosure () -> Bool, _ label: String) throws {
    if !value() { throw ProbeFailure.failed(label) }
}
func rejected(_ operation: () throws -> Void) throws {
    do { try operation() } catch { return }; throw ProbeFailure.failed("expected-rejection")
}

/// Pure policy model: bounded complete snapshots, no native browser or discovery.
final class BrowserModel {
    var records: [String: UUID] = [:]
    var revision: UInt64 = 0
    var stopped = false
    var waiter = false
    var transferred = false
    func update(_ names: [String], txtBytes: Int = 0) throws {
        guard !stopped else { throw ProbeFailure.failed("stopped") }
        guard names.count <= 2 && txtBytes <= 8 && revision < .max else {
            stopped = true; throw ProbeFailure.failed("limit")
        }
        records = Dictionary(uniqueKeysWithValues: names.map { ($0, records[$0] ?? UUID()) })
        revision += 1; waiter = false
    }
    func endpoint(_ name: String) throws -> UUID {
        guard !stopped, let id = records[name] else { throw ProbeFailure.failed("stale") }; return id
    }
    func wait(after: UInt64) throws {
        guard !stopped && after <= revision && !waiter else { throw ProbeFailure.failed("cursor/waiter") }
        if after == revision { waiter = true }
    }
    func stop() { stopped = true; waiter = false; records.removeAll() }
}

/// Leases count all SDK-owned states, independently of native remaining credits.
final class LeaseRegistry: Sendable {
    struct State: Sendable {
        var closed = false; var next = 0; var active: Set<Int> = []; var pending: Set<Int> = []
        var rearms = 0; var releases = 0
    }
    let state = OSAllocatedUnfairLock(initialState: State())
    let maximum: Int
    let onCapacity: (@Sendable (Int) -> Void)?
    init(maximum: Int = 1, onCapacity: (@Sendable (Int) -> Void)? = nil) { self.maximum = maximum; self.onCapacity = onCapacity }
    func reserve() throws -> Int {
        try state.withLock { s in
            guard !s.closed && s.active.count < maximum else { throw ProbeFailure.failed("capacity") }
            s.next += 1; s.active.insert(s.next); s.pending.insert(s.next); return s.next
        }
    }
    func handoff(_ id: Int) throws {
        try state.withLock { s in
            guard !s.closed && s.pending.remove(id) != nil else { throw ProbeFailure.failed("handoff") }
        }
    }
    func release(_ id: Int) {
        let credit = state.withLock { s -> Int? in
            if s.active.remove(id) != nil {
                s.pending.remove(id); s.releases += 1
                if !s.closed { s.rearms += 1; return maximum - s.active.count }
            }
            return nil
        }
        if let credit { onCapacity?(credit) }
    }
    func stop() { state.withLock { $0.closed = true } }
}
final class Lease: Sendable {
    let registry: LeaseRegistry; let id: Int
    init(_ registry: LeaseRegistry, _ id: Int) { self.registry = registry; self.id = id }
    func release() { registry.release(id) }
    deinit { registry.release(id) }
}
struct DatagramModel {
    var queue: [Data] = []; var dropped: UInt64 = 0; var saturated = false
    mutating func discard() { if dropped == .max { saturated = true } else { dropped += 1 } }
    mutating func push(_ bytes: Data) {
        guard bytes.count <= 8 && queue.count < 1 else { discard(); return }; queue.append(bytes)
    }
    mutating func take() -> (Data, UInt64)? {
        guard !queue.isEmpty else { return nil }; let value = queue.removeFirst(); let count = dropped; dropped = 0; return (value,count)
    }
}
struct QUICModel {
    var active: Set<Int> = []; var pending: Set<Int> = []; var closed = false
    var datagramFlow = false; var senderBusy = false
    var waiters: [Int: Once<Bool>] = [:]
    var sideEffects = 0
    mutating func stream(_ id: Int, pending: Bool = false) throws {
        guard !closed && active.count < 2 else { throw ProbeFailure.failed("streams") }
        active.insert(id); waiters[id] = Once<Bool>(); if pending { self.pending.insert(id) }
    }
    mutating func closeStream(_ id: Int) { active.remove(id); pending.remove(id); waiters[id]?.resolve(.failure(ProbeFailure.cancelled)) }
    mutating func close() { closed = true; active.removeAll(); pending.removeAll(); waiters.values.forEach { $0.resolve(.failure(ProbeFailure.cancelled)) } }
    mutating func operation(role: String, send: Bool) throws {
        try assertion(!(role == "receiveOnly" && send) && !(role == "sendOnly" && !send),"direction")
        sideEffects += 1
    }
    mutating func datagram() throws {
        guard !closed && !datagramFlow else { throw ProbeFailure.failed("datagram-flow") }; datagramFlow = true
    }
    mutating func send() throws {
        guard !senderBusy else { throw ProbeFailure.failed("duplicate") }; senderBusy = true
    }
}
