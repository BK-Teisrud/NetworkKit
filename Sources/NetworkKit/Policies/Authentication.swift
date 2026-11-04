import Foundation

/// Minimal per-operation input. No URL path/query, body or request headers are exposed.
public struct AuthenticationContext: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    public let origin: NetworkOrigin
    public let requestID: UUID
    public let method: HTTPMethod
    public let account: String?
    public let environment: String?
    public var description: String { "AuthenticationContext" }
    public var debugDescription: String { description }
}

/// App-owned, concurrency-safe credential lookup. No login, storage, refresh or replay.
public protocol AuthenticationHeaderProvider: Sendable {
    func headers(for context: AuthenticationContext) async throws -> HTTPHeaders
}

/// Immutable account/environment binding for this client's base origin only.
/// Use separate client bindings for different accounts; provider implementations may be actors.
public struct NetworkAuthentication: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    public let provider: any AuthenticationHeaderProvider
    public let account: String?
    public let environment: String?

    public init(provider: any AuthenticationHeaderProvider, account: String? = nil, environment: String? = nil) {
        self.provider = provider
        self.account = account
        self.environment = environment
    }
    public var description: String { "NetworkAuthentication" }
    public var debugDescription: String { description }
}

/// Disabled skips only the provider; explicit/default headers still follow security policy.
public enum AuthenticationPolicy: Sendable {
    case automatic
    case disabled
}

internal enum RequestAuthentication {
    static func apply(_ prepared: PreparedRequest, configuration: NetworkConfiguration,
                      policy: AuthenticationPolicy, requestID: UUID, checkpoint: @Sendable () throws -> Void) async throws -> PreparedRequest {
        try checkpoint()
        guard policy == .automatic, let authentication = configuration.authentication else { return prepared }
        guard let url = prepared.request.url else { throw NetworkError.invalidRequest(.invalidURL) }
        let origin = try NetworkOrigin(url)
        // Additional raw origins never inherit this client's provider or default headers.
        guard origin == (try NetworkOrigin(configuration.baseURL)) else { return prepared }
        guard origin.scheme == "https" else { throw NetworkError.invalidRequest(.credentialsOverHTTP) }
        let context = AuthenticationContext(origin: origin, requestID: requestID,
            method: try HTTPMethod(prepared.request.httpMethod ?? "GET"),
            account: authentication.account, environment: authentication.environment)
        let supplied: HTTPHeaders
        do {
            supplied = try await authentication.provider.headers(for: context)
        } catch is CancellationError { throw CancellationError() }
        catch NetworkError.timeout(let reason) { throw NetworkError.timeout(reason) }
        catch { throw NetworkError.invalidRequest(.authenticationProviderFailure) }
        try checkpoint()
        try RequestBuilder.validateHeaders(supplied)
        var fields = try HTTPHeaders(prepared.request.allHTTPHeaderFields ?? [:]).fields
        for (name, value) in supplied.fields {
            if let existing = fields[name], !existing.utf8.elementsEqual(value.utf8) {
                throw NetworkError.invalidRequest(.conflictingHeaders)
            }
            fields[name] = value
        }
        var request = prepared.request
        request.allHTTPHeaderFields = fields
        _ = try configuration.security.validateRequest(request, baseURL: configuration.baseURL)
        try checkpoint()
        return PreparedRequest(request: request, timeouts: prepared.timeouts, acceptedStatuses: prepared.acceptedStatuses, retry: prepared.retry)
    }
}
