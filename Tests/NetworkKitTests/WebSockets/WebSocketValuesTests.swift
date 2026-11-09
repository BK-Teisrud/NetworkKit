#if !os(watchOS)
import Foundation
import Testing
@testable import NetworkKit

@Suite struct WebSocketValuesTests {
    @Test(arguments: [0.0, -1, .infinity, -.infinity, .nan, 86400.001])
    func invalidBudgetsAreRejected(_ invalid: Double) {
        for values in [(invalid, 10.0, 2.0), (10.0, invalid, 2.0), (10.0, 10.0, invalid)] {
            #expect(throws: WebSocketError.invalidInput(.invalidTimeout)) {
                try WebSocketTimeouts(connect: values.0, send: values.1, close: values.2)
            }
        }
    }
    @Test func budgetBoundaryAndExplicitMessageLimit() throws {
        #expect(try WebSocketTimeouts(connect: 86400, send: 86400, close: 86400).connect == 86400)
        #expect(WebSocketTimeouts.default.connect == 10)
        #expect(WebSocketTimeouts.default.send == 10)
        #expect(WebSocketTimeouts.default.close == 2)
        for value in [Int.min, -1, 0] {
            #expect(throws: WebSocketError.invalidInput(.invalidMessageLimit)) { try webSocketTestConfiguration(maximum: value) }
        }
        #expect(try webSocketTestConfiguration(maximum: Int.max).maximumMessageBytes == Int.max)
    }
    @Test(arguments: ["https://service.invalid/", "wss://user:secret@service.invalid/", "wss://service.invalid/#fragment",
                      "wss://service.invalid:0/", "wss://service.invalid:65536/", "wss://service.invalid/../route"])
    func invalidURLsDoNotBroadenHTTPValidation(_ value: String) throws {
        let url = try #require(URL(string: value))
        #expect(throws: WebSocketError.invalidInput(.invalidEndpoint)) {
            try WebSocketConfiguration(endpoint: url, maximumMessageBytes: 64)
        }
    }
    @Test func localExceptionIsAnonymousAndExplicit() throws {
        for host in ["localhost", "127.0.0.1", "127.0.0.2", "[::1]"] {
            let url = URL(string: "ws://\(host):4567/path")!
            #expect(throws: WebSocketError.invalidInput(.insecureTransport)) {
                try WebSocketConfiguration(endpoint: url, maximumMessageBytes: 64)
            }
            _ = try WebSocketConfiguration(endpoint: url, maximumMessageBytes: 64, allowInsecureLoopback: true)
            #expect(throws: WebSocketError.invalidInput(.credentialsOverWS)) {
                try WebSocketConfiguration(endpoint: url, maximumMessageBytes: 64,
                    headers: HTTPHeaders(["X-Api-Key": "synthetic"]), allowInsecureLoopback: true)
            }
        }
        #expect(throws: WebSocketError.invalidInput(.insecureTransport)) {
            try WebSocketConfiguration(endpoint: URL(string: "ws://remote.invalid")!, maximumMessageBytes: 64,
                                      allowInsecureLoopback: true)
        }
        #expect(throws: (any Error).self) { try NetworkOrigin(URL(string: "wss://service.invalid")!) }
    }
    @Test func reservedHeadersProtocolsAndOpaqueConflicts() throws {
        for field in ["HOST", "Upgrade", "Cookie", "Origin", "Proxy-Authorization", "Sec-WebSocket-Protocol", "Sec-WebSocket-Extensions"] {
            #expect(throws: WebSocketError.invalidInput(.reservedHeader)) {
                try webSocketTestConfiguration(headers: HTTPHeaders([field: "synthetic"]))
            }
        }
        for protocols in [[""], ["a b"], ["a", "a"], ["非ASCII"]] {
            #expect(throws: WebSocketError.invalidInput(.invalidSubprotocol)) {
                try webSocketTestConfiguration(protocols: protocols)
            }
        }
        _ = try webSocketTestConfiguration(protocols: ["A", "a"])
        let origin = try WebSocketValidation.origin(URL(string: "wss://service.invalid")!, allowInsecureLoopback: false)
        let headers = try HTTPHeaders(["Authorization": "synthetic-A"])
        #expect(try WebSocketValidation.merged(headers, headers, origin: origin) == headers)
        #expect(throws: WebSocketError.invalidInput(.conflictingHeaders)) {
            try WebSocketValidation.merged(headers, HTTPHeaders(["authorization": "synthetic-B"]), origin: origin)
        }
    }
    @Test func closeWireAndUTF8Boundaries() throws {
        #expect(WebSocketCloseCode.normal.rawValue == 1000)
        #expect(WebSocketCloseCode.goingAway.rawValue == 1001)
        for code: UInt16 in [3000, 4001, 4999] {
            #expect(try WebSocketCloseCode.application(code).rawValue == code)
            #expect(URLSessionWebSocketTask.CloseCode(rawValue: Int(code)) != nil)
        }
        for code: UInt16 in [0, 1000, 1005, 1006, 1015, 2999, 5000, 65535] {
            #expect(throws: WebSocketError.invalidInput(.invalidCloseCode)) { try WebSocketCloseCode.application(code) }
        }
        try WebSocketValidation.closeReason(String(repeating: "a", count: 123))
        #expect(throws: WebSocketError.invalidInput(.invalidCloseReason)) {
            try WebSocketValidation.closeReason(String(repeating: "é", count: 62))
        }
        #expect(try WebSocketValidation.peerClose(code: 1005, reason: nil).code == nil)
        for (code, data) in [(1005, Data([65])), (1006, Data()), (1000, Data([0xff])), (1000, Data(repeating: 65, count: 124))] {
            #expect(throws: WebSocketError.protocolViolation) { try WebSocketValidation.peerClose(code: code, reason: data) }
        }
    }
    @Test func sensitiveDefaultsAreRedacted() throws {
        let configuration = try WebSocketConfiguration(endpoint: URL(string: "wss://private.invalid/SECRET?q=TOKEN")!,
            maximumMessageBytes: 64, headers: HTTPHeaders(["Authorization": "SECRET"]))
        let values = [String(reflecting: configuration), String(reflecting: WebSocketMessage.text("SECRET")),
            String(reflecting: WebSocketMessage.binary(Data("SECRET".utf8))),
            String(reflecting: WebSocketCloseInfo(code: 4001, reason: "SECRET")),
            String(reflecting: WebSocketError.transport(.init(domain: "SECRET", code: 1)))]
        #expect(values.allSatisfy { !$0.contains("SECRET") && !$0.contains("TOKEN") && !$0.contains("private.invalid") })
    }
}
#endif
