import Foundation
import Network
import Security
import os
/// Narrow C-callback bridge: the imported block lacks Sendable, but is retained only
/// in this slot and never exposed. The native verification protocol supports deferred
/// completion. Exclusive take prevents concurrent/double invocation; call outside lock.
/// This unchecked-state boundary is experiment-only and needs production review.
final class NativeVerifyReply: Sendable {
    private let completion: OSAllocatedUnfairLock<sec_protocol_verify_complete_t?>
    init(_ callback: @escaping sec_protocol_verify_complete_t) {
        completion = OSAllocatedUnfairLock(uncheckedState:callback)
    }
    func finish(_ valid: Bool) {
        let callback = completion.withLockUnchecked { value in let callback = value; value = nil; return callback }
        callback?(valid)
    }
}

final class NativeStartup: Sendable {
    let gate: StartupCoordinator
    let box: QUICGroupBox
    let trust = TrustObservation()
    let verificationSeen = Once<Bool>()
    let readySeen = Once<Bool>()
    let releaseReady = Once<Bool>()
    let flow = Once<ResearchFlow>()
    let history = StateHistory(limit:64)
    let held = OSAllocatedUnfairLock(initialState:[(Int,Bool)]())
    let worker = OSAllocatedUnfairLock<Task<Void,Never>?>(initialState:nil)
    let deadlineTask = OSAllocatedUnfairLock<Task<Void,Never>?>(initialState:nil)
    init(root: URL, port: UInt16, id: String) throws {
        let timeout: Double = id == "S05" ? 0.3 : 3
        let gate = StartupCoordinator(timeout:timeout); self.gate = gate
        let parameters = try quicParameters(root:root,server:false,trusted:id != "S02",alpn:id == "S03" ? "networkkit-f6-wrong" : researchALPN,observation:trust,datagrams:false)
        guard let options = parameters.defaultProtocolStack.transportProtocol as? NWProtocolQUIC.Options else { throw ProbeFailure.failed("native-options") }
        sec_protocol_options_set_tls_resumption_enabled(options.securityProtocolOptions,false)
        let anchor = id == "S02" ? nil : try Data(contentsOf:root.appendingPathComponent("ca.cert.der"))
        let hold = id == "S04" || id == "S05"
        sec_protocol_options_set_verify_block(options.securityProtocolOptions,{ [trust,held,verificationSeen,history] _,reference,complete in
            history.record("real-verify-callback")
            let replyOwner = NativeVerifyReply(complete)
            guard let token = gate.register(context:gate.context,reply:{ valid in replyOwner.finish(valid) }) else { return }
            let nativeTrust = sec_trust_copy_ref(reference).takeRetainedValue()
            SecTrustSetNetworkFetchAllowed(nativeTrust,false)
            SecTrustSetPolicies(nativeTrust,SecPolicyCreateSSL(true,"localhost" as CFString))
            if let anchor, let certificate = SecCertificateCreateWithData(nil,anchor as CFData) {
                SecTrustSetAnchorCertificates(nativeTrust,[certificate] as CFArray); SecTrustSetAnchorCertificatesOnly(nativeTrust,true)
            }
            let valid = SecTrustEvaluateWithError(nativeTrust,nil)
            trust.state.withLock { s in s.calls += 1; if valid { s.accepted += 1 } else { s.rejected += 1 } }
            if hold { held.withLock { $0.append((token,valid)) } }
            else { gate.evaluated(token,valid:valid) }
            verificationSeen.resolve(.success(true))
        },DispatchQueue(label:"f6.startup.verify"))
        let native = NWConnectionGroup(with:NWMultiplexGroup(to:.hostPort(host:"127.0.0.1",port:NWEndpoint.Port(rawValue:port)!)),using:parameters)
        let box = QUICGroupBox(native); self.box = box
        gate.setStop { [weak native] in native?.cancel() }
        let oldHandler = native.stateUpdateHandler
        let readyOnce = Once<Bool>()
        native.stateUpdateHandler = { [weak box,worker,history,readySeen,releaseReady,flow] state in
            oldHandler?(state); history.record("group:"+String(describing:state))
            switch state {
            case .ready:
                guard readyOnce.resolve(.success(true)), let box else { return }
                let task = Task {
                    do {
                        let child = try await box.open()
                        flow.resolve(.success(child)); history.record("real-child-ready")
                        readySeen.resolve(.success(true))
                        if id == "S06" { _ = try await releaseReady.value() }
                        gate.nativeReady(alpn:child.alpn == "unavailable" ? nil : child.alpn)
                    } catch { flow.resolve(.failure(error)); gate.terminate(.transport) }
                }
                worker.withLock { $0 = task }
            case .failed: gate.terminate(.transport)
            case .cancelled: gate.terminate(.cancelled)
            default: break
            }
        }
        if gate.admitNativeWork() {
            let task = Task { do { try await Task.sleep(for:.seconds(timeout)); gate.expireStartup() } catch {} }
            deadlineTask.withLock { $0 = task }; box.start()
        }
    }
    func releaseVerification() {
        let work = held.withLock { s in let all = s; s.removeAll(); return all }
        work.forEach { gate.evaluated($0.0,valid:$0.1) }
    }
    func close() async {
        gate.terminate(.cancelled); releaseVerification(); releaseReady.resolve(.success(true))
        box.close(); deadlineTask.withLock { $0 }?.cancel()
        if let work = worker.withLock({ $0 }) { await work.value }
    }
}

func startupNative(_ id: String, root: URL) async throws -> ResearchReport {
    let peer = try QUICListenerPeer(root:root,datagrams:false)
    let port = try await peer.start()
    let client: NativeStartup
    do { client = try NativeStartup(root:root,port:port,id:id) } catch { peer.close(); throw error }
    var report = ResearchReport(id:id)
    do {
        if id == "S04" || id == "S05" {
            _ = try await bounded(2,cancel:{ client.verificationSeen.resolve(.failure(ProbeFailure.timeout)) }) { try await client.verificationSeen.value() }
            if id == "S04" { client.gate.terminate(.cancelled) }
        }
        if id == "S06" {
            _ = try await bounded(2,cancel:{ client.readySeen.resolve(.failure(ProbeFailure.timeout)) }) { try await client.readySeen.value() }
            client.gate.terminate(.cancelled); client.releaseReady.resolve(.success(true))
        }
        let outcome = try await bounded(5,cancel:{ client.gate.terminate(.timeout) }) { try await client.gate.result.value() }
        client.releaseVerification()
        switch id {
        case "S01":
            try assertion(outcome == .admitted && client.gate.admitData(),"positive-admission")
            let outgoing = try await client.flow.value()
            let server = try await peer.take()
            // The peer receives the stream when its first bytes arrive, not at local extraction.
            try await outgoing.send(Data("ok".utf8))
            let incoming = try await server.incoming(); let input = try await incoming.read(2)
            try assertion(input == Data("ok".utf8),"positive-request")
            try await incoming.send(input); let reply = try await outgoing.read(2)
            try assertion(reply == input,"positive-reply")
            try assertion(client.trust.state.withLock { $0.accepted > 0 && $0.rejected == 0 },"positive-trust")
        case "S02":
            try assertion(outcome == .trustRejected && client.trust.state.withLock { $0.rejected > 0 && $0.accepted == 0 },"local-rejection-witness")
        case "S03":
            let witness = peer.groups.withLock { $0.contains { $0.failure.withLock { $0 != nil } } }
            try assertion((outcome == .timeout || outcome == .transport) && witness,"ALPN-controlled-peer-evidence")
        case "S04": try assertion(outcome == .cancelled && client.gate.snapshot.ignoredLate > 0,"native-cancel-late")
        case "S05": try assertion(outcome == .timeout && client.gate.snapshot.ignoredLate > 0,"native-timeout-late")
        case "S06": try assertion(outcome == .cancelled,"ready-handoff-cancel")
        default: throw ProbeFailure.failed("native-id")
        }
        if id != "S01" { try assertion(client.gate.snapshot.handoffs == 0 && client.gate.snapshot.data == 0,"negative-data-admission") }
        try assertion(client.gate.result.resolutionCount == 1 && client.gate.snapshot.pending == 0,"native-terminal-once")
        report.observations["outcome"] = outcome.rawValue
    } catch { report.status = "fail"; report.observations["error"] = String(describing:error) }
    await client.close(); peer.close()
    let s = client.gate.snapshot
    report.observations.merge(["registered":String(s.registered),"completed":String(s.completed),"pending":String(s.pending),"handoffs":String(s.handoffs),"dataAdmissions":String(s.data),"ignoredLate":String(s.ignoredLate),"callerResults":String(client.gate.result.resolutionCount),"trustAccepted":String(client.trust.state.withLock { $0.accepted }),"trustRejected":String(client.trust.state.withLock { $0.rejected }),"states":client.history.snapshot,"peer":peer.groups.withLock { $0.map { $0.diagnostic() }.joined(separator:" / ") }],uniquingKeysWith:{ first,_ in first })
    try assertion(peer.unexpected.withLock { $0 == 0 } && client.box.unexpected.withLock { $0 == 0 },"unexpected-context-or-group")
    return report
}

@main struct StartupMain {
    static func main() async {
        let args = CommandLine.arguments
        guard args.count == 3 else { exit(2) }
        let id = args[2]
        do {
            let report: ResearchReport
            if args[1] == "--pure", (1...12).contains(Int(id.dropFirst()) ?? 0), id.hasPrefix("L") { report = try await startupPure(id) }
            else if args[1] == "--native", (1...6).contains(Int(id.dropFirst()) ?? 0), id.hasPrefix("S"), let path = ProcessInfo.processInfo.environment["F6_RESEARCH_FIXTURE"] { report = try await startupNative(id,root:URL(fileURLWithPath:path)) }
            else { throw ProbeFailure.failed("explicit-mode") }
            let bytes = try JSONEncoder().encode(report); FileHandle.standardOutput.write(bytes + Data([10])); if report.status != "pass" { exit(1) }
        } catch {
            let report = ResearchReport(id:id,status:"fail",observations:["error":String(describing:error)])
            if let bytes = try? JSONEncoder().encode(report) { FileHandle.standardOutput.write(bytes + Data([10])) }; exit(1)
        }
    }
}
