#if !os(watchOS)
import Foundation

/// Logical budgets, not real-time or unconditional cleanup guarantees.
public struct WebSocketTimeouts: Sendable, Equatable {
    public let connect: TimeInterval
    public let send: TimeInterval
    public let close: TimeInterval

    public init(connect: TimeInterval = 10, send: TimeInterval = 10,
                close: TimeInterval = 2) throws {
        guard [connect, send, close].allSatisfy({ $0.isFinite && $0 > 0 && $0 <= 86400 }) else {
            throw WebSocketError.invalidInput(.invalidTimeout)
        }
        self.connect = connect; self.send = send; self.close = close
    }
    private init() { connect = 10; send = 10; close = 2 }
    public static let `default` = Self()
}

/// One endpoint/account binding. No mutable URL or arbitrary session/delegate.
public struct WebSocketConfiguration: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    public let endpoint: URL
    public let maximumMessageBytes: Int
    public let headers: HTTPHeaders
    public let authentication: NetworkAuthentication?
    public let subprotocols: [String]
    public let timeouts: WebSocketTimeouts
    public let allowInsecureLoopback: Bool

    public init(endpoint: URL, maximumMessageBytes: Int,
                headers: HTTPHeaders = HTTPHeaders(),
                authentication: NetworkAuthentication? = nil,
                subprotocols: [String] = [],
                timeouts: WebSocketTimeouts = .default,
                allowInsecureLoopback: Bool = false) throws {
        guard maximumMessageBytes > 0 else { throw WebSocketError.invalidInput(.invalidMessageLimit) }
        let origin = try WebSocketValidation.origin(endpoint, allowInsecureLoopback: allowInsecureLoopback)
        try WebSocketValidation.headers(headers, origin: origin)
        if origin.scheme == "http", authentication != nil {
            throw WebSocketError.invalidInput(.credentialsOverWS)
        }
        guard Set(subprotocols).count == subprotocols.count,
              subprotocols.allSatisfy(HTTPToken.isValid) else {
            throw WebSocketError.invalidInput(.invalidSubprotocol)
        }
        self.endpoint = endpoint; self.maximumMessageBytes = maximumMessageBytes
        self.headers = headers; self.authentication = authentication; self.subprotocols = subprotocols
        self.timeouts = timeouts; self.allowInsecureLoopback = allowInsecureLoopback
    }
    public var description: String { "WebSocketConfiguration(headerCount: \(headers.count))" }
    public var debugDescription: String { description }
}

public enum WebSocketMessage: Sendable, Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    case text(String)
    case binary(Data)

    internal var byteCount: Int {
        switch self { case .text(let value): value.utf8.count; case .binary(let value): value.count }
    }
    public var description: String {
        switch self {
        case .text: "WebSocketMessage.text(bytes: \(byteCount))"
        case .binary: "WebSocketMessage.binary(bytes: \(byteCount))"
        }
    }
    public var debugDescription: String { description }
}

public struct WebSocketCloseCode: Sendable, Hashable {
    public let rawValue: UInt16
    private init(_ value: UInt16) { rawValue = value }
    public static let normal = Self(1000)
    public static let goingAway = Self(1001)
    public static func application(_ code: UInt16) throws -> Self {
        guard (3000...4999).contains(code) else { throw WebSocketError.invalidInput(.invalidCloseCode) }
        return Self(code)
    }
}

/// A validated peer-frame snapshot; absent wire status is nil, never a synthetic sentinel.
public struct WebSocketCloseInfo: Sendable, Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    public let code: UInt16?
    public let reason: String?
    internal init(code: UInt16?, reason: String?) { self.code = code; self.reason = reason }
    public var description: String { "WebSocketCloseInfo" }
    public var debugDescription: String { description }
}
#endif
