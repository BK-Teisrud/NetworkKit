import Foundation

/// A typed HTTP description. APIClient executes it through the shared secure pipeline.
public protocol Endpoint: Sendable {
    associatedtype Response: Sendable
    var responseStrategy: ResponseStrategy<Response> { get }
    var method: HTTPMethod { get }
    var path: EndpointPath { get }
    var query: [HTTPQueryItem] { get }
    var body: RequestBody? { get }
    var options: NetworkCallOptions { get }
}

extension Endpoint {
    public var method: HTTPMethod { .get }
    public var query: [HTTPQueryItem] { [] }
    public var body: RequestBody? { nil }
    public var options: NetworkCallOptions { .default }

    /// Constructs buffered request data, without executing or authorizing networking.
    public func request(configuration: NetworkConfiguration) throws -> URLRequest {
        try RequestBuilder.prepare(self, configuration: configuration).request
    }

    /// Appends decoded segments to the base path without changing its origin.
    /// This constructs a URL; it does not authorize network access.
    public func url(relativeTo baseURL: URL) throws -> URL {
        try RequestURLBuilder.build(baseURL: baseURL, path: path, query: query)
    }
}

/// Decoded path data, not a relative URL or pre-percent-encoded path string.
public struct EndpointPath: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    public let segments: [String]

    /// An empty array addresses the base path. Empty/dot/traversal segments fail.
    /// Ambiguous pre-encoded text is rejected instead of decoded or double encoded.
    public init(segments: [String]) throws {
        for segment in segments {
            try URLInputValidation.validateSegment(segment)
        }
        self.segments = segments
    }

    public var description: String { "EndpointPath(segmentCount: \(segments.count))" }
    public var debugDescription: String { description }
}

/// One ordered query item. Nil means a name alone; "" means name=.
public struct HTTPQueryItem: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    public let name: String
    public let value: String?

    /// Inputs are decoded text. Percent characters are literal query data.
    public init(name: String, value: String? = nil) throws {
        guard URLInputValidation.hasNoControls(name),
              value.map(URLInputValidation.hasNoControls) ?? true else {
            throw NetworkError.invalidRequest(.invalidURL)
        }
        self.name = name
        self.value = value
    }

    public var description: String { "HTTPQueryItem(hasValue: \(value != nil))" }
    public var debugDescription: String { description }
}

// Explicitly empty endpoints need no JSON model or decoder.
extension Endpoint where Response == EmptyResponse {
    public var responseStrategy: ResponseStrategy<EmptyResponse> { .empty }
}

extension Endpoint {
    /// Interprets a buffered response with this endpoint's strategy and status policy.
    public func decodeResponse(_ data: Data, response: URLResponse) throws -> NetworkResponse<Response> {
        try responseStrategy.decode(data, response: response, acceptedStatuses: options.acceptedStatuses)
    }
}
