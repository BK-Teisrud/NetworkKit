import Foundation

/// Value-based Apple JSONEncoder settings; no shared encoder or formatter instance.
public struct JSONEncodingOptions: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    public enum DateStrategy: Sendable {
        case deferredToDate, secondsSince1970, millisecondsSince1970, iso8601
    }
    public enum KeyStrategy: Sendable { case useDefaultKeys, convertToSnakeCase }
    public enum DataStrategy: Sendable { case base64, deferredToData }
    public enum FloatStrategy: Sendable {
        case `throw`
        case convertToString(positiveInfinity: String, negativeInfinity: String, nan: String)
    }

    public let dateStrategy: DateStrategy
    public let keyStrategy: KeyStrategy
    public let dataStrategy: DataStrategy
    public let floatStrategy: FloatStrategy
    public let outputFormatting: JSONEncoder.OutputFormatting

    public init(dateStrategy: DateStrategy = .deferredToDate, keyStrategy: KeyStrategy = .useDefaultKeys,
                dataStrategy: DataStrategy = .base64, floatStrategy: FloatStrategy = .throw,
                outputFormatting: JSONEncoder.OutputFormatting = []) {
        self.dateStrategy = dateStrategy
        self.keyStrategy = keyStrategy
        self.dataStrategy = dataStrategy
        self.floatStrategy = floatStrategy
        self.outputFormatting = outputFormatting
    }

    internal func encode<Value: Encodable>(_ value: Value) throws -> Data {
        let encoder = JSONEncoder()
        switch dateStrategy {
        case .deferredToDate: encoder.dateEncodingStrategy = .deferredToDate
        case .secondsSince1970: encoder.dateEncodingStrategy = .secondsSince1970
        case .millisecondsSince1970: encoder.dateEncodingStrategy = .millisecondsSince1970
        case .iso8601: encoder.dateEncodingStrategy = .iso8601
        }
        switch keyStrategy {
        case .useDefaultKeys: encoder.keyEncodingStrategy = .useDefaultKeys
        case .convertToSnakeCase: encoder.keyEncodingStrategy = .convertToSnakeCase
        }
        switch dataStrategy {
        case .base64: encoder.dataEncodingStrategy = .base64
        case .deferredToData: encoder.dataEncodingStrategy = .deferredToData
        }
        switch floatStrategy {
        case .throw: encoder.nonConformingFloatEncodingStrategy = .throw
        case .convertToString(let positive, let negative, let nan):
            encoder.nonConformingFloatEncodingStrategy = .convertToString(
                positiveInfinity: positive, negativeInfinity: negative, nan: nan)
        }
        encoder.outputFormatting = outputFormatting
        return try encoder.encode(value)
    }

    public var description: String { "JSONEncodingOptions" }
    public var debugDescription: String { description }
}

/// Buffered request data. Absence of a body is represented by nil on Endpoint.
public struct RequestBody: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    private let kind: String
    internal let contentType: String
    private let encodeValue: @Sendable () throws -> Data

    private init(kind: String, contentType: String, encode: @escaping @Sendable () throws -> Data) {
        self.kind = kind
        self.contentType = contentType
        self.encodeValue = encode
    }

    public static func data(_ value: Data) -> Self {
        Self(kind: "data", contentType: "application/octet-stream", encode: { value })
    }

    public static func text(_ value: String) -> Self {
        Self(kind: "text", contentType: "text/plain; charset=utf-8", encode: { Data(value.utf8) })
    }

    /// Value must obey Sendable semantics. Every preparation encodes independently.
    public static func json<Value: Encodable & Sendable>(
        _ value: Value, options: JSONEncodingOptions = JSONEncodingOptions()
    ) -> Self {
        Self(kind: "json", contentType: "application/json", encode: { try options.encode(value) })
    }

    internal func encoded() throws -> Data {
        try Task.checkCancellation()
        do {
            let data = try encodeValue()
            try Task.checkCancellation()
            return data
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            try Task.checkCancellation()
            throw NetworkError.encoding
        }
    }

    public var description: String { "RequestBody(\(kind))" }
    public var debugDescription: String { description }
}
