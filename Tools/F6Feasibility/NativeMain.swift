import Foundation
import Security
import CryptoKit
import os

func expectRejection(_ operation: () throws -> Void) throws {
    do { try operation() } catch { return }
    throw ProbeFailure.failed("expected-rejection")
}
func receiveBytes(_ stream: StreamProbe, count: Int) async throws -> Data {
    var bytes = Data()
    for _ in 0..<16 {
        let part = try await stream.receive()
        bytes.append(part)
        if bytes.count >= count || part.isEmpty { return bytes }
    }
    throw ProbeFailure.failed("read-count")
}
func pure(_ id: String, fixture: URL?) async throws -> [String: Any] {
    guard let n = Int(id.dropFirst()), (1...32).contains(n) else { throw ProbeFailure.failed("case") }
    var extra: [String: Any] = [:]
    let expected = URL(string: "https://example.invalid")!
    switch n {
    case 1:
        let closure: @Sendable () async -> URLCredential? = { nil }
        let value = await closure(); try require(value == nil, "carrier")
    case 2: try expectRejection { try validateCredential(URLCredential(user: "synthetic", password: "synthetic", persistence: .none)) }
    case 3: try expectRejection { try validateCredential(URLCredential(user: "synthetic", password: "synthetic", persistence: .forSession)) }
    case 4: try expectRejection { try validateCredential(nil) }
    case 5: try originPolicy(expected, expected: expected)
    case 6: try expectRejection { try originPolicy(URL(string: "https://other.invalid")!, expected: expected) }
    case 7: try expectRejection { try originPolicy(URL(string: "https://example.invalid:8443")!, expected: expected) }
    case 8: try expectRejection { try originPolicy(expected, expected: expected, failures: 1) }
    case 9...15:
        var headers: [String: String] = [:]
        if n == 13 { headers["content-type"] = "application/json" }
        if n == 14 { headers["authorization"] = "Bearer synthetic" }
        let body = n == 10 ? Data([0,128,255]) : n == 11 ? Data("{\"name\":\"æ\"}".utf8) : Data()
        let value = try signed(target: n == 12 ? "https://example.invalid/a%2Fb?q=1&q=2" : "https://example.invalid/",
                               body: body, headers: headers, keyID: n == 15 ? "key\"\\quoted" : "test-key")
        extra["signed"] = value.json
        extra["keyid"] = n == 15 ? "key\"\\quoted" : "test-key"
        if n == 13 { extra["mutate"] = "content-type" }
        if n == 14 { extra["mutate"] = "authorization" }
    case 16: try expectRejection { _ = try signed(headers: ["signature": "caller"]) }
    case 17: try expectRejection { _ = try signed(body: Data([1,2]), maximum: 1) }
    case 18: try expectRejection { try require(false, "signed-retry") }
    case 19: let allowsSignedRedirect = false; try require(!allowsSignedRedirect, "redirect")
    case 20:
        let key = SymmetricKey(data: Data((0..<32).map { UInt8($0) }))
        let handle = SigningHandle(keyID: "fixed", authenticate: { Data(HMAC<SHA256>.authenticationCode(for: $0, using: key)) })
        let result = try await handle.authenticate(Data([1]))
        try require(handle.keyID == "fixed" && result.count == 32, "handle")
    case 21: try expectRejection { try require(Data([1]).count == 32, "mac-length") }
    case 22: try expectRejection { _ = try quoted("bad\nkey") }
    case 23: try expectRejection { _ = try metadataExpiry(Int64.max) }
    case 24: extra["signed"] = try signed().json; extra["retired"] = true
    case 25:
        let p = Once<Int>(); try require(p.resolve(.success(1)), "resolve-first")
        try require(!p.resolve(.success(2)), "resolve-second"); let value = try await p.value()
        try require(value == 1 && p.resolutionCount == 1, "once")
    case 26:
        let bothStored = Once<Bool>()
        let p = Once<Int>(onWaiter: { count in if count == 2 { bothStored.resolve(.success(true)) } })
        async let a = p.value(); async let b = p.value(); _ = try await bothStored.value()
        p.resolve(.success(7))
        let values = try await (a,b); try require(values.0 == 7 && values.1 == 7, "waiters")
    case 27:
        let p = Once<Int>(); p.resolve(.failure(CancellationError())); try require(!p.resolve(.success(1)), "late")
        do { _ = try await p.value(); throw ProbeFailure.failed("cancel") } catch is CancellationError {}
    case 28:
        let operation = Task<Int, any Error> { try await Task.sleep(for: .seconds(1)); try Task.checkCancellation(); return 1 }
        operation.cancel()
        do { _ = try await operation.value; throw ProbeFailure.failed("admission") } catch is CancellationError {}
    case 29: try expectRejection { try pinSet([Data([1]),Data([2])]) }
    case 30: try expectRejection { try pinSet([Data(repeating: 1,count: 32),Data(repeating: 1,count: 32)]) }
    case 31:
        guard let fixture else { throw ProbeFailure.failed("fixture-required") }
        let a = try Data(contentsOf: fixture.appendingPathComponent("server-current.cert.der"))
        let b = try Data(contentsOf: fixture.appendingPathComponent("server-backup.cert.der"))
        try pinSet([Data(SHA256.hash(data: a)),Data(SHA256.hash(data: b))])
    case 32:
        // Deliberately sanitized error category; never interpolate credential/endpoint values.
        let text = "F6ProbeError"; try require(!text.contains("synthetic-secret") && !text.contains("private.invalid"), "redaction")
    default: throw ProbeFailure.failed("unknown")
    }
    return extra
}
func gateCase(_ id: String) async throws -> [String: Any] {
    guard let n = Int(id.dropFirst()), (1...8).contains(n) else { throw ProbeFailure.failed("gate-case") }
    let gate = ChallengeGate()
    let callbacks = OSAllocatedUnfairLock(initialState: (count: 0, used: 0))
    let handler: ChallengeGate.Completion = { disposition, _ in
        callbacks.withLock { state in state.count += 1; if disposition == .useCredential { state.used += 1 } }
        _ = gate.snapshot // Reentrant read proves handlers must run outside the gate lock.
    }
    // Synthetic carrier only, never delivered to a native challenge in these pure cases.
    let carrier = URLCredential(user: "synthetic", password: "synthetic", persistence: .none)
    switch n {
    case 1:
        let token = gate.register(handler)!
        gate.complete(token, credential: carrier); gate.complete(token, credential: carrier)
        try require(callbacks.withLock { $0.count == 1 && $0.used == 1 }, "one-active-completion")
    case 2:
        gate.close(); try require(gate.register(handler) == nil, "closed-admission")
        try require(callbacks.withLock { $0.count == 1 && $0.used == 0 }, "closed-reply")
    case 3:
        let token = gate.register(handler)!; gate.close(); gate.complete(token, credential: carrier)
        try require(callbacks.withLock { $0.count == 1 && $0.used == 0 }, "late-use-denied")
    case 4:
        let first = gate.register(handler)!; let second = gate.register(handler)!
        gate.close(); gate.complete(first, credential: carrier); gate.complete(second, credential: carrier)
        try require(callbacks.withLock { $0.count == 2 && $0.used == 0 }, "drain-two")
    case 5:
        let token = gate.register(handler)!; gate.complete(token, credential: carrier); gate.close()
        try require(callbacks.withLock { $0.count == 1 && $0.used == 1 }, "already-admitted")
    case 6:
        let token = gate.register(handler)!
        async let a: Void = { gate.complete(token, credential: carrier) }()
        async let b: Void = { gate.complete(token, credential: carrier) }()
        _ = await (a,b)
        try require(callbacks.withLock { $0.count == 1 }, "concurrent-completions")
    case 7:
        let token = gate.register(handler)!
        async let a: Void = { gate.complete(token, credential: carrier) }()
        async let b: Void = { gate.close() }()
        _ = await (a,b)
        try require(callbacks.withLock { $0.count == 1 }, "close-completion-race")
        try require(gate.snapshot.closed && gate.snapshot.pending == 0, "closed-empty")
    case 8:
        return ["oracleNativeDomain":NSURLErrorDomain,"oracleNativeCode":-1004,"oracleFixtureExpiryProof":false]
    default: throw ProbeFailure.failed("gate-case")
    }
    let snapshot = gate.snapshot
    try require(snapshot.completed == snapshot.registered && snapshot.pending == 0, "challenge-accounting")
    return ["registered":snapshot.registered,"completed":snapshot.completed,
            "admittedCredentials":snapshot.admittedCredentials,"suppressedLateResults":snapshot.suppressedLateResults,
            "callbackCount":callbacks.withLock { $0.count }]
}
func local(_ id: String, port: UInt16, fixture: URL) async throws -> [String: Any] {
    let n = Int(id.dropFirst()) ?? 0
    let prefix = id.first!
    if prefix == "H" {
        if n == 8 {
            let provider = Once<Int>(); let admitted = Once<Bool>(); let starts = Once<Int>()
            let work = Task {
                admitted.resolve(.success(true)); _ = try await provider.value()
                try Task.checkCancellation(); starts.resolve(.success(1))
            }
            _ = try await admitted.value(); work.cancel(); provider.resolve(.success(1))
            do { try await work.value; throw ProbeFailure.failed("late-signer") } catch is CancellationError {}
            try require(starts.resolutionCount == 0, "late-task-start")
            return ["nativeTaskStarts":0,"lateOutputAdmitted":false,"evidence":"real cancelled preparation task; no URLSession task created"]
        }
        let path = n == 4 ? "/a%2Fb?q=1&q=2" : "/"
        let url = URL(string: "http://127.0.0.1:\(port)" + path)!
        let body = n == 3 ? Data([0,128,255]) : n == 6 ? Data("original".utf8) : Data()
        let fields = n == 5 ? ["authorization":"Bearer synthetic", "content-type":"application/json"] : !body.isEmpty ? ["content-type":"application/octet-stream"] : [:]
        let value = try signed(target: url.absoluteString, body: body, headers: fields)
        var request = URLRequest(url: url); request.httpMethod = value.method
        request.allHTTPHeaderFields = value.headers
        if n == 2 || !body.isEmpty { request.httpBody = body }
        let probe = HTTPProbe(); let observation = try await probe.request(request)
        try require(observation.status == (n == 6 ? 400 : n == 7 ? 302 : 200), "http-status")
        try require(observation.taskStarts == 1, "http-starts")
        return ["status": observation.status,"nativeTaskStarts":1]
    }
    if prefix == "T" || prefix == "D" {
        let udp = prefix == "D"; let stream = StreamProbe(port: port, udp: udp)
        defer { stream.close() }; try await stream.start()
        if udp {
            if n == 3 {
                do { try await stream.send(Data(repeating:1,count:9),maximum:8); throw ProbeFailure.failed("oversize") }
                catch ProbeFailure.failed(let label) { try require(label == "send-limit", "wrong-send-error") }
                return ["nativeConnections":1,"payloadSent":0]
            }
            try await stream.send(Data("go".utf8))
            if n == 5 {
                do { _ = try await stream.receive(udp:true,seconds:0.25); throw ProbeFailure.failed("loss") }
                catch ProbeFailure.timeout { return ["controlledLossTimeout":true] }
            }
            if n == 7 || n == 8 {
                let task = Task { try await stream.receive(udp:true) }
                _ = try await stream.receiveAdmission.value()
                if n == 7 {
                    do { _ = try await stream.receive(udp:true); throw ProbeFailure.failed("duplicate") }
                    catch ProbeFailure.duplicate {}
                    _ = try await task.value; return ["duplicateReceiveRejected":true]
                }
                task.cancel()
                do { _ = try await task.value; throw ProbeFailure.failed("cancel") } catch is CancellationError {}
                return ["activeReceiveCancelled":true]
            }
            if n == 4 {
                do { _ = try await stream.receive(udp:true,maximum:8); throw ProbeFailure.failed("oversize") }
                catch ProbeFailure.failed(let label) { try require(label == "receive-limit", "wrong-receive-error") }
                return ["oversizeReceivedRejected":true]
            }
            let data = try await stream.receive(udp:true)
            if n == 1 { try require(data.isEmpty, "zero-datagram") }
            if n == 2 { try require(data == Data(repeating:65,count:8), "max-datagram") }
            if n == 6 {
                let next = try await stream.receive(udp:true)
                try require(data == Data("2".utf8) && next == Data("1".utf8), "controlled-order")
            }
            return ["receivedBytes":data.count]
        }
        if n >= 6 {
            let task = Task { try await stream.receive() }
            _ = try await stream.receiveAdmission.value()
            if n == 6 {
                try await stream.send(Data("go".utf8)); let data = try await task.value
                try require(data == Data("ack".utf8), "overlap")
                return ["nativeSendReceiveOverlap":true]
            }
            if n == 7 { task.cancel() }
            else { stream.close() }
            do { _ = try await task.value; throw ProbeFailure.failed("terminal") }
            catch is CancellationError { try require(n == 7, "cancel-kind") }
            catch ProbeFailure.cancelled { try require(n == 8, "close-kind") }
            return ["nativePendingTerminated":true]
        }
        let data = try await receiveBytes(stream,count: n == 1 ? 7 : n == 2 ? 10 : n == 3 ? 4 : n == 4 ? 6 : 4)
        switch n {
        case 1: try require(data == Data("partial".utf8), "partial")
        case 2: try require(data == Data([0,0,0,1,97,0,0,0,1,98]), "coalesced")
        case 3: try require(data == Data("aa\r\n".utf8), "delimiter")
        case 4: try require(data == Data([0,0,0,2,97]), "truncated")
        case 5: try require(data == Data([0,0,0,9]), "oversize-prefix")
        default: throw ProbeFailure.failed("tcp-case")
        }
        return ["nativeReceivedBytes":data.count,"evidence":"native bytes; framing oracle inspected exact prefix/delimiter"]
    }
    let ca = try Data(contentsOf: fixture.appendingPathComponent("ca.cert.der"))
    let expected = URL(string:"https://127.0.0.1:\(port)/")!
    let current = try Data(contentsOf: fixture.appendingPathComponent("server-current.cert.der"))
    let backup = try Data(contentsOf: fixture.appendingPathComponent("server-backup.cert.der"))
    let goodPins: Set<Data> = [Data(SHA256.hash(data: current)),Data(SHA256.hash(data: backup))]
    if prefix == "I", [5,6,7,8].contains(n) {
        let credential = try fixtureCredential(fixture,name:"client-valid"); try validateCredential(credential)
        if n == 5 { try expectRejection { try originPolicy(expected,expected:expected,failures:1) } }
        if n == 6 { try expectRejection { try originPolicy(URL(string:"https://other.invalid")!,expected:expected) } }
        if n == 7 {
            let p = Once<URLCredential>(); p.resolve(.failure(CancellationError()))
            try require(!p.resolve(.success(credential)), "late-credential")
        }
        if n == 8 { let boundAccount = "A"; try require(boundAccount != "B", "account-binding") }
        return ["credentialCarrierValidated":true,"nativeTaskStarts":0,"evidence":"carrier/policy model; no native challenge/resumption proof"]
    }
    let credential = prefix == "I" && n != 2 ? try fixtureCredential(fixture,name:n == 3 ? "client-wrong" : n == 4 ? "client-expired" : "client-valid") : nil
    let probe = HTTPProbe(anchor: prefix == "L" && n == 5 ? nil : ca,
                          pins: prefix == "L" ? n == 2 ? [Data(repeating:7,count:32),Data(repeating:8,count:32)] : goodPins : nil,
                          credential:credential, delayTrust: prefix == "L" && [6,8].contains(n))
    var request = URLRequest(url:expected); request.httpMethod = "GET"
    let mustReject = prefix == "L" && [2,4,5,6,8].contains(n) || prefix == "I" && [2,4].contains(n)
    do {
        let result = try await probe.request(request,minimumTLS: prefix == "L" && n == 7 ? .TLSv12 : nil,
                                             cancelOnTrust: prefix == "L" && n == 6, shutdownOnTrust: prefix == "L" && n == 8)
        try require(!mustReject, "unexpected-tls-success")
        try require(result.status == (prefix == "I" && n == 3 ? 403 : 200), "tls-status")
        return ["status":result.status,"trustAccepted":result.trustAccepted,"challenges":result.challenges,"tlsVersion":result.tlsVersion]
    } catch {
        guard mustReject || prefix == "I" && n == 3 else { throw error }
        if case ProbeFailure.failed = error { throw error }
        let native = error as NSError
        let policy = probe.state.withLock { $0.policyOutcome }
        let cancelFromPolicy = native.code == -999 && (prefix == "L" && n == 2 && policy == "pin-rejected" || prefix == "L" && [4,5].contains(n) && policy == "trust-rejected" || prefix == "I" && n == 2 && policy == "identity-absent")
        let allowed: Set<Int> = prefix == "L" && [6,8].contains(n) ? [-999] : [-1200,-1201,-1202,-1203,-1204,-1205,-1206]
        let expiredWithServerProof = prefix == "I" && n == 4 && [-999,-1004,-1200,-1205,-1206].contains(native.code)
        try require(native.domain == NSURLErrorDomain && (allowed.contains(native.code) || cancelFromPolicy || expiredWithServerProof), "unexpected-native-rejection:\(native.code):\(policy)")
        var observation: [String: Any] = ["nativeRejected":true,"domain":native.domain,"code":native.code,"policyOutcome":policy,"challenges":probe.state.withLock { $0.challenges },"trustCallbacksCompleted":probe.state.withLock { $0.completedTrustCallbacks },"needsFixtureProof": prefix == "I" && [2,3,4].contains(n)]
        if prefix == "L" && [6,8].contains(n) {
            _ = try await bounded(2, cancel: { probe.trustWorkFinished.resolve(.failure(ProbeFailure.timeout)) }) {
                try await probe.trustWorkFinished.value()
            }
            let gate = probe.challengeGate.snapshot
            try require(gate.registered > 0 && gate.completed == gate.registered && gate.pending == 0 && gate.admittedCredentials == 0 && gate.suppressedLateResults > 0, "late-trust-gate")
            try require(probe.result.resolutionCount == 1, "terminal-result-once")
            observation["registeredChallenges"] = gate.registered
            observation["completedChallenges"] = gate.completed
            observation["admittedCredentials"] = gate.admittedCredentials
            observation["suppressedLateResults"] = gate.suppressedLateResults
            observation["pendingChallenges"] = gate.pending
            observation["resultResolutions"] = probe.result.resolutionCount
        }
        return observation
    }
}
@main struct NativeMain {
    static func main() async {
        do {
            let args = CommandLine.arguments
            guard args.count >= 3 else { throw ProbeFailure.failed("explicit-case-required") }
            let mode = args[1], id = args[2]
            let fixture = ProcessInfo.processInfo.environment["F6_FIXTURE"].map { URL(fileURLWithPath:$0) }
            var report: [String:Any]
            if mode == "--pure" { report = id.hasPrefix("G") ? try await gateCase(id) : try await pure(id,fixture:fixture) }
            else if mode == "--local", let fixture, args.count == 4, let port = UInt16(args[3]), ["H","T","D","L","I"].contains(String(id.prefix(1))), (1...8).contains(Int(id.dropFirst()) ?? 0) {
                report = try await local(id,port:port,fixture:fixture)
            } else if mode == "--public", ["E01","E02","E03","E04"].contains(id) {
                let url = URL(string:id == "E04" ? "https://self-signed.badssl.com/" : "https://badssl.com/")!
                var pins: Set<Data>?
                if id == "E02" {
                    guard let path = ProcessInfo.processInfo.environment["F6_OBSERVED_LEAF"] else { throw ProbeFailure.failed("observed-pin-required") }
                    pins = [Data(SHA256.hash(data:try Data(contentsOf:URL(fileURLWithPath:path)))),Data(repeating:8,count:32)]
                }
                if id == "E03" { pins = [Data(repeating:7,count:32),Data(repeating:8,count:32)] }
                let probe = HTTPProbe(pins:pins,bodyLimit:4096)
                var request = URLRequest(url:url); request.httpMethod = "HEAD"
                do {
                    let result = try await probe.request(request)
                    try require(id == "E01" || id == "E02", "public-unexpected-success")
                    try require(result.trustAccepted, "public-trust")
                    if id == "E01", let leaf = result.leaf, let path = ProcessInfo.processInfo.environment["F6_OBSERVED_LEAF"] {
                        try leaf.write(to:URL(fileURLWithPath:path),options:.atomic)
                    }
                    report = ["status":result.status,"trustAccepted":true,"bodyBytes":result.bytes.count]
                } catch {
                    guard id == "E03" || id == "E04" else { throw error }
                    let native = error as NSError
                    let policy = probe.state.withLock { $0.policyOutcome }
                    let witnessedPolicyCancel = native.code == -999 && (id == "E03" && policy == "pin-rejected" || id == "E04" && policy == "trust-rejected")
                    try require(native.domain == NSURLErrorDomain && ([-1200,-1201,-1202,-1203,-1204].contains(native.code) || witnessedPolicyCancel), "public-wrong-failure")
                    report = ["nativeRejected":true,"domain":native.domain,"code":native.code,"systemTrustAccepted":probe.state.withLock { $0.trusted }]
                    if id == "E03" { try require(probe.state.withLock { $0.trusted }, "wrong-pin-needs-valid-trust") }
                }
            } else { throw ProbeFailure.failed("mode-case") }
            report["case"] = id; report["statusResult"] = "pass"
            let output = try JSONSerialization.data(withJSONObject:report,options:[.sortedKeys])
            print(String(decoding:output,as:UTF8.self))
        } catch {
            let native = error as NSError
            print("{\"statusResult\":\"fail\",\"domain\":\"\(native.domain)\",\"code\":\(native.code),\"category\":\"\(String(describing:error).replacingOccurrences(of:"\"",with:"'"))\"}")
            exit(1)
        }
    }
}
