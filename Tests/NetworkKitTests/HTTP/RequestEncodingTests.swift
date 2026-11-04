import Foundation
import Testing
@testable import NetworkKit

private struct EncodingEndpoint: Endpoint {
    typealias Response = EmptyResponse
    let path: EndpointPath
    var method: HTTPMethod = .post
    var body: RequestBody? = nil
    var options: NetworkCallOptions = .default
}

private struct Payload: Encodable, Sendable {
    let displayName: String
    let createdAt: Date
    let bytes: Data
}

private struct FailingPayload: Encodable, Sendable {
    func encode(to encoder: any Encoder) throws {
        throw NSError(domain: "SECRET", code: 42, userInfo: [NSLocalizedDescriptionKey: "SECRET payload"])
    }
}

private struct CancelledPayload: Encodable, Sendable {
    func encode(to encoder: any Encoder) throws { throw CancellationError() }
}

@Suite struct RequestEncodingTests {
    private let configuration = NetworkConfiguration(baseURL: URL(string: "https://example.invalid/api")!)

    private func endpoint(body: RequestBody? = nil, options: NetworkCallOptions = .default) throws -> EncodingEndpoint {
        EncodingEndpoint(path: try EndpointPath(segments: ["items"]), body: body, options: options)
    }

    @Test func defaultEndpointHasNoBodyOrInventedContentType() throws {
        struct DefaultEndpoint: Endpoint {
            typealias Response = EmptyResponse
            let path: EndpointPath
        }
        let request = try DefaultEndpoint(path: EndpointPath(segments: [])).request(configuration: configuration)
        #expect(request.httpMethod == "GET")
        #expect(request.httpBody == nil)
        #expect(request.value(forHTTPHeaderField: "Content-Type") == nil)
        #expect(request.timeoutInterval == 30)
        #expect(NetworkCallOptions.default.totalTimeout == nil)
    }

    @Test func dataAndEmptyDataAreExplicitBodies() throws {
        for value in [Data(), Data([0, 255, 42])] {
            let request = try endpoint(body: .data(value)).request(configuration: configuration)
            #expect(request.httpBody == value)
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/octet-stream")
            #expect(request.value(forHTTPHeaderField: "Content-Length") == nil)
        }
    }

    @Test func textUsesExactUTF8() throws {
        for value in ["", "café e\u{301} 👨‍👩‍👦 日本語\nSECRET"] {
            let request = try endpoint(body: .text(value)).request(configuration: configuration)
            #expect(request.httpBody == Data(value.utf8))
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "text/plain; charset=utf-8")
        }
    }

    @Test func jsonDefaultsAndNull() throws {
        let payload = Payload(displayName: "SECRET", createdAt: Date(timeIntervalSince1970: 0), bytes: Data([1, 2]))
        let request = try endpoint(body: .json(payload)).request(configuration: configuration)
        let json = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        #expect(json["displayName"] as? String == "SECRET")
        #expect(json["createdAt"] as? Double == payload.createdAt.timeIntervalSinceReferenceDate)
        #expect(json["bytes"] as? String == "AQI=")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let null = try endpoint(body: .json(Optional<String>.none)).request(configuration: configuration)
        #expect(null.httpBody == Data("null".utf8))
    }

    @Test func jsonOptionsUseNativeStrategies() throws {
        let payload = Payload(displayName: "name", createdAt: Date(timeIntervalSince1970: 123), bytes: Data([1, 2]))
        let options = JSONEncodingOptions(dateStrategy: .millisecondsSince1970, keyStrategy: .convertToSnakeCase,
                                          dataStrategy: .deferredToData)
        let request = try endpoint(body: .json(payload, options: options)).request(configuration: configuration)
        let json = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        #expect(json["display_name"] as? String == "name")
        #expect(json["created_at"] as? Double == 123_000)
        #expect(json["bytes"] as? [Int] == [1, 2])
        let iso = try endpoint(body: .json(payload, options: JSONEncodingOptions(dateStrategy: .iso8601)))
            .request(configuration: configuration)
        let isoJSON = try JSONSerialization.jsonObject(with: iso.httpBody!) as! [String: Any]
        #expect(isoJSON["createdAt"] as? String == "1970-01-01T00:02:03Z")
    }

    @Test func jsonFloatAndOutputFormatting() throws {
        #expect(throws: NetworkError.encoding) {
            try endpoint(body: .json(Double.infinity)).request(configuration: configuration)
        }
        let options = JSONEncodingOptions(floatStrategy: .convertToString(positiveInfinity: "inf", negativeInfinity: "-inf", nan: "nan"))
        let request = try endpoint(body: .json([Double.infinity, -.infinity, .nan], options: options))
            .request(configuration: configuration)
        #expect(try JSONSerialization.jsonObject(with: request.httpBody!) as? [String] == ["inf", "-inf", "nan"])
        let formatted = try endpoint(body: .json(["z": "/", "a": "b"], options:
            JSONEncodingOptions(outputFormatting: [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes])))
            .request(configuration: configuration)
        let text = String(decoding: formatted.httpBody!, as: UTF8.self)
        #expect(text.contains("\n"))
        #expect(!text.contains("\\/"))
        #expect(text.range(of: "\"a\"")!.lowerBound < text.range(of: "\"z\"")!.lowerBound)
    }

    @Test func explicitHeadersAndContentTypeWinWithoutChangingBytes() throws {
        let client = NetworkConfiguration(baseURL: configuration.baseURL,
            headers: try HTTPHeaders(["X-Choice": "client", "X-Keep": "keep", "Content-Type": "client/type"]))
        let options = try NetworkCallOptions(headers: HTTPHeaders(["x-choice": "call", "CONTENT-TYPE": "custom/type"]),
                                              inactivityTimeout: 4, totalTimeout: 9)
        let prepared = try RequestBuilder.prepare(endpoint(body: .text("é"), options: options), configuration: client)
        #expect(prepared.request.value(forHTTPHeaderField: "X-Choice") == "call")
        #expect(prepared.request.value(forHTTPHeaderField: "X-Keep") == "keep")
        #expect(prepared.request.value(forHTTPHeaderField: "Content-Type") == "custom/type")
        #expect(prepared.request.httpBody == Data("é".utf8))
        #expect(prepared.request.timeoutInterval == 4)
        #expect(prepared.timeouts.total == 9)
        #expect(client.headers["x-choice"] == "client")
        let noBody = try endpoint(options: options).request(configuration: client)
        #expect(noBody.value(forHTTPHeaderField: "Content-Type") == "custom/type")
    }

    @Test func methodsArePreserved() throws {
        for method in [HTTPMethod.get, .post, .put, .patch, .delete, .head, .options, try HTTPMethod("CUSTOM"), try HTTPMethod("custom")] {
            var value = try endpoint()
            value.method = method
            #expect(try value.request(configuration: configuration).httpMethod == method.rawValue)
        }
    }

    @Test func normalizedCustomMethodIsNotSilentlyChanged() throws {
        var value = try endpoint()
        value.method = try HTTPMethod("get")
        #expect(throws: NetworkError.invalidRequest(.unsupportedRequest)) {
            try value.request(configuration: configuration)
        }
    }

    @Test(arguments: [HTTPMethod.get, .head])
    func bodylessMethodsRejectBodies(_ method: HTTPMethod) throws {
        var value = try endpoint(body: .data(Data()))
        value.method = method
        #expect(throws: NetworkError.invalidRequest(.unsupportedRequest)) { try value.request(configuration: configuration) }
        var raw = URLRequest(url: configuration.baseURL)
        raw.httpMethod = method.rawValue
        raw.httpBody = Data()
        #expect(throws: NetworkError.invalidRequest(.unsupportedRequest)) { try RequestBuilder.prepare(raw, configuration: configuration) }
    }

    @Test func encodingFailureIsSanitizedAndDoesNotPoisonNextCall() throws {
        do {
            _ = try endpoint(body: .json(FailingPayload())).request(configuration: configuration)
            Issue.record("Failing Encodable must throw")
        } catch {
            #expect(error as? NetworkError == .encoding)
            #expect(!error.localizedDescription.contains("SECRET"))
            #expect(!String(reflecting: error).contains("SECRET"))
        }
        let next = try endpoint(body: .json(["ok": true])).request(configuration: configuration)
        #expect(try JSONSerialization.jsonObject(with: next.httpBody!) as? [String: Bool] == ["ok": true])
    }

    @Test func encodingCancellationIsNotOrdinaryFailure() throws {
        #expect(throws: CancellationError.self) {
            try endpoint(body: .json(CancelledPayload())).request(configuration: configuration)
        }
    }

    @Test func concurrentEncodersHaveIndependentStrategiesAndPayloads() async throws {
        let snakeBody = RequestBody.json(
            Payload(displayName: "snake", createdAt: Date(timeIntervalSince1970: 5), bytes: Data([42])),
            options: JSONEncodingOptions(dateStrategy: .secondsSince1970, keyStrategy: .convertToSnakeCase))
        let camelBody = RequestBody.json(
            Payload(displayName: "camel", createdAt: Date(timeIntervalSince1970: 5), bytes: Data([42])),
            options: JSONEncodingOptions(dateStrategy: .millisecondsSince1970))
        let requests = try await withThrowingTaskGroup(of: (Int, URLRequest).self) { group in
            for index in 0..<100 {
                group.addTask {
                    let options = try NetworkCallOptions(headers: HTTPHeaders(["X-Index": String(index)]))
                    return (index, try endpoint(body: index.isMultiple(of: 2) ? snakeBody : camelBody,
                                               options: options).request(configuration: configuration))
                }
            }
            var result: [(Int, URLRequest)] = []
            for try await request in group { result.append(request) }
            return result
        }
        #expect(requests.count == 100)
        for (index, request) in requests {
            let json = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
            let snake = index.isMultiple(of: 2)
            #expect(json[snake ? "display_name" : "displayName"] as? String == (snake ? "snake" : "camel"))
            #expect(json[snake ? "created_at" : "createdAt"] as? Double == (snake ? 5 : 5_000))
            #expect(json[snake ? "displayName" : "display_name"] == nil)
            #expect(request.value(forHTTPHeaderField: "X-Index") == String(index))
        }
    }

    @Test func descriptionsExcludePayloadAndFormattingValues() throws {
        let body = RequestBody.json(["SECRET": "SECRET"])
        let options = JSONEncodingOptions(floatStrategy: .convertToString(positiveInfinity: "SECRET", negativeInfinity: "SECRET", nan: "SECRET"))
        let prepared = try RequestBuilder.prepare(endpoint(body: body), configuration: configuration)
        for text in [String(describing: body), String(reflecting: body), String(describing: options),
                     String(reflecting: options), String(describing: prepared), String(reflecting: prepared)] {
            #expect(!text.contains("SECRET"))
            #expect(!text.contains("example.invalid"))
        }
    }
}

@Suite struct RawRequestEncodingTests {
    private let base = URL(string: "https://example.invalid")!

    @Test func rawBodyHeadersAndCallPrecedence() throws {
        let client = NetworkConfiguration(baseURL: base, headers: try HTTPHeaders(["X-Choice": "client", "X-Keep": "keep"]))
        var raw = URLRequest(url: base, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 999)
        raw.httpMethod = "POST"
        raw.httpBody = Data([0, 42])
        raw.allHTTPHeaderFields = ["X-Choice": "raw", "X-Raw": "raw-only"]
        let options = try NetworkCallOptions(headers: HTTPHeaders(["x-choice": "call"]), totalTimeout: 8)
        let prepared = try RequestBuilder.prepare(raw, configuration: client, options: options)
        #expect(prepared.request.httpBody == raw.httpBody)
        #expect(prepared.request.value(forHTTPHeaderField: "X-Choice") == "call")
        #expect(prepared.request.value(forHTTPHeaderField: "X-Keep") == "keep")
        #expect(prepared.request.value(forHTTPHeaderField: "X-Raw") == "raw-only")
        #expect(prepared.request.value(forHTTPHeaderField: "Content-Type") == "application/octet-stream")
        #expect(prepared.request.timeoutInterval == 30)
        #expect(prepared.timeouts.total == 8)
        #expect(prepared.request.cachePolicy == .reloadIgnoringLocalCacheData)
        #expect(raw.timeoutInterval == 999)
        let inheritedRaw = try RequestBuilder.prepare(raw, configuration: client)
        #expect(inheritedRaw.request.value(forHTTPHeaderField: "X-Choice") == "raw")
    }

    @Test func rawExplicitContentTypeAndNoBody() throws {
        var raw = URLRequest(url: base)
        raw.httpMethod = "POST"
        raw.httpBody = Data("{}".utf8)
        raw.setValue("application/custom+json", forHTTPHeaderField: "Content-Type")
        let prepared = try RequestBuilder.prepare(raw, configuration: NetworkConfiguration(baseURL: base))
        #expect(prepared.request.value(forHTTPHeaderField: "Content-Type") == "application/custom+json")
        let empty = try RequestBuilder.prepare(URLRequest(url: base), configuration: NetworkConfiguration(baseURL: base))
        #expect(empty.request.httpBody == nil)
        #expect(empty.request.value(forHTTPHeaderField: "Content-Type") == nil)
    }

    @Test func rawStreamsAndMalformedMethodsFailLocally() throws {
        let client = NetworkConfiguration(baseURL: base)
        var stream = URLRequest(url: base)
        stream.httpMethod = "POST"
        stream.httpBodyStream = InputStream(data: Data([1]))
        #expect(throws: NetworkError.invalidRequest(.unsupportedRequest)) { try RequestBuilder.prepare(stream, configuration: client) }
        var invalid = URLRequest(url: base)
        invalid.httpMethod = "BAD METHOD"
        #expect(throws: NetworkError.invalidRequest(.invalidMethod)) { try RequestBuilder.prepare(invalid, configuration: client) }
    }

    @Test(arguments: ["Host", "CONTENT-LENGTH", "Transfer-Encoding"])
    func managedHeadersAreRejected(_ name: String) throws {
        let headers = try HTTPHeaders([name: "SECRET"])
        let client = NetworkConfiguration(baseURL: base)
        let endpoint = EncodingEndpoint(path: try EndpointPath(segments: []), options: try NetworkCallOptions(headers: headers))
        #expect(throws: NetworkError.invalidRequest(.unsupportedRequest)) { try endpoint.request(configuration: client) }
        var raw = URLRequest(url: base)
        raw.allHTTPHeaderFields = [name: "SECRET"]
        #expect(throws: NetworkError.invalidRequest(.unsupportedRequest)) { try RequestBuilder.prepare(raw, configuration: client) }
        #expect(throws: NetworkError.invalidRequest(.unsupportedRequest)) {
            try RequestBuilder.prepare(URLRequest(url: base), configuration: NetworkConfiguration(baseURL: base, headers: headers))
        }
    }

    @Test func rawHeadersUseExistingValidation() throws {
        var raw = URLRequest(url: base)
        raw.allHTTPHeaderFields = ["X-Test": "SECRET\u{0}"]
        #expect(throws: NetworkError.invalidRequest(.invalidHeaderValue)) {
            try RequestBuilder.prepare(raw, configuration: NetworkConfiguration(baseURL: base))
        }
        #expect(throws: NetworkError.invalidRequest(.conflictingHeaders)) {
            try HTTPHeaders(["X-Test": "one", "x-test": "two"])
        }
        #expect(throws: NetworkError.invalidRequest(.invalidHeaderValue)) {
            try NetworkCallOptions(headers: HTTPHeaders(["X-Test": "SECRET\r\nInjected: yes"]))
        }
        raw.allHTTPHeaderFields = ["Bad Name": "value"]
        #expect(throws: NetworkError.invalidRequest(.invalidHeaderName)) {
            try RequestBuilder.prepare(raw, configuration: NetworkConfiguration(baseURL: base))
        }
    }

    @Test func foundationDiscardedCRLFIsNotReintroduced() throws {
        var raw = URLRequest(url: base)
        raw.allHTTPHeaderFields = ["X-Test": "SECRET\r\nInjected: yes"]
        let client = NetworkConfiguration(baseURL: base)
        if (raw.allHTTPHeaderFields ?? [:]).isEmpty {
            let prepared = try RequestBuilder.prepare(raw, configuration: client)
            #expect(prepared.request.value(forHTTPHeaderField: "X-Test") == nil)
        } else {
            #expect(throws: NetworkError.invalidRequest(.invalidHeaderValue)) {
                try RequestBuilder.prepare(raw, configuration: client)
            }
        }
    }
}
