import Foundation

internal struct PreparedRequest: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    let request: URLRequest
    let timeouts: NetworkTimeouts
    let acceptedStatuses: HTTPStatusPolicy
    let retry: RetryPolicy
    var description: String { "PreparedRequest" }
    var debugDescription: String { description }
}

/// Builds buffered values and applies shared URL/header security policy.
/// APIClient connects both preparation paths to the same secured transport and response path.
internal enum RequestBuilder {
    static func validateHeaders(_ headers: HTTPHeaders) throws {
        // Let URLSession derive origin/framing. Do not accept misleading manual values.
        for name in ["host", "content-length", "transfer-encoding"] where headers[name] != nil {
            throw NetworkError.invalidRequest(.unsupportedRequest)
        }
    }

    private static func validateBody(method: HTTPMethod, hasBody: Bool) throws {
        // Foreground URLSession data requests do not support GET/HEAD bodies here.
        if hasBody && (method == .get || method == .head) {
            throw NetworkError.invalidRequest(.unsupportedRequest)
        }
    }

    static func prepare<E: Endpoint>(_ endpoint: E, configuration: NetworkConfiguration,
                                     options: NetworkCallOptions? = nil) throws -> PreparedRequest {
        try Task.checkCancellation()
        let options = options ?? endpoint.options
        let snapshot = try ConfigurationSnapshot(configuration: configuration, options: options)
        try validateHeaders(snapshot.headers)
        let method = endpoint.method
        let body = endpoint.body
        try RetryDecision.validate(options.retry, method: method, hasBody: body != nil, hasBodyStream: false)
        try validateBody(method: method, hasBody: body != nil)
        let url = try endpoint.url(relativeTo: snapshot.baseURL)
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        guard request.httpMethod == method.rawValue else {
            // Foundation canonicalizes some familiar method spellings. Do not
            // silently change a case-sensitive custom HTTPMethod into another.
            throw NetworkError.invalidRequest(.unsupportedRequest)
        }
        var headers = snapshot.headers.fields
        if let body {
            request.httpBody = try body.encoded()
            if headers["content-type"] == nil { headers["content-type"] = body.contentType }
        }
        request.allHTTPHeaderFields = headers
        request.timeoutInterval = snapshot.timeouts.inactivity
        _ = try configuration.security.validateRequest(request, baseURL: configuration.baseURL)
        try Task.checkCancellation()
        return PreparedRequest(request: request, timeouts: snapshot.timeouts, acceptedStatuses: snapshot.acceptedStatuses, retry: options.retry)
    }

    static func prepare(_ input: URLRequest, configuration: NetworkConfiguration,
                        options: NetworkCallOptions = .default) throws -> PreparedRequest {
        try Task.checkCancellation()
        _ = try URLInputValidation.components(configuration.baseURL, isBase: true)
        let origin = try configuration.security.validateRequest(input, baseURL: configuration.baseURL, allowAdditionalOrigins: true)
        let sameOrigin = origin == (try NetworkOrigin(configuration.baseURL))
        let method = try HTTPMethod(input.httpMethod ?? "GET")
        try RetryDecision.validate(options.retry, method: method, hasBody: input.httpBody != nil,
                                   hasBodyStream: input.httpBodyStream != nil)
        guard input.httpBodyStream == nil else { throw NetworkError.invalidRequest(.unsupportedRequest) }
        try validateBody(method: method, hasBody: input.httpBody != nil)
        let rawHeaders = try HTTPHeaders(input.allHTTPHeaderFields ?? [:])
        try validateHeaders(configuration.headers)
        try validateHeaders(rawHeaders)
        try validateHeaders(options.headers)
        // Client defaults < explicit raw fields < explicit call options.
        let headers = try HTTPHeaders(rawHeaders.fields.merging(options.headers.fields) { _, call in call })
        let mergedOptions = try NetworkCallOptions(headers: headers,
            inactivityTimeout: options.inactivityTimeout, totalTimeout: options.totalTimeout, acceptedStatuses: options.acceptedStatuses,
            authentication: options.authentication, retry: options.retry)
        let rawConfiguration = NetworkConfiguration(baseURL: configuration.baseURL,
            headers: sameOrigin ? configuration.headers : HTTPHeaders(), timeouts: configuration.timeouts, security: configuration.security)
        let snapshot = try ConfigurationSnapshot(configuration: rawConfiguration, options: mergedOptions)
        var request = input
        var fields = snapshot.headers.fields
        if request.httpBody != nil && fields["content-type"] == nil {
            fields["content-type"] = "application/octet-stream"
        }
        request.allHTTPHeaderFields = fields
        request.timeoutInterval = snapshot.timeouts.inactivity
        _ = try configuration.security.validateRequest(request, baseURL: configuration.baseURL, allowAdditionalOrigins: true)
        try Task.checkCancellation()
        return PreparedRequest(request: request, timeouts: snapshot.timeouts, acceptedStatuses: snapshot.acceptedStatuses, retry: options.retry)
    }
}
