/// Immutable per-call acceptance. Explicit policies replace the default 200...299.
public struct HTTPStatusPolicy: Sendable, Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    private let codes: Set<Int>

    public init(codes: Set<Int>) throws {
        guard !codes.isEmpty, codes.allSatisfy({ (100...599).contains($0) }) else {
            throw NetworkError.invalidRequest(.invalidConfiguration)
        }
        self.codes = codes
    }

    public init(range: ClosedRange<Int>) throws {
        guard range.lowerBound >= 100, range.upperBound <= 599 else {
            throw NetworkError.invalidRequest(.invalidConfiguration)
        }
        try self.init(codes: Set(range))
    }

    public static let successful = Self()
    private init() { codes = Set(200...299) }
    public func accepts(_ status: HTTPStatus) -> Bool { codes.contains(status.code) }
    public var description: String { "HTTPStatusPolicy(codeCount: \(codes.count))" }
    public var debugDescription: String { description }
}
