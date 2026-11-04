import Foundation
import Testing
@testable import NetworkKit

private struct ResponseModel: Codable, Sendable, Equatable { let displayName: String }
private struct ResponseEndpoint: Endpoint {
    let path: EndpointPath
    let responseStrategy: ResponseStrategy<ResponseModel> = .json()
    var options: NetworkCallOptions = .default
}
private struct ThrowingModel: Decodable, Sendable {
    init(from decoder: any Decoder) throws {
        throw NSError(domain: "SECRET", code: 1, userInfo: [NSLocalizedDescriptionKey: "SECRET body"])
    }
}
private struct MisleadingErrorModel: Decodable, Sendable {
    init(from decoder: any Decoder) throws { throw NetworkError.invalidResponse(.unexpectedContentType) }
}
private struct CancellingModel: Decodable, Sendable {
    init(from decoder: any Decoder) throws { throw CancellationError() }
}
private struct CounterModel: Decodable, Sendable {
    init(from decoder: any Decoder) throws { Issue.record("Decoder must not run before status/content validation") }
}

@Suite struct ResponseDecodingTests {
    private func http(_ status: Int = 200, _ fields: [String: String] = [:]) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://example.invalid/SECRET?token=SECRET")!,
                        statusCode: status, httpVersion: "HTTP/1.1", headerFields: fields)!
    }
    private let json = Data(#"{"displayName":"SECRET"}"#.utf8)

    @Test func jsonAndMetadata() throws {
        let response = try ResponseStrategy<ResponseModel>.json().decode(json,
            response: http(201, ["Content-Type": "application/json", "X-Request-ID": "opaque", "Set-Cookie": "SECRET"]))
        #expect(response.value == ResponseModel(displayName: "SECRET"))
        #expect(response.status.code == 201)
        #expect(response.headers["x-request-id"] == "opaque")
        #expect(response.headers["SET-COOKIE"] == "SECRET")
        #expect(!String(reflecting: response).contains("SECRET"))
    }

    @Test(arguments: ["application/json", "APPLICATION/JSON ; charset=\"utf-8\"", "application/problem+json",
                      "model/example+json", "application/json; profile=\"https://example.invalid/a;b\""])
    func acceptedJSONMediaTypes(_ contentType: String) throws {
        #expect(try ResponseStrategy<ResponseModel>.json().decode(json, response: http(200, ["Content-Type": contentType])).value.displayName == "SECRET")
    }

    @Test func missingContentTypeIsAllowed() throws {
        #expect(try ResponseStrategy<ResponseModel>.json().decode(json, response: http()).value.displayName == "SECRET")
    }

    @Test(arguments: ["text/json", "text/plain", "application/+json", "application/jsonp", "application/json, text/plain",
                      "application/json;", "application/json; charset=", "application/json; x=\"unterminated",
                      "application/json; charset=utf-8; CHARSET=ascii", "application/json garbage"])
    func rejectsIncorrectOrAmbiguousJSONMediaType(_ contentType: String) throws {
        #expect(throws: NetworkError.invalidResponse(.unexpectedContentType)) {
            try ResponseStrategy<CounterModel>.json().decode(Data(), response: http(200, ["Content-Type": contentType]))
        }
    }

    @Test func statusWinsOverCodingAndContentType() throws {
        do {
            _ = try ResponseStrategy<CounterModel>.json().decode(Data("SECRET".utf8),
                response: http(401, ["Content-Type": "text/plain", "WWW-Authenticate": "SECRET"]))
            Issue.record("Expected rejected status")
        } catch let error as NetworkError {
            guard case .httpStatus(let status, let headers) = error else { Issue.record("Wrong category"); return }
            #expect(status.code == 401)
            #expect(headers["www-authenticate"] == "SECRET")
            #expect(!error.description.contains("SECRET"))
            #expect(!error.localizedDescription.contains("SECRET"))
            #expect(!String(reflecting: error).contains("SECRET"))
        }
    }

    @Test(arguments: [Data(), Data("{".utf8), Data(#"{"wrong":1}"#.utf8), Data([0xff])])
    func malformedOrEmptyJSONFails(_ bytes: Data) throws {
        #expect(throws: NetworkError.decoding) {
            try ResponseStrategy<ResponseModel>.json().decode(bytes, response: http())
        }
    }

    @Test func explicitEmpty204AndHEADSemantics() throws {
        let empty = try ResponseStrategy<EmptyResponse>.empty.decode(Data(), response: http(204))
        #expect(empty.value == EmptyResponse())
        #expect(empty.status.code == 204)
        #expect(try ResponseStrategy<EmptyResponse>.empty.decode(Data("ignored".utf8),
            response: http(200, ["Content-Type": "nonsense"])).value == EmptyResponse())
        #expect(throws: NetworkError.decoding) {
            try ResponseStrategy<ResponseModel>.json().decode(Data(), response: http(204))
        }
    }

    @Test func dataIsUnchangedAndDoesNotImposeContentType() throws {
        for data in [Data(), Data([0, 255, 195, 40])] {
            #expect(try ResponseStrategy<Data>.data.decode(data, response: http(200, ["Content-Type": "not a media type"])).value == data)
        }
    }

    @Test(arguments: ["text/plain", "text/plain; charset=UTF-8", "text/plain; CHARSET=\"utf-8\"", "application/custom; note=\"a; b\"; charset=utf-8"])
    func textUsesStrictUTF8(_ contentType: String) throws {
        let value = "café e\u{301} 👨‍👩‍👦 日本語"
        #expect(try ResponseStrategy<String>.text.decode(Data(value.utf8), response: http(200, ["Content-Type": contentType])).value == value)
        #expect(try ResponseStrategy<String>.text.decode(Data(), response: http(200, ["Content-Type": contentType])).value == "")
    }

    @Test func textWithoutContentTypeAndInvalidBytes() throws {
        #expect(try ResponseStrategy<String>.text.decode(Data("hello".utf8), response: http()).value == "hello")
        for bytes in [Data([0xff]), Data([0xc3, 0x28]), Data([0xe2, 0x82])] {
            #expect(throws: NetworkError.decoding) { try ResponseStrategy<String>.text.decode(bytes, response: http()) }
        }
    }

    @Test(arguments: ["text/plain; charset=ascii", "text/plain; charset=iso-8859-1", "text/plain; charset=\"\"",
                      "text/plain; charset=utf-8; charset=utf-8", "text/plain; charset=utf-8, ascii", "broken"])
    func unsupportedOrInvalidTextDeclarationFails(_ contentType: String) throws {
        #expect(throws: NetworkError.decoding) {
            try ResponseStrategy<String>.text.decode(Data("ASCII".utf8), response: http(200, ["Content-Type": contentType]))
        }
    }

    @Test func rejectsNonHTTPAndInvalidStatus() throws {
        let nonHTTP = URLResponse(url: URL(string: "https://example.invalid")!, mimeType: nil,
                                  expectedContentLength: 0, textEncodingName: nil)
        #expect(throws: NetworkError.invalidResponse(.nonHTTPResponse)) {
            try ResponseStrategy<Data>.data.decode(Data(), response: nonHTTP)
        }
        #expect(throws: NetworkError.invalidResponse(.invalidStatusCode)) {
            try ResponseStrategy<Data>.data.decode(Data(), response: http(999))
        }
    }

    @Test func customDecoderFailuresAreSanitized() throws {
        #expect(throws: NetworkError.decoding) {
            try ResponseStrategy<ThrowingModel>.json().decode(Data("{}".utf8), response: http())
        }
        #expect(throws: NetworkError.decoding) {
            try ResponseStrategy<MisleadingErrorModel>.json().decode(Data("{}".utf8), response: http())
        }
        #expect(throws: CancellationError.self) {
            try ResponseStrategy<CancellingModel>.json().decode(Data("{}".utf8), response: http())
        }
    }

    @Test func appleDecoderOptionsAndDefaultValues() throws {
        struct Model: Decodable, Sendable { let displayName: String; let createdAt: Date; let bytes: Data }
        let options = JSONDecodingOptions(dateStrategy: .millisecondsSince1970, keyStrategy: .convertFromSnakeCase, dataStrategy: .deferredToData)
        let value = try ResponseStrategy<Model>.json(options: options).decode(
            Data(#"{"display_name":"ok","created_at":123000,"bytes":[1,2]}"#.utf8), response: http()).value
        #expect(value.displayName == "ok")
        #expect(value.createdAt == Date(timeIntervalSince1970: 123))
        #expect(value.bytes == Data([1,2]))
        let normal = try ResponseStrategy<Model>.json().decode(Data(#"{"displayName":"ok","createdAt":0,"bytes":"AQI="}"#.utf8), response: http()).value
        #expect(normal.createdAt == Date(timeIntervalSinceReferenceDate: 0))
        #expect(normal.bytes == Data([1,2]))
        #expect(try ResponseStrategy<Date>.json(options: JSONDecodingOptions(dateStrategy: .secondsSince1970)).decode(Data("123".utf8), response: http()).value == Date(timeIntervalSince1970: 123))
        #expect(try ResponseStrategy<Date>.json(options: JSONDecodingOptions(dateStrategy: .iso8601)).decode(Data(#""1970-01-01T00:00:00Z""#.utf8), response: http()).value == Date(timeIntervalSince1970: 0))
        let floats = JSONDecodingOptions(floatStrategy: .convertFromString(positiveInfinity: "inf", negativeInfinity: "-inf", nan: "nan"))
        let numbers = try ResponseStrategy<[Double]>.json(options: floats).decode(Data(#"["inf","-inf","nan"]"#.utf8), response: http()).value
        #expect(numbers[0] == .infinity && numbers[1] == -.infinity && numbers[2].isNaN)
        #expect(throws: NetworkError.decoding) { try ResponseStrategy<Double>.json().decode(Data(#""inf""#.utf8), response: http()) }
        #expect(try ResponseStrategy<String?>.json().decode(Data("null".utf8), response: http()).value == nil)
    }

    @Test func typedAndRawStrategiesShareStatusRules() throws {
        let policy = try HTTPStatusPolicy(codes: [404])
        let endpoint = ResponseEndpoint(path: try EndpointPath(segments: []), options: try NetworkCallOptions(acceptedStatuses: policy))
        let typed = try endpoint.decodeResponse(json, response: http(404))
        let raw = try ResponseStrategy<ResponseModel>.json().decode(json, response: http(404), acceptedStatuses: policy)
        #expect(typed == raw)
        #expect(throws: NetworkError.httpStatus(try HTTPStatus(200), headers: HTTPHeaders())) {
            try endpoint.decodeResponse(json, response: http())
        }
        #expect(throws: NetworkError.decoding) { try endpoint.decodeResponse(Data(), response: http(404)) }
        let config = NetworkConfiguration(baseURL: URL(string: "https://example.invalid")!)
        let prepared = try RequestBuilder.prepare(endpoint, configuration: config)
        let request = URLRequest(url: config.baseURL)
        let rawPrepared = try RequestBuilder.prepare(request, configuration: config, options: endpoint.options)
        #expect(prepared.acceptedStatuses == policy)
        #expect(rawPrepared.acceptedStatuses == policy)
        #expect(try ConfigurationSnapshot(configuration: config, options: endpoint.options).acceptedStatuses == policy)
    }

    @Test func parallelDecodersDoNotShareStrategyOrPayload() async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<40 {
                group.addTask { () async throws -> Void in
                    let snake = index.isMultiple(of: 2)
                    let strategy = ResponseStrategy<ResponseModel>.json(options: JSONDecodingOptions(keyStrategy: snake ? .convertFromSnakeCase : .useDefaultKeys))
                    let key = snake ? "display_name" : "displayName"
                    let bytes = Data("{\"\(key)\":\"\(index)\"}".utf8)
                    #expect(try strategy.decode(bytes, response: http()).value.displayName == String(index))
                }
            }
            try await group.waitForAll()
        }
    }

    @Test func cancellationBeforeAndAfterSynchronousDecoding() async throws {
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            #expect(throws: CancellationError.self) {
                try ResponseStrategy<Data>.data.decode(Data(), response: http())
            }
        }
        await task.value
        struct CancelsTask: Decodable, Sendable {
            init(from decoder: any Decoder) throws { withUnsafeCurrentTask { $0?.cancel() } }
        }
        _ = await Task {
            #expect(throws: CancellationError.self) {
                try ResponseStrategy<CancelsTask>.json().decode(Data("{}".utf8), response: http())
            }
        }.value
    }
}

@Suite struct HTTPStatusPolicyTests {
    @Test func defaultsAndBoundaries() throws {
        for code in 100...599 {
            #expect(HTTPStatusPolicy.successful.accepts(try HTTPStatus(code)) == (200...299).contains(code))
        }
        let custom = try HTTPStatusPolicy(range: 400...404)
        #expect(custom.accepts(try HTTPStatus(400)))
        #expect(custom.accepts(try HTTPStatus(404)))
        #expect(!custom.accepts(try HTTPStatus(200)))
        #expect(!custom.accepts(try HTTPStatus(405)))
    }
    @Test func rejectsEmptyOrInvalidPolicies() throws {
        for codes: Set<Int> in [[], [99], [600], [200, 999]] {
            #expect(throws: NetworkError.invalidRequest(.invalidConfiguration)) { try HTTPStatusPolicy(codes: codes) }
        }
        #expect(throws: NetworkError.invalidRequest(.invalidConfiguration)) { try HTTPStatusPolicy(range: Int.min...Int.max) }
    }
}
