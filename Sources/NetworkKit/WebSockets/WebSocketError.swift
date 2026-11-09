#if !os(watchOS)
import Foundation

/// Safe WebSocket failures; cancellation remains CancellationError.
public enum WebSocketError: Error, Sendable, Equatable, LocalizedError,
    CustomStringConvertible, CustomDebugStringConvertible {
    case invalidInput(InvalidInputReason)
    case authenticationFailed
    case handshakeRejected
    case subprotocolMismatch
    case transport(NetworkError.TransportFailure)
    case timeout(TimeoutPhase)
    case operationConflict(Operation)
    case messageTooLarge
    case protocolViolation
    case closed
    case peerClosed(code: UInt16?)

    public enum TimeoutPhase: String, Sendable { case connect, send }
    public enum Operation: String, Sendable { case send, receive }
    public enum InvalidInputReason: String, Sendable {
        case invalidEndpoint, insecureTransport, credentialsOverWS
        case invalidMessageLimit, invalidTimeout
        case reservedHeader, conflictingHeaders, invalidSubprotocol
        case invalidCloseCode, invalidCloseReason
    }

    public var description: String {
        switch self {
        case .invalidInput(let reason): "WebSocketError.invalidInput(\(reason.rawValue))"
        case .authenticationFailed: "WebSocketError.authenticationFailed"
        case .handshakeRejected: "WebSocketError.handshakeRejected"
        case .subprotocolMismatch: "WebSocketError.subprotocolMismatch"
        case .transport: "WebSocketError.transport"
        case .timeout(let phase): "WebSocketError.timeout(\(phase.rawValue))"
        case .operationConflict(let operation): "WebSocketError.operationConflict(\(operation.rawValue))"
        case .messageTooLarge: "WebSocketError.messageTooLarge"
        case .protocolViolation: "WebSocketError.protocolViolation"
        case .closed: "WebSocketError.closed"
        case .peerClosed: "WebSocketError.peerClosed"
        }
    }
    public var debugDescription: String { description }
    public var errorDescription: String? { description }
}
#endif
