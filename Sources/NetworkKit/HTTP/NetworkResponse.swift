/// A decoded value and its HTTP metadata. Values crossing tasks must be Sendable.
///
/// Access the payload and headers explicitly. Default descriptions omit them,
/// including when the payload has a custom description containing secrets.
public struct NetworkResponse<Value: Sendable>: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    public let value: Value
    public let status: HTTPStatus
    public let headers: HTTPHeaders

    public init(value: Value, status: HTTPStatus, headers: HTTPHeaders = HTTPHeaders()) {
        self.value = value
        self.status = status
        self.headers = headers
    }

    public var description: String {
        "NetworkResponse(status: \(status.code), headerCount: \(headers.count))"
    }

    public var debugDescription: String { description }
}

extension NetworkResponse: Equatable where Value: Equatable {}

/// Explicitly selects the absence of a response model; it does not decode JSON.
/// ResponseStrategy.empty deliberately skips payload decoding.
public struct EmptyResponse: Sendable, Hashable {
    public init() {}
}
