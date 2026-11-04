import Foundation

/// Value settings applied to a fresh Apple JSONDecoder for every response.
/// Custom decoding hooks must obey Sendable semantics and protect shared state.
public struct JSONDecodingOptions: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    public enum DateStrategy: Sendable {
        case deferredToDate, secondsSince1970, millisecondsSince1970, iso8601
    }
    public enum KeyStrategy: Sendable { case useDefaultKeys, convertFromSnakeCase }
    public enum DataStrategy: Sendable { case base64, deferredToData }
    public enum FloatStrategy: Sendable {
        case `throw`
        case convertFromString(positiveInfinity: String, negativeInfinity: String, nan: String)
    }
    public let dateStrategy: DateStrategy
    public let keyStrategy: KeyStrategy
    public let dataStrategy: DataStrategy
    public let floatStrategy: FloatStrategy

    public init(dateStrategy: DateStrategy = .deferredToDate, keyStrategy: KeyStrategy = .useDefaultKeys,
                dataStrategy: DataStrategy = .base64, floatStrategy: FloatStrategy = .throw) {
        self.dateStrategy = dateStrategy
        self.keyStrategy = keyStrategy
        self.dataStrategy = dataStrategy
        self.floatStrategy = floatStrategy
    }

    internal func decode<Value: Decodable>(_ type: Value.Type, from data: Data) throws -> Value {
        let decoder = JSONDecoder()
        switch dateStrategy {
        case .deferredToDate: decoder.dateDecodingStrategy = .deferredToDate
        case .secondsSince1970: decoder.dateDecodingStrategy = .secondsSince1970
        case .millisecondsSince1970: decoder.dateDecodingStrategy = .millisecondsSince1970
        case .iso8601: decoder.dateDecodingStrategy = .iso8601
        }
        switch keyStrategy {
        case .useDefaultKeys: decoder.keyDecodingStrategy = .useDefaultKeys
        case .convertFromSnakeCase: decoder.keyDecodingStrategy = .convertFromSnakeCase
        }
        switch dataStrategy {
        case .base64: decoder.dataDecodingStrategy = .base64
        case .deferredToData: decoder.dataDecodingStrategy = .deferredToData
        }
        switch floatStrategy {
        case .throw: decoder.nonConformingFloatDecodingStrategy = .throw
        case .convertFromString(let positive, let negative, let nan):
            decoder.nonConformingFloatDecodingStrategy = .convertFromString(
                positiveInfinity: positive, negativeInfinity: negative, nan: nan)
        }
        return try decoder.decode(type, from: data)
    }
    public var description: String { "JSONDecodingOptions" }
    public var debugDescription: String { description }
}
