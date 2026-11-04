/// An HTTP status code in 100...599, including unregistered codes in that range.
public struct HTTPStatus: Sendable, Hashable {
    public let code: Int

    public init(_ code: Int) throws {
        guard (100...599).contains(code) else {
            throw NetworkError.invalidResponse(.invalidStatusCode)
        }
        self.code = code
    }

    /// The default success classification, not a per-call acceptance policy.
    public var isSuccessful: Bool { (200...299).contains(code) }
}
