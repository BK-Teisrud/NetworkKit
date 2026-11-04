import Foundation
import Testing
@testable import NetworkKit

private struct F1Payload: Codable, Sendable, Equatable { let name: String }
private struct F1Call<Value: Sendable>: Endpoint {
    let path: EndpointPath
    let responseStrategy: ResponseStrategy<Value>
    var method: HTTPMethod = .get
    var query: [HTTPQueryItem] = []
    var body: RequestBody? = nil
    var options: NetworkCallOptions = .default
}
private struct F1FailingEncoder: Encodable, Sendable {
    func encode(to encoder: any Encoder) throws {
        throw NSError(domain: "SECRET", code: 1, userInfo: [NSLocalizedDescriptionKey: "SECRET"])
    }
}
private struct F1ForbiddenDecoder: Decodable, Sendable {
    init(from decoder: any Decoder) throws { Issue.record("Rejected HTTP status must precede decoding") }
}
private actor F1RecordingTransport: NetworkTransport {
    let data: Data
    let status: Int
    let headers: [String: String]
    private(set) var requests: [URLRequest] = []
    init(data: Data = Data(), status: Int = 200, headers: [String: String] = [:]) {
        self.data = data; self.status = status; self.headers = headers
    }
    func send(_ request: URLRequest) async throws -> TransportResponse {
        requests.append(request)
        return TransportResponse(data: data, response: HTTPURLResponse(url: request.url!, statusCode: status,
                                                                      httpVersion: nil, headerFields: headers)!)
    }
}

/// Gate-level contracts using scripted transport; native transport evidence stays
/// in HTTPPipelineTests, SessionTransportTests and RedirectIntegrationTests.
@Suite struct F1AcceptanceTests {
    private let base = URL(string: "https://example.invalid/api")!

    @Test func typedAndRawPOSTHaveRequestAndResponseParity() async throws {
        let transport = F1RecordingTransport(data: Data(#"{"name":"response"}"#.utf8), status: 201,
                                              headers: ["Content-Type": "application/json", "X-Server": "metadata"])
        let client = try APIClient(configuration: NetworkConfiguration(baseURL: base,
            headers: HTTPHeaders(["X-Client": "default", "X-Mode": "default"])), transport: transport)
        let options = try NetworkCallOptions(headers: HTTPHeaders(["X-Mode": "call"]), inactivityTimeout: 12)
        let typed = F1Call(path: try EndpointPath(segments: ["items", "42"]),
            responseStrategy: ResponseStrategy<F1Payload>.json(), method: .post,
            query: [try HTTPQueryItem(name: "tag", value: "a b"), try HTTPQueryItem(name: "tag", value: ""),
                    try HTTPQueryItem(name: "flag")], body: .json(F1Payload(name: "payload")), options: options)
        let first = try await client.send(typed)
        var raw = URLRequest(url: URL(string: "https://example.invalid/api/items/42?tag=a%20b&tag=&flag")!)
        raw.httpMethod = "POST"
        raw.httpBody = Data(#"{"name":"payload"}"#.utf8)
        raw.setValue("application/json", forHTTPHeaderField: "Content-Type")
        raw.setValue("raw", forHTTPHeaderField: "X-Mode")
        raw.timeoutInterval = 1 // Explicit call policy, rather than this field, governs execution.
        let second = try await client.send(raw, response: .json(F1Payload.self), options: options)
        #expect(first == second)
        #expect(first.value.name == "response")
        #expect(first.status.code == 201)
        #expect(first.headers["x-server"] == "metadata")
        let requests = await transport.requests
        #expect(requests.count == 2)
        for request in requests {
            #expect(request.url == raw.url)
            #expect(request.httpMethod == "POST")
            #expect(request.httpBody == raw.httpBody)
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
            #expect(request.value(forHTTPHeaderField: "X-Mode") == "call")
            #expect(request.value(forHTTPHeaderField: "X-Client") == "default")
            #expect(request.timeoutInterval == 12)
        }
    }

    @Test func encodingFailureDoesNotSendOrPoisonClient() async throws {
        let transport = F1RecordingTransport(status: 204)
        let client = try APIClient(configuration: NetworkConfiguration(baseURL: base), transport: transport)
        let call = F1Call(path: try EndpointPath(segments: []), responseStrategy: ResponseStrategy<EmptyResponse>.empty,
                          method: .post, body: .json(F1FailingEncoder()))
        await #expect(throws: NetworkError.encoding) { try await client.send(call) }
        #expect(await transport.requests.isEmpty)
        #expect(!NetworkError.encoding.localizedDescription.contains("SECRET"))
        #expect(try await client.send(URLRequest(url: base), response: .empty).status.code == 204)
        #expect(await transport.requests.count == 1)
    }

    @Test(arguments: [false, true]) func HTTPFailurePrecedesDecoderWithoutRetry(raw: Bool) async throws {
        let transport = F1RecordingTransport(data: Data("SECRET malformed body".utf8), status: 503,
                                              headers: ["Content-Type": "application/json", "X-Server": "metadata"])
        let client = try APIClient(configuration: NetworkConfiguration(baseURL: base), transport: transport)
        do {
            if raw { _ = try await client.send(URLRequest(url: base), response: .json(F1ForbiddenDecoder.self)) }
            else { _ = try await client.send(F1Call(path: EndpointPath(segments: []),
                                                    responseStrategy: ResponseStrategy<F1ForbiddenDecoder>.json())) }
            Issue.record("Expected rejected status")
        } catch let error as NetworkError {
            guard case .httpStatus(let status, let headers) = error else { Issue.record("Wrong error category"); return }
            #expect(status.code == 503)
            #expect(headers["x-server"] == "metadata")
            #expect(!String(reflecting: error).contains("SECRET"))
        }
        #expect(await transport.requests.count == 1)
    }

    @Test(arguments: [false, true]) func invalidUTF8IsDecodingFailureForBothInputs(raw: Bool) async throws {
        let transport = F1RecordingTransport(data: Data([0xff]), headers: ["Content-Type": "text/plain; charset=utf-8"])
        let client = try APIClient(configuration: NetworkConfiguration(baseURL: base), transport: transport)
        await #expect(throws: NetworkError.decoding) {
            if raw { _ = try await client.send(URLRequest(url: base), response: .text) }
            else { _ = try await client.send(F1Call(path: EndpointPath(segments: []),
                                                   responseStrategy: ResponseStrategy<String>.text)) }
        }
        #expect(await transport.requests.count == 1)
    }

    @Test func extraRawOriginDropsDefaultsAndDeniedOriginDoesNotSend() async throws {
        let extra = URL(string: "https://other.invalid/items")!
        let policy = NetworkSecurityPolicy(additionalRawOrigins: [try NetworkOrigin(extra)])
        let configuration = NetworkConfiguration(baseURL: base,
            headers: try HTTPHeaders(["Authorization": "SECRET", "X-Default": "SECRET"]), security: policy)
        let transport = F1RecordingTransport(status: 204)
        let client = try APIClient(configuration: configuration, transport: transport)
        await #expect(throws: NetworkError.invalidRequest(.unpermittedOrigin)) {
            try await client.send(URLRequest(url: URL(string: "https://denied.invalid")!), response: .empty)
        }
        #expect(await transport.requests.isEmpty)
        var request = URLRequest(url: extra)
        request.setValue("explicit", forHTTPHeaderField: "X-Destination")
        _ = try await client.send(request, response: .empty)
        let sent = try #require(await transport.requests.first)
        #expect(sent.url == extra)
        #expect(sent.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(sent.value(forHTTPHeaderField: "X-Default") == nil)
        #expect(sent.value(forHTTPHeaderField: "X-Destination") == "explicit")
        #expect(await transport.requests.count == 1)
    }

    @Test(arguments: [false, true]) func loopbackCredentialsFailBeforeTransport(raw: Bool) async throws {
        let local = URL(string: "http://localhost:8080")!
        let transport = F1RecordingTransport()
        let client = try APIClient(configuration: NetworkConfiguration(baseURL: local,
            security: NetworkSecurityPolicy(allowInsecureLoopback: true)), transport: transport)
        let options = try NetworkCallOptions(headers: HTTPHeaders(["Authorization": "SECRET"]))
        await #expect(throws: NetworkError.invalidRequest(.credentialsOverHTTP)) {
            if raw { _ = try await client.send(URLRequest(url: local), response: .empty, options: options) }
            else { _ = try await client.send(F1Call(path: EndpointPath(segments: []),
                responseStrategy: ResponseStrategy<EmptyResponse>.empty, options: options)) }
        }
        #expect(await transport.requests.isEmpty)
    }
}
