import Foundation

/// Call-specific file-download settings. No replay or partial-response policy is exposed.
public struct DownloadOptions: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    public let headers: HTTPHeaders
    public let inactivityTimeout: TimeInterval?
    public let totalTimeout: TimeInterval?
    public let authentication: AuthenticationPolicy

    public init(headers: HTTPHeaders = HTTPHeaders(), inactivityTimeout: TimeInterval? = nil,
                totalTimeout: TimeInterval? = nil, authentication: AuthenticationPolicy = .automatic) throws {
        for timeout in [inactivityTimeout, totalTimeout].compactMap({ $0 }) {
            guard timeout.isFinite, timeout > 0 else { throw NetworkError.invalidRequest(.invalidConfiguration) }
        }
        self.headers = headers
        self.inactivityTimeout = inactivityTimeout
        self.totalTimeout = totalTimeout
        self.authentication = authentication
    }
    public static let `default` = Self()
    private init() { headers = HTTPHeaders(); inactivityTimeout = nil; totalTimeout = nil; authentication = .automatic }
    public var description: String { "DownloadOptions(headerCount: \(headers.count))" }
    public var debugDescription: String { description }
}

/// A complete temporary file. On successful return the app owns moving or removing it.
/// Client shutdown never removes handed-off files. Descriptions omit the file URL.
public struct DownloadedFile: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    public let url: URL
    public let byteCount: Int64
    internal init(url: URL, byteCount: Int64) { self.url = url; self.byteCount = byteCount }
    public var description: String { "DownloadedFile" }
    public var debugDescription: String { description }
}

/// File failures contain bounded categories, never paths or underlying system errors.
/// Request/HTTP/transport/timeouts remain NetworkError; cancellation remains CancellationError.
public enum DownloadError: Error, Sendable, Equatable, LocalizedError, CustomStringConvertible, CustomDebugStringConvertible {
    public enum FileOperation: String, Sendable { case preserve, inspect, remove }
    public enum PrimaryFailure: String, Sendable {
        case invalidRequest, transport, httpStatus, invalidResponse, fileSystem, sizeLimitExceeded, other
    }
    case sizeLimitExceeded
    case fileSystem(FileOperation)
    case cleanupFailed(primary: PrimaryFailure)

    public var description: String {
        switch self {
        case .sizeLimitExceeded: "NetworkKit download size limit exceeded."
        case .fileSystem(let operation): "NetworkKit download file operation failed (\(operation.rawValue))."
        case .cleanupFailed(let primary): "NetworkKit download cleanup failed (\(primary.rawValue))."
        }
    }
    public var debugDescription: String { description }
    public var errorDescription: String? { description }

    internal static func primary(_ error: any Error) -> PrimaryFailure {
        if let error = error as? DownloadError {
            switch error {
            case .sizeLimitExceeded: return .sizeLimitExceeded
            case .fileSystem: return .fileSystem
            case .cleanupFailed(let primary): return primary
            }
        }
        if let error = error as? NetworkError {
            switch error {
            case .invalidRequest: return .invalidRequest
            case .transport: return .transport
            case .httpStatus: return .httpStatus
            case .invalidResponse: return .invalidResponse
            default: return .other
            }
        }
        return .other
    }
}
