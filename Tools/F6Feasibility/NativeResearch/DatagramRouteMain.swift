import Foundation
import Network
import Security
import os

func directDatagramParameters(root: URL, server: Bool, gate: StartupCoordinator, trust: TrustObservation) throws -> NWParameters {
    let parameters = NWParameters.quicDatagram(alpn:[researchALPN])
    guard let quic = parameters.defaultProtocolStack.transportProtocol as? NWProtocolQUIC.Options else { throw ProbeFailure.failed("direct-QUIC-options") }
    try assertion(quic.isDatagram,"factory-datagram-mode")
    quic.maxDatagramFrameSize = 1024; quic.idleTimeout = 5000
    quic.initialMaxData = 65536; quic.initialMaxStreamsBidirectional = 4; quic.initialMaxStreamsUnidirectional = 4
    let security = quic.securityProtocolOptions
    sec_protocol_options_set_tls_resumption_enabled(security,false)
    if server {
        let carrier = try fixtureCredential(root,name:"server-current")
        guard let identity = carrier.identity, let native = sec_identity_create(identity) else { throw ProbeFailure.failed("fixture-identity") }
        sec_protocol_options_set_local_identity(security,native); sec_protocol_options_set_peer_authentication_required(security,false)
    } else {
        let bytes = try Data(contentsOf:root.appendingPathComponent("ca.cert.der"))
        sec_protocol_options_set_tls_server_name(security,"localhost")
        sec_protocol_options_set_verify_block(security,{ _,reference,complete in
            let reply = DatagramVerifyReply(complete)
            guard let token = gate.register(context:gate.context,reply:{ reply.finish($0) }) else { return }
            let nativeTrust = sec_trust_copy_ref(reference).takeRetainedValue()
            SecTrustSetNetworkFetchAllowed(nativeTrust,false); SecTrustSetPolicies(nativeTrust,SecPolicyCreateSSL(true,"localhost" as CFString))
            guard let anchor = SecCertificateCreateWithData(nil,bytes as CFData) else { gate.evaluated(token,valid:false); return }
            SecTrustSetAnchorCertificates(nativeTrust,[anchor] as CFArray); SecTrustSetAnchorCertificatesOnly(nativeTrust,true)
            let valid = SecTrustEvaluateWithError(nativeTrust,nil)
            trust.state.withLock { s in s.calls += 1; if valid { s.accepted += 1 } else { s.rejected += 1 } }
            gate.evaluated(token,valid:valid)
        },DispatchQueue(label:"f6.direct-dg.verify"))
    }
    return parameters
}
final class DirectDatagramPeer: Sendable {
    let listener: NWListener
    let ready = Once<UInt16>(); let accepted = Once<ResearchFlow>()
    let queue = DispatchQueue(label:"f6.direct-dg.peer")
    let flows = OSAllocatedUnfairLock(initialState:[ResearchFlow]())
    let budget = FlowBudget(); let policy = DatagramRouteState()
    let unexpected = OSAllocatedUnfairLock(initialState:0)
    let phases: StateHistory
    init(root: URL, phases: StateHistory) throws {
        self.phases = phases
        let parameters = try directDatagramParameters(root:root,server:true,gate:StartupCoordinator(),trust:TrustObservation())
        parameters.requiredLocalEndpoint = .hostPort(host:"127.0.0.1",port:.any)
        let listener = try NWListener(using:parameters,on:.any); self.listener = listener
        listener.newConnectionLimit = 1
        listener.stateUpdateHandler = { [ready,weak listener,phases] state in
            phases.record("listener:"+String(describing:state))
            if case .ready = state, let port = listener?.port { ready.resolve(.success(port.rawValue)) }
            if case .failed(let error) = state { ready.resolve(.failure(error)) }
        }
        listener.newConnectionHandler = { [accepted,policy,budget,queue,flows,unexpected,phases] connection in
            phases.record("direct-peer-connection-callback")
            do {
                try policy.reserveDatagram()
                let flow = try ResearchFlow(connection,budget:budget,datagram:true,phases:phases)
                flows.withLock { $0.append(flow) }; flow.start(on:queue); accepted.resolve(.success(flow))
            } catch { unexpected.withLock { $0 += 1 }; connection.cancel(); accepted.resolve(.failure(error)) }
        }
    }
    func start() async throws -> UInt16 {
        listener.start(queue:queue)
        return try await bounded(3,cancel:{ [listener,ready] in listener.cancel(); ready.resolve(.failure(ProbeFailure.timeout)) }) { [ready] in try await ready.value() }
    }
    func take() async throws -> ResearchFlow {
        let flow = try await bounded(3,cancel:{ [accepted] in accepted.resolve(.failure(ProbeFailure.timeout)) }) { [accepted] in try await accepted.value() }
        try await flow.waitReady(); return flow
    }
    func close() { listener.cancel(); flows.withLock { $0 }.forEach { $0.close() }; accepted.resolve(.failure(ProbeFailure.cancelled)) }
}
func datagramRoute(_ id: String, root: URL) async throws -> ResearchReport {
    if id == "G01" || id == "G02" {
        let value = try await quicCase(id == "G01" ? "Q04" : "Q05",root:root)
        return ResearchReport(id:id,status:value.status,observations:value.observations)
    }
    let phases = StateHistory(limit:64); let peer = try DirectDatagramPeer(root:root,phases:phases)
    defer { peer.close() }
    let port = try await peer.start(); let trust = TrustObservation(); let gate = StartupCoordinator(timeout:4)
    let parameters = try directDatagramParameters(root:root,server:false,gate:gate,trust:trust)
    let native = NWConnection(host:"127.0.0.1",port:NWEndpoint.Port(rawValue:port)!,using:parameters)
    let budget = FlowBudget(); let client = try ResearchFlow(native,budget:budget,datagram:true,phases:phases)
    gate.setStop { [weak native] in native?.cancel() }
    defer { gate.terminate(.cancelled); client.close() }
    let timer = Task { do { try await Task.sleep(for:.seconds(4)); gate.expireStartup() } catch {} }; defer { timer.cancel() }
    client.start(on:DispatchQueue(label:"f6.direct-dg.client"),onReady:{ [weak client] in
        gate.nativeReady(alpn:client?.alpn == "unavailable" ? nil : client?.alpn)
    })
    var report = ResearchReport(id:id,observations:["positiveReady":"false","positiveDatagram":"false","emptyReceived":"false"])
    do {
        let outcome = try await bounded(5,cancel:{ gate.expireStartup() }) { try await gate.result.value() }
        try assertion(outcome == .admitted && trust.state.withLock { $0.accepted > 0 && $0.rejected == 0 },"direct-trust-ALPN-admission")
        phases.record("client-trust-ALPN-admitted")
        let remote = try await peer.take()
        try assertion(remote.alpn == researchALPN && client.usableDatagramSize >= 2 && remote.usableDatagramSize >= 2,"direct-peer-ALPN-capacity")
        report.observations["positiveReady"] = "true"
        phases.record("direct-ready:client:"+client.datagramMetadata+";server:"+remote.datagramMetadata)
        let sender = id == "D02" ? remote : client
        let receiver = id == "D02" ? client : remote
        let policy = DatagramRouteState()
        func exchange(_ bytes: Data) async throws -> Data {
            let registered = Once<Bool>()
            let receiving = Task { try await receiver.receive(registered:registered) }
            defer { receiving.cancel() }
            _ = try await bounded(2,cancel:{ receiver.close(); registered.resolve(.failure(ProbeFailure.timeout)) }) { try await registered.value() }
            try assertion(gate.admitData(),"logical-data-admission")
            try await sender.send(bytes)
            let result = try await receiving.value
            return try policy.message(result,complete:true,context:true,capacity:receiver.usableDatagramSize)
        }
        if id != "D03" {
            let input = Data("dg".utf8); let received = try await exchange(input)
            try assertion(received == input,"direct-nonempty-exact")
            report.observations["positiveDatagram"] = "true"; phases.record("direct-nonempty-exact")
        }
        let empty = try await exchange(Data()); try assertion(empty.isEmpty,"direct-empty-exact")
        report.observations["emptyReceived"] = "true"; phases.record("direct-empty-exact")
        try assertion(peer.unexpected.withLock { $0 == 0 } && budget.state.withLock { $0.contextAttempts <= 4 } && peer.budget.state.withLock { $0.contextAttempts <= 4 },"direct-context-cap")
    } catch { report.status = "fail"; report.observations["error"] = String(describing:error) }
    report.observations["phases"] = phases.snapshot
    report.observations["trustAccepted"] = String(trust.state.withLock { $0.accepted })
    report.observations["trustRejected"] = String(trust.state.withLock { $0.rejected })
    report.observations["clientStates"] = client.history.snapshot
    report.observations["serverStates"] = peer.flows.withLock { $0.map { $0.history.snapshot }.joined(separator:" / ") }
    return report
}
@main struct DatagramRouteMain {
    static func main() async {
        let args = CommandLine.arguments
        guard args.count == 3 else { exit(2) }
        let id = args[2]
        do {
            let report: ResearchReport
            if args[1] == "--pure", ["R01","R02","R03","R04"].contains(id) { report = try datagramPure(id) }
            else if args[1] == "--native", ["D01","D02","D03","G01","G02"].contains(id), let path = ProcessInfo.processInfo.environment["F6_RESEARCH_FIXTURE"] { report = try await datagramRoute(id,root:URL(fileURLWithPath:path)) }
            else { throw ProbeFailure.failed("explicit-input") }
            FileHandle.standardOutput.write(try JSONEncoder().encode(report)+Data([10])); if report.status != "pass" { exit(1) }
        } catch {
            let report = ResearchReport(id:id,status:"fail",observations:["error":String(describing:error)])
            if let bytes = try? JSONEncoder().encode(report) { FileHandle.standardOutput.write(bytes+Data([10])) }; exit(1)
        }
    }
}
