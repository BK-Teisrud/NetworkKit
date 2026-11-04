import Foundation

/// Buffered response interpretation, independent of networking. No custom decoder plugin.
public struct ResponseStrategy<Value: Sendable>: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    private let kind: String
    private let validate: @Sendable (HTTPHeaders) throws -> Void
    private let interpret: @Sendable (Data, HTTPHeaders) throws -> Value

    private init(kind: String, validate: @escaping @Sendable (HTTPHeaders) throws -> Void = { _ in },
                 interpret: @escaping @Sendable (Data, HTTPHeaders) throws -> Value) {
        self.kind = kind
        self.validate = validate
        self.interpret = interpret
    }

    /// Confirms HTTP metadata and accepted status before interpreting the payload.
    /// Raw and typed callers share this boundary; it does not execute a request.
    public func decode(_ data: Data, response: URLResponse,
                       acceptedStatuses: HTTPStatusPolicy = .successful) throws -> NetworkResponse<Value> {
        try Task.checkCancellation()
        return try decode(data, metadata: ResponseMetadata(response), acceptedStatuses: acceptedStatuses)
    }

    internal func decode(_ data: Data, metadata: ResponseMetadata,
                         acceptedStatuses: HTTPStatusPolicy) throws -> NetworkResponse<Value> {
        try Task.checkCancellation()
        let status = metadata.status, headers = metadata.headers
        guard acceptedStatuses.accepts(status) else { throw NetworkError.httpStatus(status, headers: headers) }
        try validate(headers)
        let value: Value
        do {
            value = try interpret(data, headers)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            try Task.checkCancellation()
            throw NetworkError.decoding
        }
        try Task.checkCancellation()
        return NetworkResponse(value: value, status: status, headers: headers)
    }

    public var description: String { "ResponseStrategy(\(kind))" }
    public var debugDescription: String { description }
}

extension ResponseStrategy where Value: Decodable {
    public static func json(_ type: Value.Type = Value.self,
                            options: JSONDecodingOptions = JSONDecodingOptions()) -> Self {
        Self(kind: "json", validate: { headers in
            if let contentType = headers["content-type"] {
                guard let media = ResponseMediaType(contentType), (media.type == "application" && media.subtype == "json")
                        || (media.subtype.hasSuffix("+json") && media.subtype.count > 5) else {
                    throw NetworkError.invalidResponse(.unexpectedContentType)
                }
            }
        }) { data, _ in
            try options.decode(type, from: data)
        }
    }
}

extension ResponseStrategy where Value == Data {
    public static var data: Self { Self(kind: "data") { data, _ in data } }
}

extension ResponseStrategy where Value == String {
    /// Missing charset means UTF-8. Other encodings are deliberately unsupported.
    public static var text: Self {
        Self(kind: "text") { data, headers in
            if let contentType = headers["content-type"] {
                guard let media = ResponseMediaType(contentType),
                      media.parameters["charset"].map({ $0.lowercased() == "utf-8" }) ?? true else {
                    throw NetworkError.decoding
                }
            }
            guard let text = String(data: data, encoding: .utf8) else { throw NetworkError.decoding }
            return text
        }
    }
}

extension ResponseStrategy where Value == EmptyResponse {
    /// Ignores payload and Content-Type intentionally, while preserving status/headers.
    public static var empty: Self { Self(kind: "empty") { _, _ in EmptyResponse() } }
}

/// Strict token/quoted-string parsing prevents ambiguous charset or media declarations.
internal struct ResponseMediaType {
    let type: String
    let subtype: String
    let parameters: [String: String]

    init?(_ input: String) {
        var remainder = input[...]
        func whitespace() {
            while let c = remainder.first, c == " " || c == "\t" { remainder.removeFirst() }
        }
        func token() -> String? {
            let prefix = remainder.prefix { HTTPToken.isValid(String($0)) }
            guard !prefix.isEmpty else { return nil }
            remainder.removeFirst(prefix.count)
            return String(prefix)
        }
        whitespace()
        guard let type = token(), remainder.first == "/" else { return nil }
        remainder.removeFirst()
        guard let subtype = token() else { return nil }
        var parameters: [String: String] = [:]
        whitespace()
        while !remainder.isEmpty {
            guard remainder.removeFirst() == ";" else { return nil }
            whitespace()
            guard let name = token()?.lowercased(), parameters[name] == nil else { return nil }
            whitespace()
            guard remainder.first == "=" else { return nil }
            remainder.removeFirst()
            whitespace()
            let value: String
            if remainder.first == "\"" {
                remainder.removeFirst()
                var result = ""
                var closed = false
                while let character = remainder.first {
                    remainder.removeFirst()
                    if character == "\"" { closed = true; break }
                    if character == "\\" {
                        guard let escaped = remainder.first else { return nil }
                        remainder.removeFirst()
                        guard escaped.unicodeScalars.allSatisfy({ $0.value == 9 || ($0.value >= 32 && $0.value != 127) }) else { return nil }
                        result.append(escaped)
                    } else {
                        guard character.unicodeScalars.allSatisfy({ $0.value == 9 || ($0.value >= 32 && $0.value != 127) }) else { return nil }
                        result.append(character)
                    }
                }
                guard closed else { return nil }
                value = result
            } else {
                guard let parsed = token() else { return nil }
                value = parsed
            }
            parameters[name] = value
            whitespace()
        }
        self.type = type.lowercased()
        self.subtype = subtype.lowercased()
        self.parameters = parameters
    }
}
