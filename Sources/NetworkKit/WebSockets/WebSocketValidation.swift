#if !os(watchOS)
import Foundation

internal enum WebSocketValidation {
    static func origin(_ endpoint: URL, allowInsecureLoopback: Bool) throws -> NetworkOrigin {
        guard endpoint.baseURL == nil,
              var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(), ["ws", "wss"].contains(scheme) else {
            throw WebSocketError.invalidInput(.invalidEndpoint)
        }
        // Validate a private copy; native task still receives the original WS/WSS URL.
        components.scheme = scheme == "wss" ? "https" : "http"
        guard let mapped = components.url else { throw WebSocketError.invalidInput(.invalidEndpoint) }
        let origin: NetworkOrigin
        do { origin = try NetworkOrigin(mapped) }
        catch { throw WebSocketError.invalidInput(.invalidEndpoint) }
        guard scheme == "wss" || (allowInsecureLoopback && origin.isLoopback) else {
            throw WebSocketError.invalidInput(.insecureTransport)
        }
        return origin
    }

    static func headers(_ headers: HTTPHeaders, origin: NetworkOrigin) throws {
        let reserved: Set<String> = ["host", "connection", "upgrade", "content-length", "transfer-encoding",
            "cookie", "set-cookie", "proxy-authorization", "proxy-connection", "origin"]
        guard headers.fields.keys.allSatisfy({ !reserved.contains($0) && !$0.hasPrefix("sec-websocket-") }) else {
            throw WebSocketError.invalidInput(.reservedHeader)
        }
        if origin.scheme == "http" {
            // Pure existing public-metadata whitelist; no HTTP transport/lifetime reuse.
            do { try NetworkSecurityPolicy().validateHeaders(headers, origin: origin) }
            catch { throw WebSocketError.invalidInput(.credentialsOverWS) }
        }
    }

    static func merged(_ base: HTTPHeaders, _ supplied: HTTPHeaders, origin: NetworkOrigin) throws -> HTTPHeaders {
        try headers(supplied, origin: origin)
        var result = base.fields
        for (name, value) in supplied.fields {
            if let existing = result[name], !existing.utf8.elementsEqual(value.utf8) {
                throw WebSocketError.invalidInput(.conflictingHeaders)
            }
            result[name] = value
        }
        return try HTTPHeaders(result)
    }

    static func closeReason(_ reason: String?) throws {
        guard reason.map({ $0.utf8.count <= 123 }) ?? true else {
            throw WebSocketError.invalidInput(.invalidCloseReason)
        }
    }

    static func peerClose(code: Int, reason: Data?) throws -> WebSocketCloseInfo {
        let wireCode: UInt16?
        if code == 1005 { wireCode = nil } // Valid empty close, only on authoritative peer delegate path.
        else {
            let allowed = [1000, 1001, 1002, 1003, 1007, 1008, 1009, 1010, 1011, 1012, 1013, 1014]
            guard allowed.contains(code) || (3000...4999).contains(code), let value = UInt16(exactly: code) else {
                throw WebSocketError.protocolViolation
            }
            wireCode = value
        }
        guard wireCode != nil || (reason?.isEmpty ?? true) else { throw WebSocketError.protocolViolation }
        guard (reason?.count ?? 0) <= 123 else { throw WebSocketError.protocolViolation }
        let text: String?
        if let reason, !reason.isEmpty {
            guard let decoded = String(data: reason, encoding: .utf8) else { throw WebSocketError.protocolViolation }
            text = decoded
        } else { text = nil }
        return WebSocketCloseInfo(code: wireCode, reason: text)
    }
}
#endif
