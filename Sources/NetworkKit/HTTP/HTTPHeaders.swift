/// Immutable header fields with ASCII case-insensitive names and opaque values.
///
/// Values are accessible explicitly through lookup or `fields`. Default descriptions
/// reveal only the field count. This is not a raw wire-header representation.
public struct HTTPHeaders: Sendable, Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    /// Field names are stored in lowercase. The dictionary has no wire ordering.
    public let fields: [String: String]

    public init() {
        fields = [:]
    }

    /// Rejects malformed names, unsafe control characters, and conflicting
    /// case-insensitive duplicates. Identical duplicate values are collapsed.
    /// Values are neither split, combined, trimmed, nor otherwise rewritten.
    public init(_ fields: [String: String]) throws {
        var normalized: [String: String] = [:]
        for (name, value) in fields.sorted(by: { $0.key < $1.key }) {
            guard HTTPToken.isValid(name) else {
                throw NetworkError.invalidRequest(.invalidHeaderName)
            }
            guard value.utf8.allSatisfy({ $0 == 9 || ($0 >= 32 && $0 != 127) }) else {
                throw NetworkError.invalidRequest(.invalidHeaderValue)
            }
            let key = name.lowercased()
            if let existing = normalized[key], !existing.utf8.elementsEqual(value.utf8) {
                throw NetworkError.invalidRequest(.conflictingHeaders)
            }
            normalized[key] = value
        }
        self.fields = normalized
    }

    /// Invalid lookup names return nil; Unicode lookalikes cannot alias ASCII names.
    public subscript(_ name: String) -> String? {
        guard HTTPToken.isValid(name) else { return nil }
        return fields[name.lowercased()]
    }

    /// Opaque field values compare by UTF-8 bytes, without Unicode normalization.
    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs.count == rhs.count else { return false }
        return lhs.fields.allSatisfy { name, value in
            guard let other = rhs.fields[name] else { return false }
            return value.utf8.elementsEqual(other.utf8)
        }
    }

    public var count: Int { fields.count }
    public var description: String { "HTTPHeaders(count: \(count))" }
    public var debugDescription: String { description }
}
