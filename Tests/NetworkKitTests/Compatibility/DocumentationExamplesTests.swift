import Foundation
import Testing
import NetworkKit

// DOC-EXAMPLE: typed BEGIN
struct GuideItem: Codable, Sendable, Equatable {
    let id: Int
    let name: String
}

struct GuideItemCall: Endpoint {
    let path: EndpointPath
    let query: [HTTPQueryItem]
    let responseStrategy: ResponseStrategy<GuideItem> = .json()

    init(id: Int) throws {
        path = try EndpointPath(segments: ["items", String(id)])
        query = [try HTTPQueryItem(name: "include", value: "summary")]
    }
}

func guideLoadItem(using client: any NetworkClient, id: Int) async throws -> NetworkResponse<GuideItem> {
    try await client.send(GuideItemCall(id: id))
}
// DOC-EXAMPLE: typed END

// DOC-EXAMPLE: formats BEGIN
func guideReadFormats(using client: any NetworkClient, url: URL) async throws -> (Data, String, EmptyResponse) {
    let request = URLRequest(url: url)
    let data = try await client.send(request, response: .data)
    let text = try await client.send(request, response: .text)
    let empty = try await client.send(request, response: .empty)
    return (data.value, text.value, empty.value)
}

func guideReadExplicitErrorBody(using client: any NetworkClient, url: URL) async throws -> Data {
    let options = try NetworkCallOptions(
        inactivityTimeout: 15, totalTimeout: 45,
        acceptedStatuses: HTTPStatusPolicy(codes: [200, 404]), authentication: .disabled)
    return try await client.send(URLRequest(url: url), response: .data, options: options).value
}

/// Opt in only when the service's read semantics permit replay.
func guideReadWithOneRetry(using client: any NetworkClient, url: URL) async throws -> Data {
    let options = try NetworkCallOptions(retry: .oneRetryForSafeReads)
    return try await client.send(URLRequest(url: url), response: .data, options: options).value
}

func guideEncodeItem(_ item: GuideItem, baseURL: URL) throws -> URLRequest {
    struct CreateItem: Endpoint {
        typealias Response = EmptyResponse
        let path: EndpointPath
        let method: HTTPMethod = .post
        let body: RequestBody?
    }
    let call = CreateItem(path: try EndpointPath(segments: ["items"]), body: .json(item))
    return try call.request(configuration: NetworkConfiguration(baseURL: baseURL))
}
// DOC-EXAMPLE: formats END

// DOC-EXAMPLE: ownership BEGIN
func guideMakeOwnedClient(baseURL: URL) throws -> APIClient {
    try APIClient(configuration: NetworkConfiguration(baseURL: baseURL))
}

func guideMakeBorrowedClient(baseURL: URL) throws -> (APIClient, URLSession) {
    let settings = URLSessionConfiguration.ephemeral
    settings.httpCookieStorage = nil
    settings.httpShouldSetCookies = false
    settings.httpCookieAcceptPolicy = .never
    settings.urlCredentialStorage = nil
    settings.urlCache = nil
    settings.requestCachePolicy = .reloadIgnoringLocalCacheData
    let session = URLSession(configuration: settings)
    do {
        let client = try APIClient(configuration: NetworkConfiguration(baseURL: baseURL), session: session)
        return (client, session)
    } catch {
        session.invalidateAndCancel()
        throw error
    }
}

func guideRunAndClose(client: any NetworkClient, id: Int) async throws -> GuideItem {
    do {
        let result = try await guideLoadItem(using: client, id: id)
        await client.shutdown()
        return result.value
    } catch {
        await client.shutdown()
        throw error
    }
}
// DOC-EXAMPLE: ownership END

// DOC-EXAMPLE: authentication BEGIN
actor GuideHeaders: AuthenticationHeaderProvider {
    private let token: String
    init(token: String) { self.token = token }

    func headers(for context: AuthenticationContext) async throws -> HTTPHeaders {
        try Task.checkCancellation()
        return try HTTPHeaders(["Authorization": "Bearer \(token)"])
    }
}

func guideMakeAuthenticatedClient(baseURL: URL, token: String) throws -> APIClient {
    let provider = GuideHeaders(token: token)
    let binding = NetworkAuthentication(provider: provider, account: "selected-account", environment: "production")
    return try APIClient(configuration: NetworkConfiguration(baseURL: baseURL, authentication: binding))
}

func guideSafeFailureCategory(_ error: any Error) -> String {
    if error is CancellationError { return "cancelled" }
    guard let failure = error as? NetworkError else { return "unexpected" }
    switch failure {
    case .invalidRequest: return "invalid-request"
    case .transport: return "transport"
    case .httpStatus: return "http-status"
    case .invalidResponse: return "invalid-response"
    case .encoding: return "encoding"
    case .decoding: return "decoding"
    case .timeout: return "timeout"
    }
}
// DOC-EXAMPLE: authentication END

// DOC-EXAMPLE: testing BEGIN
/// A buffered consumer double: no URLSession, network, retry or production-policy simulation.
struct GuideStubClient: NetworkClient {
    let data: Data
    let status: Int

    func shutdown() async {}

    func send<E: Endpoint>(_ endpoint: E) async throws -> NetworkResponse<E.Response> {
        try Task.checkCancellation()
        let response = HTTPURLResponse(url: URL(string: "https://example.invalid")!,
            statusCode: status, httpVersion: nil, headerFields: [:])!
        return try endpoint.decodeResponse(data, response: response)
    }

    func send<Value: Sendable>(_ request: URLRequest, response strategy: ResponseStrategy<Value>,
                               options: NetworkCallOptions) async throws -> NetworkResponse<Value> {
        try Task.checkCancellation()
        let response = HTTPURLResponse(url: URL(string: "https://example.invalid")!,
            statusCode: status, httpVersion: nil, headerFields: [:])!
        return try strategy.decode(data, response: response, acceptedStatuses: options.acceptedStatuses)
    }
}
// DOC-EXAMPLE: testing END

@Suite struct DocumentationExamplesTests {
    @Test func typedGuideDecodesValueAndMetadata() async throws {
        let client = GuideStubClient(data: Data(#"{"id":7,"name":"guide"}"#.utf8), status: 200)
        let response = try await guideLoadItem(using: client, id: 7)
        #expect(response.value == GuideItem(id: 7, name: "guide"))
        #expect(response.status.code == 200)
        let request = try GuideItemCall(id: 7).request(configuration:
            NetworkConfiguration(baseURL: URL(string: "https://example.invalid/api")!))
        #expect(request.url?.path == "/api/items/7")
        #expect(request.url?.query == "include=summary")
    }

    @Test func formatGuideHandlesBytesTextEmptyAndExplicitStatus() async throws {
        let url = URL(string: "https://example.invalid")!
        let result = try await guideReadFormats(using: GuideStubClient(data: Data("guide".utf8), status: 200), url: url)
        #expect(result.0 == Data("guide".utf8)); #expect(result.1 == "guide"); #expect(result.2 == EmptyResponse())
        let body = try await guideReadExplicitErrorBody(using: GuideStubClient(data: Data("missing".utf8), status: 404), url: url)
        #expect(body == Data("missing".utf8))
        let request = try guideEncodeItem(GuideItem(id: 7, name: "guide"), baseURL: url)
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(try JSONDecoder().decode(GuideItem.self, from: #require(request.httpBody)).id == 7)
    }

    @Test func ownershipGuideConstructsAndClosesBothProfiles() async throws {
        let url = URL(string: "https://example.invalid")!
        let owned = try guideMakeOwnedClient(baseURL: url)
        await owned.shutdown()
        let (borrowed, session) = try guideMakeBorrowedClient(baseURL: url)
        defer { session.invalidateAndCancel() }
        await borrowed.shutdown()
        await #expect(throws: NetworkError.invalidRequest(.clientClosed)) {
            try await borrowed.send(URLRequest(url: url), response: .data)
        }
        let value = try await guideRunAndClose(client: GuideStubClient(data: Data(#"{"id":7,"name":"guide"}"#.utf8), status: 200), id: 7)
        #expect(value.id == 7)
        await #expect(throws: NetworkError.decoding) {
            try await guideRunAndClose(client: GuideStubClient(data: Data(), status: 200), id: 7)
        }
    }

    @Test func authAndErrorGuideUsesPublicBoundariesWithoutNetworking() async throws {
        let client = try guideMakeAuthenticatedClient(baseURL: URL(string: "https://example.invalid")!, token: "synthetic-guide")
        await client.shutdown()
        let errors: [any Error] = [CancellationError(), NetworkError.invalidRequest(.invalidURL),
            NetworkError.transport(.init(URLError(.notConnectedToInternet))),
            NetworkError.httpStatus(try HTTPStatus(401), headers: HTTPHeaders()),
            NetworkError.invalidResponse(.nonHTTPResponse), NetworkError.encoding, NetworkError.decoding,
            NetworkError.timeout(.totalBudget), URLError(.unknown)]
        #expect(errors.map(guideSafeFailureCategory) == ["cancelled", "invalid-request", "transport", "http-status",
            "invalid-response", "encoding", "decoding", "timeout", "unexpected"])
    }
    // Regular import (no @testable): public visibility and original function arities matter.
    @Test func legacyAndFileFunctionReferencesRemainPublic() async throws {
        let initializer: (HTTPHeaders, TimeInterval?, TimeInterval?, HTTPStatusPolicy, AuthenticationPolicy) throws -> NetworkCallOptions =
            NetworkCallOptions.init(headers:inactivityTimeout:totalTimeout:acceptedStatuses:authentication:)
        let legacy = try initializer(HTTPHeaders(), nil, nil, .successful, .automatic)
        #expect(legacy.retry == .disabled)
        let factory: (NetworkConfiguration) throws -> APIClient = APIClient.init(configuration:)
        let borrowedFactory: (NetworkConfiguration, URLSession, SessionStorageProfile) throws -> APIClient = APIClient.init(configuration:session:storage:)
        _ = borrowedFactory
        let conformer: any NetworkClient = GuideStubClient(data: Data(), status: 200)
        await conformer.shutdown()
        let base = URL(string: "https://example.invalid")!
        let client = try factory(NetworkConfiguration(baseURL: base))
        let raw: (URLRequest, ResponseStrategy<Data>, NetworkCallOptions) async throws -> NetworkResponse<Data> = client.send
        _ = raw // Never perform live traffic in this compatibility check.
        let file: (URLRequest, Int64, DownloadOptions) async throws -> NetworkResponse<DownloadedFile> = client.download
        await #expect(throws: NetworkError.invalidRequest(.invalidConfiguration)) { try await file(URLRequest(url: base), 0, .default) }
        await client.shutdown()
    }

}
