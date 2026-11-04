import Foundation

/// Immutable, validated limits in seconds. A shorter total budget is valid.
public struct NetworkTimeouts: Sendable, Equatable {
    public let inactivity: TimeInterval
    public let total: TimeInterval

    public init(inactivity: TimeInterval = 30, total: TimeInterval = 60) throws {
        guard inactivity.isFinite, inactivity > 0, total.isFinite, total > 0 else {
            throw NetworkError.invalidRequest(.invalidConfiguration)
        }
        self.inactivity = inactivity
        self.total = total
    }

    public static let `default` = NetworkTimeouts()

    private init() {
        inactivity = 30
        total = 60
    }
}

/// Immutable client settings. URL/security validation belongs to request construction.
public struct NetworkConfiguration: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    public let baseURL: URL
    public let headers: HTTPHeaders
    public let security: NetworkSecurityPolicy
    public let timeouts: NetworkTimeouts
    public let authentication: NetworkAuthentication?
    public let diagnostics: (any NetworkDiagnosticSink)?

    public init(baseURL: URL, headers: HTTPHeaders = HTTPHeaders(),
                timeouts: NetworkTimeouts = .default, security: NetworkSecurityPolicy = .default,
                authentication: NetworkAuthentication? = nil, diagnostics: (any NetworkDiagnosticSink)? = nil) {
        self.baseURL = baseURL
        self.headers = headers
        self.timeouts = timeouts
        self.security = security
        self.authentication = authentication
        self.diagnostics = diagnostics
    }

    public var description: String { "NetworkConfiguration(headerCount: \(headers.count))" }
    public var debugDescription: String { description }
}

/// Explicit call overrides. Nil inherits the corresponding client limit.
public struct NetworkCallOptions: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    public let headers: HTTPHeaders
    public let inactivityTimeout: TimeInterval?
    public let totalTimeout: TimeInterval?
    public let acceptedStatuses: HTTPStatusPolicy
    public let authentication: AuthenticationPolicy
    /// Disabled by default; opt in only for semantically safe bodyless reads.
    public let retry: RetryPolicy

    /// Preserves the pre-retry initializer, including references used as function values.
    public init(headers: HTTPHeaders = HTTPHeaders(), inactivityTimeout: TimeInterval? = nil,
                totalTimeout: TimeInterval? = nil, acceptedStatuses: HTTPStatusPolicy = .successful,
                authentication: AuthenticationPolicy = .automatic) throws {
        try self.init(headers: headers, inactivityTimeout: inactivityTimeout, totalTimeout: totalTimeout,
                      acceptedStatuses: acceptedStatuses, authentication: authentication, retry: .disabled)
    }

    /// Explicit replay selection; all other call overrides retain their original defaults.
    public init(headers: HTTPHeaders = HTTPHeaders(), inactivityTimeout: TimeInterval? = nil,
                totalTimeout: TimeInterval? = nil, acceptedStatuses: HTTPStatusPolicy = .successful,
                authentication: AuthenticationPolicy = .automatic, retry: RetryPolicy) throws {
        for limit in [inactivityTimeout, totalTimeout].compactMap({ $0 }) {
            guard limit.isFinite, limit > 0 else {
                throw NetworkError.invalidRequest(.invalidConfiguration)
            }
        }
        self.headers = headers
        self.inactivityTimeout = inactivityTimeout
        self.totalTimeout = totalTimeout
        self.acceptedStatuses = acceptedStatuses
        self.authentication = authentication
        self.retry = retry
    }

    public static let `default` = NetworkCallOptions()

    private init() {
        headers = HTTPHeaders()
        inactivityTimeout = nil
        totalTimeout = nil
        acceptedStatuses = .successful
        authentication = .automatic
        retry = .disabled
    }

    public var description: String { "NetworkCallOptions(headerCount: \(headers.count))" }
    public var debugDescription: String { description }
}

/// A new value for every operation; no shared mutable encoder/session state.
internal struct ConfigurationSnapshot: Sendable {
    let baseURL: URL
    let headers: HTTPHeaders
    let timeouts: NetworkTimeouts
    let acceptedStatuses: HTTPStatusPolicy

    init(configuration: NetworkConfiguration, options: NetworkCallOptions) throws {
        baseURL = configuration.baseURL
        acceptedStatuses = options.acceptedStatuses
        headers = try HTTPHeaders(configuration.headers.fields.merging(options.headers.fields) { _, call in call })
        timeouts = try NetworkTimeouts(
            inactivity: options.inactivityTimeout ?? configuration.timeouts.inactivity,
            total: options.totalTimeout ?? configuration.timeouts.total)
    }
}
