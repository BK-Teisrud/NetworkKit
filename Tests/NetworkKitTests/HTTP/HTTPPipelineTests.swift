import Foundation
import Testing
@testable import NetworkKit

private struct PipelineModel: Decodable, Sendable, Equatable { let name: String }
private struct PipelineEndpoint<Value: Sendable>: Endpoint {
    let path: EndpointPath
    let responseStrategy: ResponseStrategy<Value>
    var options: NetworkCallOptions = .default
}

private actor PipelineTransport: NetworkTransport {
    let operation: @Sendable (URLRequest) async throws -> TransportResponse
    private(set) var requests: [URLRequest] = []
    init(_ operation: @escaping @Sendable (URLRequest) async throws -> TransportResponse) {
        self.operation = operation
    }
    func send(_ request: URLRequest) async throws -> TransportResponse {
        requests.append(request)
        return try await operation(request)
    }
}

@Suite struct HTTPPipelineTests {
    private let base = URL(string: "https://example.invalid")!

    private func call<Value: Sendable>(_ client: any NetworkClient, url: URL,
                                       strategy: ResponseStrategy<Value>, raw: Bool,
                                       options: NetworkCallOptions = .default) async throws -> NetworkResponse<Value> {
        if raw { return try await client.send(URLRequest(url: url), response: strategy, options: options) }
        let path = try EndpointPath(segments: url.pathComponents.filter { $0 != "/" })
        return try await client.send(PipelineEndpoint(path: path, responseStrategy: strategy, options: options))
    }

    private func nativeClient() throws -> APIClient {
        let configuration = NetworkConfiguration(baseURL: base)
        let settings = URLSessionTransport.configuration()
        #if os(watchOS)
        let transport = try URLSessionTransport(ownedConfiguration: settings,
            dataOperation: SessionStubProtocol.dataOperation,
            securityPolicy: configuration.security, baseURL: configuration.baseURL)
        return try APIClient(configuration: configuration, transport: transport)
        #else
        settings.protocolClasses = [SessionStubProtocol.self]
        let transport = try URLSessionTransport(ownedConfiguration: settings,
            securityPolicy: configuration.security, baseURL: configuration.baseURL)
        return try APIClient(configuration: configuration, transport: transport)
        #endif
    }

    @Test(arguments: [false, true]) func jsonThroughSession(raw: Bool) async throws {
        let url = SessionStubProtocol.install(.init(data: Data(#"{"name":"result"}"#.utf8), status: 201,
            headers: ["Content-Type": "application/json", "X-Result": "metadata"]))
        defer { SessionStubProtocol.remove(url) }
        let result = try await call(nativeClient(), url: url, strategy: .json(PipelineModel.self), raw: raw)
        #expect(result.value == PipelineModel(name: "result"))
        #expect(result.status.code == 201)
        #expect(result.headers["x-result"] == "metadata")
    }

    @Test(arguments: [false, true]) func dataTextAndEmptyThroughSession(raw: Bool) async throws {
        let bytes = Data("Hello ø".utf8)
        let url = SessionStubProtocol.install(.init(data: bytes, status: 200, headers: [:]))
        let empty = SessionStubProtocol.install(.init(data: Data(), status: 204, headers: [:]))
        defer { SessionStubProtocol.remove(url); SessionStubProtocol.remove(empty) }
        let client = try nativeClient()
        #expect(try await call(client, url: url, strategy: .data, raw: raw).value == bytes)
        #expect(try await call(client, url: url, strategy: .text, raw: raw).value == "Hello ø")
        #expect(try await call(client, url: empty, strategy: .empty, raw: raw).status.code == 204)
    }

    @Test(arguments: [false, true]) func statusPrecedesDecodingAndExplicitPolicyWorks(raw: Bool) async throws {
        let url = SessionStubProtocol.install(.init(data: Data(#"{"name":"denied"}"#.utf8), status: 401, headers: [:]))
        defer { SessionStubProtocol.remove(url) }
        let client = try nativeClient()
        do {
            _ = try await call(client, url: url, strategy: .json(PipelineModel.self), raw: raw)
            Issue.record("Expected HTTP failure")
        } catch let error as NetworkError {
            guard case .httpStatus(let status, _) = error else { Issue.record("Wrong category"); return }
            #expect(status.code == 401)
        }
        let options = try NetworkCallOptions(acceptedStatuses: HTTPStatusPolicy(codes: [401]))
        #expect(try await call(client, url: url, strategy: .json(PipelineModel.self), raw: raw, options: options).value.name == "denied")
    }

    @Test(arguments: [false, true]) func invalidJSONAndContentTypeRemainStructured(raw: Bool) async throws {
        let url = SessionStubProtocol.install(.init(data: Data("bad JSON".utf8), status: 200, headers: [:]))
        defer { SessionStubProtocol.remove(url) }
        await #expect(throws: NetworkError.decoding) {
            try await call(nativeClient(), url: url, strategy: .json(PipelineModel.self), raw: raw)
        }
        let wrongType = SessionStubProtocol.install(.init(data: Data("bad JSON".utf8), status: 200,
                                                          headers: ["Content-Type": "text/plain"]))
        defer { SessionStubProtocol.remove(wrongType) }
        await #expect(throws: NetworkError.invalidResponse(.unexpectedContentType)) {
            try await call(nativeClient(), url: wrongType, strategy: .json(PipelineModel.self), raw: raw)
        }
    }

    @Test(arguments: [false, true]) func transportErrorsAreSanitizedAndNeverRetried(raw: Bool) async throws {
        let transport = PipelineTransport { _ in
            throw NSError(domain: NSURLErrorDomain, code: URLError.serverCertificateUntrusted.rawValue,
                          userInfo: [NSLocalizedDescriptionKey: "SECRET", NSURLErrorFailingURLStringErrorKey: "https://SECRET"])
        }
        let client = try APIClient(configuration: NetworkConfiguration(baseURL: base), transport: transport)
        do {
            _ = try await call(client, url: base, strategy: .data, raw: raw)
            Issue.record("Expected transport failure")
        } catch let error as NetworkError {
            #expect(error == .transport(.init(domain: NSURLErrorDomain, code: URLError.serverCertificateUntrusted.rawValue)))
            #expect(!String(reflecting: error).contains("SECRET"))
        }
        #expect(await transport.requests.count == 1)
    }

    @Test(arguments: [false, true]) func systemTimeoutAndUnexplainedCancellationAreDistinct(raw: Bool) async throws {
        for code in [URLError.timedOut, URLError.cancelled] {
            let transport = PipelineTransport { _ in throw URLError(code) }
            let client = try APIClient(configuration: NetworkConfiguration(baseURL: base), transport: transport)
            let expected: NetworkError = code == .timedOut ? .timeout(.system) : .transport(.init(URLError(code)))
            await #expect(throws: expected) { try await call(client, url: base, strategy: .data, raw: raw) }
            #expect(await transport.requests.count == 1)
        }
    }

    @Test(arguments: [false, true]) func securityRejectsBeforeTransport(raw: Bool) async throws {
        let transport = PipelineTransport { _ in Issue.record("Must not send"); throw URLError(.unknown) }
        let config = NetworkConfiguration(baseURL: base, headers: try HTTPHeaders(["Host": "SECRET"]))
        let client = try APIClient(configuration: config, transport: transport)
        await #expect(throws: NetworkError.invalidRequest(.unsupportedRequest)) {
            try await call(client, url: base, strategy: .data, raw: raw)
        }
        #expect(await transport.requests.isEmpty)
    }

    @Test(arguments: [false, true]) func preCancelledCallsDoNotSend(raw: Bool) async throws {
        let transport = PipelineTransport { _ in Issue.record("Must not send"); throw URLError(.unknown) }
        let client = try APIClient(configuration: NetworkConfiguration(baseURL: base), transport: transport)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await call(client, url: base, strategy: .data, raw: raw)
        }
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(await transport.requests.isEmpty)
    }

    @Test func constructorsRejectInsecureBaseAndIncompatibleSession() throws {
        #expect(throws: NetworkError.invalidRequest(.insecureTransport)) {
            try APIClient(configuration: NetworkConfiguration(baseURL: URL(string: "http://example.invalid")!))
        }
        let session = URLSession(configuration: .default)
        defer { session.invalidateAndCancel() }
        #expect(throws: NetworkError.invalidRequest(.invalidConfiguration)) {
            try APIClient(configuration: NetworkConfiguration(baseURL: base), session: session)
        }
        _ = try APIClient(configuration: NetworkConfiguration(baseURL: base))
    }

    @Test(arguments: [false, true]) func sessionFailureUsesSharedNormalization(raw: Bool) async throws {
        // No installed fixture: native URLProtocol (scripted I/O on watchOS)
        // fails deterministically without contacting the reserved hostname.
        let url = base.appendingPathComponent(UUID().uuidString)
        await #expect(throws: NetworkError.transport(.init(URLError(.resourceUnavailable)))) {
            try await call(nativeClient(), url: url, strategy: .data, raw: raw)
        }
    }

    @Test(arguments: [false, true]) func nonHTTPResponseIsRejectedAfterTransport(raw: Bool) async throws {
        let transport = PipelineTransport { request in
            TransportResponse(data: Data(), response: URLResponse(url: request.url!, mimeType: nil,
                                                                  expectedContentLength: 0, textEncodingName: nil))
        }
        let client = try APIClient(configuration: NetworkConfiguration(baseURL: base), transport: transport)
        await #expect(throws: NetworkError.invalidResponse(.nonHTTPResponse)) {
            try await call(client, url: base, strategy: .data, raw: raw)
        }
        #expect(await transport.requests.count == 1)
    }

    @Test(arguments: [false, true]) func preparedHeadersAndTimeoutReachTransport(raw: Bool) async throws {
        let transport = PipelineTransport { request in
            #expect(request.value(forHTTPHeaderField: "X-Default") == "default")
            #expect(request.value(forHTTPHeaderField: "X-Call") == "call")
            #expect(request.timeoutInterval == 12)
            return TransportResponse(data: Data(), response: HTTPURLResponse(url: request.url!, statusCode: 204,
                                                                            httpVersion: nil, headerFields: [:])!)
        }
        let client = try APIClient(configuration: NetworkConfiguration(baseURL: base,
            headers: HTTPHeaders(["X-Default": "default", "X-Call": "overridden"])), transport: transport)
        let options = try NetworkCallOptions(headers: HTTPHeaders(["X-Call": "call"]), inactivityTimeout: 12)
        _ = try await call(client, url: base, strategy: .empty, raw: raw, options: options)
        #expect(await transport.requests.count == 1)
    }
}
