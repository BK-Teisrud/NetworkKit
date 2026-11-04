import Foundation

/// One shared metadata boundary for standalone decoding and live HTTP attempts.
/// Foundation has already normalized wire fields; preserve all exposed retry
/// values before HTTPHeaders can collapse case-insensitive duplicates.
internal struct ResponseMetadata {
    let status: HTTPStatus
    let headers: HTTPHeaders
    let retryAfterFields: [String]

    init(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse(.nonHTTPResponse)
        }
        status = try HTTPStatus(http.statusCode)
        var fields: [String: String] = [:]
        var retryAfter: [String] = []
        for (key, value) in http.allHeaderFields {
            guard let name = key as? String, let text = value as? String,
                  fields[name] == nil else { throw NetworkError.invalidResponse(.invalidHeaders) }
            fields[name] = text
            if name.lowercased() == "retry-after" { retryAfter.append(text) }
        }
        do { headers = try HTTPHeaders(fields) }
        catch { throw NetworkError.invalidResponse(.invalidHeaders) }
        retryAfterFields = retryAfter
    }
}
