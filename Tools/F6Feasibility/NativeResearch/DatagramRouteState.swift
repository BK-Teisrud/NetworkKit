import Foundation
import Network
import Security
import os

enum DatagramRouteMode: Sendable { case directDatagram, stream }
final class DatagramRouteState: Sendable {
    let mode: DatagramRouteMode
    private let lock = OSAllocatedUnfairLock(initialState:0)
    init(mode: DatagramRouteMode = .directDatagram) { self.mode = mode }
    func validateMode(_ selected: DatagramRouteMode) throws { try assertion(selected == mode && selected == .directDatagram,"mode-mismatch-no-fallback") }
    func reserveDatagram() throws { try lock.withLock { count in try assertion(count == 0,"one-datagram-flow"); count += 1 } }
    func message(_ bytes: Data?, complete: Bool, context: Bool, capacity: Int) throws -> Data {
        guard let bytes, complete, context, capacity > 0, bytes.count <= capacity else { throw ProbeFailure.failed("invalid-or-missing-datagram") }
        return bytes
    }
}
func datagramPure(_ id: String) throws -> ResearchReport {
    let state = DatagramRouteState()
    switch id {
    case "R01":
        try rejected { _ = try state.message(nil,complete:true,context:true,capacity:8) }
        let empty = try state.message(Data(),complete:true,context:true,capacity:8); try assertion(empty.isEmpty,"explicit-empty")
    case "R02": try rejected { try state.validateMode(.stream) }; try state.validateMode(.directDatagram)
    case "R03": try state.reserveDatagram(); try rejected { try state.reserveDatagram() }
    case "R04":
        let bytes = Data([1,2])
        try rejected { _ = try state.message(bytes,complete:false,context:true,capacity:8) }
        try rejected { _ = try state.message(bytes,complete:true,context:true,capacity:0) }
        try rejected { _ = try state.message(bytes,complete:true,context:true,capacity:1) }
    default: throw ProbeFailure.failed("pure-id")
    }
    return ResearchReport(id:id,observations:["evidence":"actual route-state fixed input, not native delivery"])
}

/// Same narrow C completion ownership boundary as the startup experiment.
final class DatagramVerifyReply: Sendable {
    private let owner: OSAllocatedUnfairLock<sec_protocol_verify_complete_t?>
    init(_ callback: @escaping sec_protocol_verify_complete_t) { owner = OSAllocatedUnfairLock(uncheckedState:callback) }
    func finish(_ valid: Bool) { let callback = owner.withLockUnchecked { value in let take = value; value = nil; return take }; callback?(valid) }
}
