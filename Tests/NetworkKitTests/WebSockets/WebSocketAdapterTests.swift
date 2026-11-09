#if !os(watchOS)
import Foundation
import Synchronization
import Testing
@testable import NetworkKit

private final class WebSocketChallengeSender: NSObject, URLAuthenticationChallengeSender, Sendable {
    func use(_ credential: URLCredential, for challenge: URLAuthenticationChallenge) {}
    func continueWithoutCredential(for challenge: URLAuthenticationChallenge) {}
    func cancel(_ challenge: URLAuthenticationChallenge) {}
    func performDefaultHandling(for challenge: URLAuthenticationChallenge) {}
    func rejectProtectionSpaceAndContinue(with challenge: URLAuthenticationChallenge) {}
}

@Suite(.timeLimit(.minutes(1))) struct WebSocketAdapterTests {
    @Test(arguments: [Int(POSIXErrorCode.EPROTO.rawValue), Int(POSIXErrorCode.EMSGSIZE.rawValue),
                      URLError.dataLengthExceedsMaximum.rawValue])
    func unopenedTaskCompletionDoesNotInventMessageOrProtocolFailures(_ code: Int) async throws {
        let domain = code < 0 ? NSURLErrorDomain : NSPOSIXErrorDomain
        let ready = WebSocketTestCounter(), events = Mutex<[WebSocketTransportEvent]>([])
        let adapter = WebSocketSessionTransport(request: .init(endpoint: URL(string: "wss://service.invalid")!,
            headers: .init(), subprotocols: [], maximumMessageBytes: 64)) { event in
                events.withLock { $0.append(event) }; ready.increment()
            }
        let session = URLSession(configuration: .ephemeral)
        let task = session.webSocketTask(with: URL(string: "wss://service.invalid")!) // Never resumed.
        defer { task.cancel(); session.invalidateAndCancel() }
        adapter.urlSession(session, task: task, didCompleteWithError: NSError(domain: domain, code: code))
        try await ready.wait(1)
        #expect(events.withLock { values in
            values.count == 1 && { if case .failed(.transport(let failure)) = values[0] {
                failure == .init(domain: domain, code: code)
            } else { false } }()
        })
    }

    @Test func nativeProtocolErrorsAndInvalidCloseReasonsRemainProtocolFailures() {
        let error = NSError(domain: NSPOSIXErrorDomain, code: Int(POSIXErrorCode.EPROTO.rawValue))
        #expect(WebSocketSessionTransport.failure(error, opened: true) == .protocolViolation)
        #expect(WebSocketSessionTransport.failure(error, opened: false) ==
            .transport(.init(domain: NSPOSIXErrorDomain, code: Int(POSIXErrorCode.EPROTO.rawValue))))
        #expect(WebSocketSessionTransport.taskCloseValidationFailure(code: 1000, reason: Data([255])) == .protocolViolation)
        #expect(WebSocketSessionTransport.taskCloseValidationFailure(code: 1005, reason: Data([97])) == .protocolViolation)
        #expect(WebSocketSessionTransport.taskCloseValidationFailure(code: 1000, reason: nil) == nil)
        #expect(WebSocketSessionTransport.taskCloseValidationFailure(code: 0, reason: nil) == nil)
    }

    @Test func nativeSizeErrorAndEarlyTaskCloseMetadataAreStructured() throws {
        #expect(WebSocketSessionTransport.failure(NSError(domain: NSPOSIXErrorDomain,
            code: Int(POSIXErrorCode.EMSGSIZE.rawValue)), opened: true) == .messageTooLarge)
        #expect(WebSocketSessionTransport.failure(NSError(domain: NSPOSIXErrorDomain,
            code: Int(POSIXErrorCode.ENOTCONN.rawValue)), opened: true) ==
                .transport(.init(domain: NSPOSIXErrorDomain, code: Int(POSIXErrorCode.ENOTCONN.rawValue))))
        #expect(WebSocketSessionTransport.taskCloseSnapshot(code: 1000, reason: Data("reason".utf8)) ==
            WebSocketCloseInfo(code: 1000, reason: "reason"))
        #expect(WebSocketSessionTransport.taskCloseSnapshot(code: 3001, reason: Data("reason".utf8)) ==
            WebSocketCloseInfo(code: 3001, reason: "reason"))
        for sentinel in [0, 1005, 1006, 1015] {
            #expect(WebSocketSessionTransport.taskCloseSnapshot(code: sentinel, reason: nil) == nil)
        }
        #expect(WebSocketSessionTransport.taskCloseSnapshot(code: 1000, reason: Data([255])) == nil)
    }

    @Test func ownedConfigurationAndRequestDoNotEnableStoresOrRewriteTarget() throws {
        let config = WebSocketSessionTransport.sessionConfiguration()
        #expect(config.httpCookieStorage == nil && config.urlCredentialStorage == nil && config.urlCache == nil)
        #expect(!config.httpShouldSetCookies)
        #expect(config.requestCachePolicy == .reloadIgnoringLocalCacheData)
        let endpoint = URL(string: "wss://service.invalid:8443/path%20name?a=x%2By&b=1")!
        let prepared = WebSocketOpenRequest(endpoint: endpoint, headers: try HTTPHeaders(["Authorization": "synthetic"]),
            subprotocols: ["first", "second"], maximumMessageBytes: 64)
        let request = WebSocketSessionTransport.urlRequest(prepared)
        #expect(request.url?.absoluteString == endpoint.absoluteString)
        #expect(request.httpMethod == "GET" && !request.httpShouldHandleCookies)
        #expect(request.value(forHTTPHeaderField: "Sec-WebSocket-Protocol") == "first, second")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "synthetic")
    }

    @Test func safeNativeErrorMappingNeverRetainsUserInfoOrInfersCallerCancellation() {
        let secret = NSError(domain: NSURLErrorDomain, code: URLError.cancelled.rawValue,
                             userInfo: [NSLocalizedDescriptionKey: "SECRET", NSURLErrorFailingURLStringErrorKey: "SECRET"])
        let error = WebSocketSessionTransport.failure(secret, opened: true)
        #expect(error == .transport(.init(domain: NSURLErrorDomain, code: URLError.cancelled.rawValue)))
        #expect(!String(reflecting: error).contains("SECRET"))
        #expect(WebSocketSessionTransport.failure(URLError(.badServerResponse), opened: false) == .handshakeRejected)
        #expect(WebSocketSessionTransport.failure(URLError(.dataLengthExceedsMaximum), opened: true) == .messageTooLarge)
    }

    @Test func redirectDelegateDeniesWithoutStartingATask() async throws {
        let events = Mutex<[WebSocketTransportEvent]>([]), eventReady = WebSocketTestCounter()
        let adapter = WebSocketSessionTransport(request: .init(endpoint: URL(string: "wss://service.invalid")!,
            headers: .init(), subprotocols: [], maximumMessageBytes: 64)) { event in
                events.withLock { $0.append(event) }; eventReady.increment()
            }
        let session = URLSession(configuration: .ephemeral)
        let task = session.webSocketTask(with: URL(string: "wss://service.invalid")!) // Deliberately never resumed.
        defer { task.cancel(); session.invalidateAndCancel() }
        let response = try #require(HTTPURLResponse(url: URL(string: "wss://service.invalid")!, statusCode: 302,
            httpVersion: nil, headerFields: ["Location": "wss://denied.invalid"]))
        let completionCalled = Mutex(false), accepted = Mutex<URLRequest?>(URLRequest(url: URL(string: "https://placeholder.invalid")!))
        adapter.urlSession(session, task: task, willPerformHTTPRedirection: response,
            newRequest: URLRequest(url: URL(string: "wss://denied.invalid")!)) { request in
                accepted.withLock { $0 = request }; completionCalled.withLock { $0 = true }
            }
        try await eventReady.wait(1)
        #expect(completionCalled.withLock { $0 } && accepted.withLock { $0 == nil })
        #expect(events.withLock { list in
            list.count == 1 && { if case .failed(.handshakeRejected) = list[0] { true } else { false } }()
        })
    }

    @Test(arguments: [NSURLAuthenticationMethodServerTrust, NSURLAuthenticationMethodHTTPBasic,
                      NSURLAuthenticationMethodHTTPDigest, NSURLAuthenticationMethodClientCertificate])
    func authChallengeUsesOnlySystemTrust(_ method: String) {
        let adapter = WebSocketSessionTransport(request: .init(endpoint: URL(string: "wss://service.invalid")!,
            headers: .init(), subprotocols: [], maximumMessageBytes: 64), events: { _ in })
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        let space = URLProtectionSpace(host: "service.invalid", port: 443, protocol: "https", realm: nil,
                                      authenticationMethod: method)
        let challenge = URLAuthenticationChallenge(protectionSpace: space, proposedCredential: nil,
            previousFailureCount: 0, failureResponse: nil, error: nil, sender: WebSocketChallengeSender())
        let disposition = Mutex<URLSession.AuthChallengeDisposition?>(nil), usedCredential = Mutex(false)
        adapter.urlSession(session, didReceive: challenge) { result, credential in
            disposition.withLock { $0 = result }; usedCredential.withLock { $0 = credential != nil }
        }
        #expect(disposition.withLock { $0 } == (method == NSURLAuthenticationMethodServerTrust ? .performDefaultHandling : .cancelAuthenticationChallenge))
        #expect(!usedCredential.withLock { $0 })
    }
}
#endif
#if !os(watchOS)
extension WebSocketAdapterTests {
    @Test func nativePeerSnapshotKeepsFirstValidatedFrameWithoutResumingTask() async throws {
        let count = WebSocketTestCounter(), events = Mutex<[WebSocketTransportEvent]>([])
        let adapter = WebSocketSessionTransport(request: .init(endpoint: URL(string: "wss://service.invalid")!,
            headers: .init(), subprotocols: [], maximumMessageBytes: 64)) { event in
                events.withLock { $0.append(event) }; count.increment()
            }
        let session = URLSession(configuration: .ephemeral)
        let task = session.webSocketTask(with: URL(string: "wss://service.invalid")!)
        defer { task.cancel(); session.invalidateAndCancel() }
        adapter.urlSession(session, webSocketTask: task, didCloseWith: .normalClosure, reason: Data("first".utf8))
        adapter.urlSession(session, webSocketTask: task, didCloseWith: .goingAway, reason: Data("late".utf8))
        try await count.wait(1)
        #expect(adapter.peerCloseInfo == WebSocketCloseInfo(code: 1000, reason: "first"))
        #expect(events.withLock { $0.count } == 1)
    }
}
#endif
