import Foundation
import Network
import Security
import os

let researchALPN = "networkkit-f6-test"
final class TrustObservation: Sendable {
    struct State: Sendable { var calls = 0; var accepted = 0; var rejected = 0 }
    let state = OSAllocatedUnfairLock(initialState: State())
}
func quicParameters(root: URL, server: Bool, trusted: Bool = true, alpn: String = researchALPN,
                    observation: TrustObservation, datagrams: Bool = true) throws -> NWParameters {
    let options = NWProtocolQUIC.Options(alpn:[alpn])
    options.idleTimeout = 5000; options.initialMaxData = 65536
    options.initialMaxStreamDataBidirectionalLocal = 65536; options.initialMaxStreamDataBidirectionalRemote = 65536
    options.initialMaxStreamDataUnidirectional = 65536
    options.initialMaxStreamsBidirectional = 4; options.initialMaxStreamsUnidirectional = 4
    options.maxDatagramFrameSize = datagrams ? 1024 : 0
    let security = options.securityProtocolOptions
    if server {
        let carrier = try fixtureCredential(root,name:"server-current")
        guard let identity = carrier.identity, let nativeIdentity = sec_identity_create(identity) else { throw ProbeFailure.failed("server-identity") }
        sec_protocol_options_set_local_identity(security,nativeIdentity)
        sec_protocol_options_set_peer_authentication_required(security,false) // Fixture server does not request client identity.
    } else {
        let anchorBytes = trusted ? try Data(contentsOf:root.appendingPathComponent("ca.cert.der")) : nil
        sec_protocol_options_set_tls_server_name(security,"localhost")
        sec_protocol_options_set_verify_block(security,{ _, reference, complete in
            let trust = sec_trust_copy_ref(reference).takeRetainedValue()
            SecTrustSetNetworkFetchAllowed(trust,false)
            SecTrustSetPolicies(trust,SecPolicyCreateSSL(true,"localhost" as CFString))
            if let anchorBytes, let anchor = SecCertificateCreateWithData(nil,anchorBytes as CFData) {
                SecTrustSetAnchorCertificates(trust,[anchor] as CFArray); SecTrustSetAnchorCertificatesOnly(trust,true)
            }
            let valid = SecTrustEvaluateWithError(trust,nil)
            observation.state.withLock { s in s.calls += 1; if valid { s.accepted += 1 } else { s.rejected += 1 } }
            complete(valid)
        },DispatchQueue(label:"f6.179.trust"))
    }
    return NWParameters(quic:options)
}

final class QUICGroupBox: Sendable {
    let group: NWConnectionGroup
    let ready = Once<Bool>()
    let inbox = FlowInbox()
    let budget = FlowBudget()
    let flows = OSAllocatedUnfairLock(initialState:[ResearchFlow]())
    let queue = DispatchQueue(label:"f6.179.quic.group")
    let failure = OSAllocatedUnfairLock<String?>(initialState:nil)
    let history = StateHistory()
    let unexpected = OSAllocatedUnfairLock(initialState:0)
    init(_ group: NWConnectionGroup) {
        self.group = group
        group.stateUpdateHandler = { [ready,failure,history] state in
            history.record(String(describing:state))
            if case .ready = state { ready.resolve(.success(true)) }
            if case .failed(let error) = state { failure.withLock { $0 = String(describing:error) }; ready.resolve(.failure(error)) }
            if case .cancelled = state { ready.resolve(.failure(ProbeFailure.cancelled)) }
        }
        group.newConnectionHandler = { [inbox,budget,flows,queue,unexpected] connection in
            do {
                let flow = try ResearchFlow(connection,budget:budget)
                flows.withLock { $0.append(flow) }
                // Do not block the FIFO on an incoming stream that has not reached readiness.
                flow.start(on:queue,onReady:{ [weak flow] in if let flow { inbox.push(flow) } })
            } catch { unexpected.withLock { $0 += 1 }; connection.cancel() }
        }
    }
    func start() { group.start(queue:queue) }
    func waitReady() async throws {
        _ = try await bounded(4,cancel:{ [group,ready] in group.cancel(); ready.resolve(.failure(ProbeFailure.timeout)) }) { [ready] in try await ready.value() }
    }
    func open(unidirectional: Bool = false, datagram: Bool = false) async throws -> ResearchFlow {
        let connection: NWConnection?
        if unidirectional || datagram {
            // Preserve the established group's TLS/ALPN configuration when selecting a child mode.
            // A fresh options object may request a different protocol stack during cloning.
            guard let options = group.parameters.copy().defaultProtocolStack.transportProtocol as? NWProtocolQUIC.Options else {
                throw ProbeFailure.failed("group-QUIC-options-unavailable")
            }
            options.direction = unidirectional ? .unidirectional : .bidirectional
            options.isDatagram = datagram
            connection = group.extract(using: options)
        } else {
            // Ordinary bidirectional stream uses the documented default extraction.
            connection = group.extract()
        }
        guard let connection else { throw ProbeFailure.failed("extract-nil") }
        let flow = try ResearchFlow(connection,budget:budget,datagram:datagram,sendOnly:unidirectional)
        flows.withLock { $0.append(flow) }; flow.start(on:queue)
        do { try await flow.waitReady() } catch { throw ProbeFailure.failed("extracted-flow-ready:\(error)") }
        return flow
    }
    func incoming() async throws -> ResearchFlow { let flow = try await inbox.take(); try await flow.waitReady(); return flow }
    func diagnostic() -> String {
        "group=\(history.snapshot);unexpected=\(unexpected.withLock { $0 });flows=" + flows.withLock { $0.map { $0.history.snapshot }.joined(separator:";") }
    }
    func close() {
        let all = flows.withLock { s in let all = s; s.removeAll(); return all }
        all.forEach { $0.close() }; inbox.close(); group.cancel(); ready.resolve(.failure(ProbeFailure.cancelled))
    }
    deinit { close() }
}

final class QUICListenerPeer: Sendable {
    let listener: NWListener
    let ready = Once<UInt16>()
    let accepted = Once<QUICGroupBox>()
    let groups = OSAllocatedUnfairLock(initialState:[QUICGroupBox]())
    let queue = DispatchQueue(label:"f6.179.quic.listener")
    let unexpected = OSAllocatedUnfairLock(initialState:0)
    init(root: URL, datagrams: Bool = true) throws {
        let parameters = try quicParameters(root:root,server:true,observation:TrustObservation(),datagrams:datagrams)
        parameters.requiredLocalEndpoint = .hostPort(host:"127.0.0.1",port:.any)
        let listener: NWListener
        do { listener = try NWListener(using:parameters,on:.any) }
        catch { throw ProbeFailure.failed("quic-listener-init:\(error)") }
        self.listener = listener
        listener.newConnectionLimit = 8 // Finite creation credit, not the one-transport admission cap.
        listener.stateUpdateHandler = { [ready,weak listener] state in
            if case .ready = state, let port = listener?.port { ready.resolve(.success(port.rawValue)) }
            if case .failed(let error) = state { ready.resolve(.failure(error)) }
            if case .cancelled = state { ready.resolve(.failure(ProbeFailure.cancelled)) }
        }
        listener.newConnectionGroupHandler = { [groups,accepted,unexpected] group in
            let allowed = groups.withLock { $0.isEmpty }
            guard allowed else { unexpected.withLock { $0 += 1 }; group.cancel(); return }
            let box = QUICGroupBox(group)
            groups.withLock { $0.append(box) }; box.start(); accepted.resolve(.success(box))
        }
        // SDK listener.h: group and ordinary connection handlers are mutually exclusive.
    }
    func start() async throws -> UInt16 {
        listener.start(queue:queue)
        do { return try await bounded(3,cancel:{ [listener,ready] in listener.cancel(); ready.resolve(.failure(ProbeFailure.timeout)) }) { [ready] in try await ready.value() } }
        catch { throw ProbeFailure.failed("quic-listener-start:\(error)") }
    }
    func take() async throws -> QUICGroupBox {
        let group = try await bounded(4,cancel:{ [accepted] in accepted.resolve(.failure(ProbeFailure.timeout)) }) { [accepted] in try await accepted.value() }
        try await group.waitReady(); return group
    }
    func close() { listener.cancel(); groups.withLock { $0 }.forEach { $0.close() }; accepted.resolve(.failure(ProbeFailure.cancelled)) }
    deinit { close() }
}

func quicCase(_ id: String, root: URL) async throws -> ResearchReport {
    let streamOnly = id == "C01"
    let peer = try QUICListenerPeer(root:root,datagrams:!streamOnly); defer { peer.close() }
    let port = try await peer.start(); let trust = TrustObservation()
    let parameters = try quicParameters(root:root,server:false,trusted:id != "Q07",alpn:id == "Q06" ? "networkkit-f6-wrong" : researchALPN,observation:trust,datagrams:!streamOnly)
    let client = QUICGroupBox(NWConnectionGroup(with:NWMultiplexGroup(to:.hostPort(host:"127.0.0.1",port:NWEndpoint.Port(rawValue:port)!)),using:parameters))
    defer {
        let evidence = ResearchReport(id:id+"-diagnostic",observations:["client":client.diagnostic(),"peer":peer.groups.withLock { $0.map { $0.diagnostic() }.joined(separator:" / ") },"unexpectedTransports":String(peer.unexpected.withLock { $0 }),"trustCalls":String(trust.state.withLock { $0.calls }),"trustRejected":String(trust.state.withLock { $0.rejected }),"trustAccepted":String(trust.state.withLock { $0.accepted })])
        if let bytes = try? JSONEncoder().encode(evidence) { FileHandle.standardError.write(bytes + Data([10])) }
        client.close()
    }; client.start()
    var report = ResearchReport(id:id)
    if id == "Q06" || id == "Q07" {
        do { try await client.waitReady(); throw ProbeFailure.failed("negative-quic-ready") }
        catch let error as NWError {
            if id == "Q07" { try assertion(trust.state.withLock { $0.calls > 0 && $0.rejected > 0 && $0.accepted == 0 },"trust-witness") }
            if id == "Q06" { guard case .tls = error else { throw ProbeFailure.failed("ALPN-not-TLS-error") } }
            report.observations["nativeError"] = String(describing:error)
            report.observations["trustRejected"] = String(trust.state.withLock { $0.rejected })
            return report
        }
    }
    try await client.waitReady(); let server = try await peer.take()
    if id == "Q04" || id == "Q05" {
        let outgoing = try await client.open(datagram:true); let incoming = try await server.open(datagram:true)
        try await outgoing.send(Data("dg".utf8)); let data = try await incoming.receive()
        try assertion(data == Data("dg".utf8),"datagram-route")
        try await outgoing.send(Data()); let empty = try await incoming.receive()
        try assertion(empty.isEmpty,"empty-datagram")
        report.observations["datagramBytes"] = String(data.count); report.observations["emptyDatagram"] = "true"
        if id == "Q04" { report.observations["clientContexts"] = String(client.budget.state.withLock { $0.contexts }); return report }
    }
    if id == "Q02" {
        let outgoing = try await server.open(unidirectional:true)
        try await outgoing.send(Data("uni".utf8)); let incoming = try await client.incoming()
        let bytes = try await incoming.read(3); try assertion(bytes == Data("uni".utf8),"peer-uni")
        try assertion(outgoing.streamID.map { $0 & 3 == 3 } == true,"server-unidirectional-stream-id")
        report.observations["peerInitiatedUnidirectional"] = "true"
    } else {
        let outgoing = try await client.open(unidirectional:id == "Q03")
        try await outgoing.send(Data("one".utf8)); let incoming = try await server.incoming()
        let bytes = try await incoming.read(3); try assertion(bytes == Data("one".utf8),"stream-route")
        if id == "Q03" {
            do { _ = try await outgoing.receive(); throw ProbeFailure.failed("direction-guard") }
            catch ProbeFailure.failed(let label) { try assertion(label == "send-only-receive","direction-error") }
            try assertion(outgoing.streamID.map { $0 & 3 == 2 } == true && outgoing.lastReceive.withLock { $0 == nil },"client-uni-no-receive")
            report.observations["invalidReceiveNoIO"] = "true"
        } else if id == "Q08" {
            outgoing.close()
            let sibling = try await client.open(); try await sibling.send(Data("two".utf8))
            let peerSibling = try await server.incoming(); let other = try await peerSibling.read(3)
            try assertion(other == Data("two".utf8),"sibling-data")
            try await peerSibling.send(Data("ok".utf8)); let reply = try await sibling.read(2)
            try assertion(reply == Data("ok".utf8),"sibling-after-cancel")
            report.observations["siblingSurvives"] = "true"
        } else if id == "Q09" {
            let pending = Task { try await outgoing.receive() }
            _ = try await outgoing.receiveStarted.value(); client.close()
            do { _ = try await pending.value; throw ProbeFailure.failed("child-still-active") } catch ProbeFailure.cancelled {}
            try assertion(outgoing.lastReceive.withLock { $0?.resolutionCount } == 1,"child-resolution-once")
            report.observations["childResolvedOnce"] = "true"
        } else {
            try await incoming.send(Data("ok".utf8)); let reply = try await outgoing.read(2)
            try assertion(reply == Data("ok".utf8),"stream-echo")
            try assertion(outgoing.alpn == researchALPN,"negotiated-alpn")
            report.observations["negotiatedALPN"] = outgoing.alpn
        }
    }
    try assertion(peer.unexpected.withLock { $0 == 0 } && client.unexpected.withLock { $0 == 0 } && server.unexpected.withLock { $0 == 0 },"unexpected-group-or-context")
    try assertion(client.budget.state.withLock { $0.contextAttempts <= 4 } && server.budget.state.withLock { $0.contextAttempts <= 4 },"native-context-budget")
    report.observations["clientContexts"] = String(client.budget.state.withLock { $0.contexts })
    report.observations["serverContexts"] = String(server.budget.state.withLock { $0.contexts })
    report.observations["peerTransportGroups"] = String(peer.groups.withLock { $0.count })
    report.observations["trustedCallbacks"] = String(trust.state.withLock { $0.accepted })
    return report
}
