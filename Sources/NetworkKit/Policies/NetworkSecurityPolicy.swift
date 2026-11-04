import Foundation
import Darwin

/// A validated scheme/host/effective-port identity. Paths are not part of an origin.
public struct NetworkOrigin: Sendable, Hashable, CustomStringConvertible, CustomDebugStringConvertible {
    public let scheme: String
    public let host: String
    public let port: Int

    public init(_ url: URL) throws {
        let components = try URLInputValidation.components(url, isBase: false)
        scheme = components.scheme!.lowercased()
        var host = try URLInputValidation.normalizedHost(components)
        if host.contains(":") {
            var address = in6_addr()
            guard host.withCString({ inet_pton(AF_INET6, $0, &address) }) == 1 else {
                throw NetworkError.invalidRequest(.invalidURL)
            }
            var output = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
            guard inet_ntop(AF_INET6, &address, &output, socklen_t(output.count)) != nil else {
                throw NetworkError.invalidRequest(.invalidURL)
            }
            host = output.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
        }
        self.host = host
        port = components.port ?? (scheme == "https" ? 443 : 80)
    }

    internal var isLoopback: Bool {
        if host == "localhost" { return true }
        if host.contains(":") { return host == "::1" }
        var address = in_addr()
        guard host.withCString({ inet_pton(AF_INET, $0, &address) }) == 1 else { return false }
        return withUnsafeBytes(of: address) { $0.first == 127 }
    }

    public var description: String { "NetworkOrigin" }
    public var debugDescription: String { description }
}

/// HTTPS/system trust by default. Extra raw origins never authorize automatic redirects.
public struct NetworkSecurityPolicy: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    public let allowInsecureLoopback: Bool
    public let additionalRawOrigins: Set<NetworkOrigin>

    public init(allowInsecureLoopback: Bool = false, additionalRawOrigins: Set<NetworkOrigin> = []) {
        self.allowInsecureLoopback = allowInsecureLoopback
        self.additionalRawOrigins = additionalRawOrigins
    }
    public static let `default` = Self()

    internal func validateURL(_ url: URL, baseURL: URL? = nil,
                              allowAdditionalOrigins: Bool = false) throws -> NetworkOrigin {
        let origin = try NetworkOrigin(url)
        func permittedScheme(_ origin: NetworkOrigin) -> Bool {
            origin.scheme == "https" || (allowInsecureLoopback && origin.scheme == "http" && origin.isLoopback)
        }
        guard permittedScheme(origin) else { throw NetworkError.invalidRequest(.insecureTransport) }
        if let baseURL {
            let base = try NetworkOrigin(baseURL)
            guard permittedScheme(base) else { throw NetworkError.invalidRequest(.insecureTransport) }
            guard origin == base || (allowAdditionalOrigins && additionalRawOrigins.contains(origin)) else {
                throw NetworkError.invalidRequest(.unpermittedOrigin)
            }
        }
        return origin
    }

    /// Loopback HTTP only permits ordinary public metadata fields. Custom/auth/cookie
    /// fields require HTTPS; arbitrary values cannot be classified as secrets by a library.
    internal func validateHeaders(_ headers: HTTPHeaders, origin: NetworkOrigin) throws {
        guard origin.scheme == "http" else { return }
        let publicFields: Set<String> = ["accept", "accept-language", "accept-encoding", "content-type",
            "user-agent", "cache-control", "pragma", "if-match", "if-none-match", "if-modified-since",
            "if-unmodified-since", "range", "if-range"]
        guard Set(headers.fields.keys).isSubset(of: publicFields) else {
            throw NetworkError.invalidRequest(.credentialsOverHTTP)
        }
    }

    internal func validateRequest(_ request: URLRequest, baseURL: URL? = nil,
                                  allowAdditionalOrigins: Bool = false) throws -> NetworkOrigin {
        guard let url = request.url else { throw NetworkError.invalidRequest(.invalidURL) }
        let origin = try validateURL(url, baseURL: baseURL, allowAdditionalOrigins: allowAdditionalOrigins)
        try validateHeaders(HTTPHeaders(request.allHTTPHeaderFields ?? [:]), origin: origin)
        return origin
    }

    public var description: String { "NetworkSecurityPolicy(additionalOriginCount: \(additionalRawOrigins.count))" }
    public var debugDescription: String { description }
}
