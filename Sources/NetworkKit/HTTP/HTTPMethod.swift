/// A case-sensitive HTTP method token. Custom methods retain their exact spelling.
public struct HTTPMethod: Sendable, Hashable, CustomStringConvertible, CustomDebugStringConvertible {
    public let rawValue: String

    /// Rejects empty, non-ASCII, whitespace-containing, or malformed tokens.
    public init(_ rawValue: String) throws {
        guard HTTPToken.isValid(rawValue) else {
            throw NetworkError.invalidRequest(.invalidMethod)
        }
        self.rawValue = rawValue
    }

    private init(standard: String) {
        rawValue = standard
    }

    public static let get = Self(standard: "GET")
    public static let post = Self(standard: "POST")
    public static let put = Self(standard: "PUT")
    public static let patch = Self(standard: "PATCH")
    public static let delete = Self(standard: "DELETE")
    public static let head = Self(standard: "HEAD")
    public static let options = Self(standard: "OPTIONS")

    /// Custom method strings are not included in default diagnostics.
    public var description: String {
        switch self {
        case .get, .post, .put, .patch, .delete, .head, .options:
            "HTTPMethod(\(rawValue))"
        default:
            "HTTPMethod(custom)"
        }
    }

    public var debugDescription: String { description }
}
