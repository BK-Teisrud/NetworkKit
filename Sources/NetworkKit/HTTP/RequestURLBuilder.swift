import Foundation

/// Structural URL checks shared by construction and the active network security policy.
internal enum URLInputValidation {
    static func hasNoControls(_ text: String) -> Bool {
        // Preserve format scalars such as the joiner in compound emoji. C0/C1
        // controls are rejected; every other non-unreserved UTF-8 byte is escaped.
        text.unicodeScalars.allSatisfy { $0.value > 31 && !(127...159).contains($0.value) }
    }

    static func containsEscape(_ text: String) -> Bool {
        let bytes = Array(text.utf8)
        guard bytes.count >= 3 else { return false }
        func isHex(_ byte: UInt8) -> Bool {
            (48...57).contains(byte) || (65...70).contains(byte) || (97...102).contains(byte)
        }
        return (0..<(bytes.count - 2)).contains { index in
            bytes[index] == 37 && isHex(bytes[index + 1]) && isHex(bytes[index + 2])
        }
    }

    static func validateSegment(_ segment: String) throws {
        // Slash data is encoded as %2F, never inserted as a path separator.
        // Backslashes and nested escapes are rejected for conservative routing.
        guard !segment.isEmpty, hasNoControls(segment), !segment.contains("\\"),
              !containsEscape(segment),
              !segment.split(separator: "/", omittingEmptySubsequences: false)
                .contains(where: { $0 == "." || $0 == ".." }) else {
            throw NetworkError.invalidRequest(.invalidURL)
        }
    }

    /// URL.host representations differ across OS releases. encodedHost retains
    /// Foundation's IDNA ASCII form and explicit IPv6 brackets consistently.
    static func normalizedHost(_ components: URLComponents) throws -> String {
        guard var host = components.encodedHost, !host.isEmpty else {
            throw NetworkError.invalidRequest(.invalidURL)
        }
        if host.hasPrefix("[") && host.hasSuffix("]") {
            host = String(host.dropFirst().dropLast())
            guard host.contains(":") else { throw NetworkError.invalidRequest(.invalidURL) }
        }
        guard !host.isEmpty, !host.hasSuffix("."), host.utf8.allSatisfy({ byte in
            (48...57).contains(byte) || (65...90).contains(byte) || (97...122).contains(byte)
                || [45, 46, 58].contains(byte)
        }) else { throw NetworkError.invalidRequest(.invalidURL) }
        return host.lowercased()
    }

    static func components(_ url: URL, isBase: Bool) throws -> URLComponents {
        guard url.baseURL == nil,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(), ["http", "https"].contains(scheme),
              components.user == nil, components.password == nil, components.fragment == nil,
              components.port.map({ (1...65535).contains($0) }) ?? true,
              !isBase || components.percentEncodedQuery == nil else {
            throw NetworkError.invalidRequest(.invalidURL)
        }
        _ = try normalizedHost(components)
        let path = components.percentEncodedPath
        guard path.isEmpty || path.hasPrefix("/") else {
            throw NetworkError.invalidRequest(.invalidURL)
        }
        // Empty base/raw path components remain valid; endpoint segments are explicit.
        for encoded in path.split(separator: "/", omittingEmptySubsequences: true) {
            guard let decoded = String(encoded).removingPercentEncoding else {
                throw NetworkError.invalidRequest(.invalidURL)
            }
            try validateSegment(decoded)
        }
        if let query = components.percentEncodedQuery {
            guard let decoded = query.removingPercentEncoding, hasNoControls(decoded) else {
                throw NetworkError.invalidRequest(.invalidURL)
            }
        }
        return components
    }
}

internal enum RequestURLBuilder {
    /// Encode UTF-8 once, permitting only RFC 3986 unreserved bytes.
    /// Using this for each component also preserves literal +, &, =, ?, and #.
    private static func encode(_ text: String) -> String {
        let hex = Array("0123456789ABCDEF".utf8)
        var output: [UInt8] = []
        for byte in text.utf8 {
            if (48...57).contains(byte) || (65...90).contains(byte) || (97...122).contains(byte)
                || [45, 46, 95, 126].contains(byte) {
                output.append(byte)
            } else {
                output.append(contentsOf: [37, hex[Int(byte >> 4)], hex[Int(byte & 15)]])
            }
        }
        return String(decoding: output, as: UTF8.self)
    }

    static func build(baseURL: URL, path: EndpointPath, query: [HTTPQueryItem]) throws -> URL {
        var components = try URLInputValidation.components(baseURL, isBase: true)
        if !path.segments.isEmpty {
            var basePath = components.percentEncodedPath
            if !basePath.hasSuffix("/") { basePath += "/" }
            components.percentEncodedPath = basePath + path.segments.map(encode).joined(separator: "/")
        }
        if !query.isEmpty {
            components.percentEncodedQuery = query.map { item in
                encode(item.name) + (item.value.map { "=" + encode($0) } ?? "")
            }.joined(separator: "&")
        }
        guard let url = components.url else { throw NetworkError.invalidRequest(.invalidURL) }
        _ = try URLInputValidation.components(url, isBase: false)
        return url
    }
}
