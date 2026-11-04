import Foundation
import NetworkKit
import Testing

struct HTTPMethodTests {
    @Test func standardMethodsAndCaseSensitivity() throws {
        let standards: [(HTTPMethod, String)] = [
            (.get, "GET"), (.post, "POST"), (.put, "PUT"), (.patch, "PATCH"),
            (.delete, "DELETE"), (.head, "HEAD"), (.options, "OPTIONS"),
        ]
        for (method, spelling) in standards {
            #expect(method.rawValue == spelling)
            #expect(try HTTPMethod(spelling) == method)
        }
        #expect(try HTTPMethod("get") != .get)
        #expect(try HTTPMethod("get").rawValue == "get")
        #expect(Set([HTTPMethod.get, try HTTPMethod("GET")]).count == 1)
    }

    @Test func tokenAlphabetIsASCIIOnly() {
        let allowed = "!#$%&'*+-.^_`|~0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
        for scalar in UInt8(0)...UInt8(127) {
            let character = String(UnicodeScalar(scalar))
            if allowed.contains(character) {
                #expect(throws: Never.self) { try HTTPMethod(character) }
            } else {
                #expect(throws: NetworkError.invalidRequest(.invalidMethod)) {
                    try HTTPMethod(character)
                }
            }
        }
    }

    @Test(arguments: ["", "G ET", "GET\r\nX: injected", "GÉT", "ＧＥＴ", "GET/", " GET"])
    func invalidMethodsFailWithoutEchoingInput(_ input: String) {
        #expect(throws: NetworkError.invalidRequest(.invalidMethod)) { try HTTPMethod(input) }
    }

    @Test func customMethodsDoNotAppearInDescriptions() throws {
        let method = try HTTPMethod("CANARY-CUSTOM-METHOD")
        #expect(method.rawValue == "CANARY-CUSTOM-METHOD")
        #expect(String(describing: method) == "HTTPMethod(custom)")
        #expect(String(reflecting: method) == "HTTPMethod(custom)")
        #expect(String(describing: HTTPMethod.get) == "HTTPMethod(GET)")
    }
}

struct HTTPHeadersTests {
    @Test func caseInsensitiveLookupPreservesOpaqueValues() throws {
        let fields = try HTTPHeaders(["Content-Type": "application/json", "X-List": "a, b", "X-Empty": ""])
        #expect(fields["CONTENT-TYPE"] == "application/json")
        #expect(fields["content-type"] == "application/json")
        #expect(fields["X-LIST"] == "a, b")
        #expect(fields["x-empty"] == "")
        #expect(fields["missing"] == nil)
        #expect(fields.fields["content-type"] == "application/json")
        #expect(fields.count == 3)
        #expect(HTTPHeaders().count == 0)
    }

    @Test func equalDuplicatesCollapseButConflictsFail() throws {
        let fields = try HTTPHeaders(["Accept": "application/json", "ACCEPT": "application/json"])
        #expect(fields.count == 1)
        #expect(try fields == HTTPHeaders(["accept": "application/json"]))
        #expect(throws: NetworkError.invalidRequest(.conflictingHeaders)) {
            try HTTPHeaders(["Accept": "a", "accept": "b"])
        }
        #expect(throws: NetworkError.invalidRequest(.conflictingHeaders)) {
            try HTTPHeaders(["ACCEPT": "b", "accept": "a"])
        }
    }

    @Test(arguments: ["", "X Field", "X:Field", "X\r\nInjected", "Héader", "K", "X/Field"])
    func invalidNamesAreRejected(_ name: String) {
        #expect(throws: NetworkError.invalidRequest(.invalidHeaderName)) {
            try HTTPHeaders([name: "value"])
        }
    }

    @Test func controlsAreRejectedExceptHorizontalTab() {
        for byte in Array(UInt8(0)...UInt8(31)) + [127] where byte != 9 {
            let value = "before" + String(UnicodeScalar(byte)) + "after"
            #expect(throws: NetworkError.invalidRequest(.invalidHeaderValue)) {
                try HTTPHeaders(["X-Value": value])
            }
        }
        #expect(throws: Never.self) { try HTTPHeaders(["X-Value": "a\tb"]) }
    }

    @Test func opaqueValuesAreNotUnicodeNormalized() throws {
        let composed = "\u{E9}"
        let decomposed = "e\u{301}"
        #expect(composed == decomposed) // Swift String equality normalizes these.
        let first = try HTTPHeaders(["X-Value": composed])
        let second = try HTTPHeaders(["x-value": decomposed])
        #expect(first != second)
        let stored = try #require(first["X-Value"])
        #expect(Array(stored.utf8) == [0xC3, 0xA9])
        #expect(throws: NetworkError.invalidRequest(.conflictingHeaders)) {
            try HTTPHeaders(["X-Value": composed, "x-value": decomposed])
        }
    }

    @Test func lookupRejectsUnicodeAliasesAndMalformedNames() throws {
        let fields = try HTTPHeaders(["K": "secret"])
        #expect(fields["k"] == "secret")
        #expect(fields["K"] == nil)
        #expect(fields[" K"] == nil)
        #expect(fields["K\r\n"] == nil)
    }

    @Test func snapshotsDoNotChangeWithInputOrExportedDictionary() throws {
        var source = ["Authorization": "CANARY-ORIGINAL"]
        let fields = try HTTPHeaders(source)
        source["Authorization"] = "changed"
        var exported = fields.fields
        exported["authorization"] = "changed-again"
        #expect(fields["Authorization"] == "CANARY-ORIGINAL")
        #expect(source["Authorization"] == "changed")
        #expect(exported["authorization"] == "changed-again")
    }

    @Test func descriptionsDoNotExposeNamesOrValues() throws {
        let fields = try HTTPHeaders(["X-CANARY-NAME": "CANARY-TOKEN"])
        #expect(String(describing: fields) == "HTTPHeaders(count: 1)")
        #expect(String(reflecting: fields) == "HTTPHeaders(count: 1)")
    }
}

struct HTTPStatusTests {
    @Test func everyValidStatusHasTheExpectedDefaultClassification() throws {
        for code in 100...599 {
            let status = try HTTPStatus(code)
            #expect(status.code == code)
            #expect(status.isSuccessful == (code / 100 == 2))
        }
        #expect(try HTTPStatus(471).code == 471)
        #expect(try Set([HTTPStatus(200), HTTPStatus(200)]).count == 1)
    }

    @Test(arguments: [Int.min, -1, 0, 99, 600, 999, Int.max])
    func invalidStatusesAreRejected(_ code: Int) {
        #expect(throws: NetworkError.invalidResponse(.invalidStatusCode)) { try HTTPStatus(code) }
    }
}

struct NetworkResponseTests {
    private struct Payload: Sendable, Equatable, CustomStringConvertible {
        var text: String
        var description: String { text }
    }

    @Test func valuesAndMetadataRemainAvailableWithoutImplicitDecoding() throws {
        let status = try HTTPStatus(200)
        let fields = try HTTPHeaders(["X-Request-ID": "request-1"])
        let text = NetworkResponse(value: "hello", status: status, headers: fields)
        let data = NetworkResponse(value: Data([0, 255]), status: status, headers: fields)
        let empty = NetworkResponse(value: EmptyResponse(), status: try HTTPStatus(204), headers: fields)
        #expect(text.value == "hello")
        #expect(data.value == Data([0, 255]))
        #expect(empty.value == EmptyResponse())
        #expect(empty.status.code == 204)
        #expect(empty.headers["x-request-id"] == "request-1")
        #expect(text == NetworkResponse(value: "hello", status: status, headers: fields))
        #expect(NetworkResponse(value: EmptyResponse(), status: status).headers.count == 0)
    }

    @Test func payloadSnapshotsAndDescriptionsDoNotLeak() throws {
        var payload = Payload(text: "CANARY-PAYLOAD")
        let response = NetworkResponse(
            value: payload, status: try HTTPStatus(200),
            headers: try HTTPHeaders(["Authorization": "CANARY-HEADER"])
        )
        payload.text = "changed"
        #expect(response.value.text == "CANARY-PAYLOAD")
        #expect(payload.text == "changed")
        #expect(String(describing: response) == "NetworkResponse(status: 200, headerCount: 1)")
        #expect(String(reflecting: response) == "NetworkResponse(status: 200, headerCount: 1)")
    }

    @Test func publicValuesCanCrossTaskBoundaries() async throws {
        let headers = try HTTPHeaders(["X-Value": "snapshot"])
        let response = NetworkResponse(value: EmptyResponse(), status: try HTTPStatus(204), headers: headers)
        let method = try HTTPMethod("CUSTOM")
        let failure = NetworkError.httpStatus(try HTTPStatus(503), headers: headers)
        let copied = await Task.detached { (response, method, failure) }.value
        #expect(copied.0 == response)
        #expect(copied.1 == method)
        #expect(copied.2 == failure)
    }
}

struct NetworkErrorTests {
    @Test func transportIdentityPreservesCodeWithoutUnderlyingUserInfo() {
        let error = URLError(.secureConnectionFailed, userInfo: [
            NSURLErrorFailingURLStringErrorKey: "https://example.invalid/CANARY-URL",
            NSLocalizedDescriptionKey: "CANARY-SYSTEM-TEXT",
        ])
        let identity = NetworkError.TransportFailure(error)
        #expect(identity.domain == NSURLErrorDomain)
        #expect(identity.code == URLError.secureConnectionFailed.rawValue)
        #expect(identity == NetworkError.TransportFailure(domain: NSURLErrorDomain, code: error.code.rawValue))
        #expect(!String(reflecting: identity).contains("CANARY"))
    }

    @Test func httpErrorsRetainExplicitMetadataButDescriptionsAreSanitized() throws {
        let headers = try HTTPHeaders(["Set-Cookie": "CANARY-COOKIE"])
        let error = NetworkError.httpStatus(try HTTPStatus(401), headers: headers)
        guard case .httpStatus(let status, let metadata) = error else {
            Issue.record("Expected an HTTP status failure")
            return
        }
        #expect(status.code == 401)
        #expect(metadata["set-cookie"] == "CANARY-COOKIE")
        #expect(error.description == "NetworkKit HTTP status failure (401).")
        #expect(!String(reflecting: error).contains("CANARY"))
    }

    @Test func categoriesRemainDistinctAndAllDescriptionsAreSafe() throws {
        let errors: [NetworkError] = [
            .invalidRequest(.invalidURL),
            .transport(.init(domain: "CANARY-DOMAIN", code: -1)),
            .httpStatus(try HTTPStatus(500), headers: try HTTPHeaders(["X-Secret": "CANARY-TOKEN"])),
            .invalidResponse(.nonHTTPResponse), .encoding, .decoding,
            .timeout(.inactivity), .timeout(.totalBudget), .timeout(.system),
        ]
        for (index, error) in errors.enumerated() {
            #expect(!String(describing: error).contains("CANARY"))
            #expect(!String(reflecting: error).contains("CANARY"))
            #expect(!error.localizedDescription.contains("CANARY"))
            #expect(error.errorDescription == error.description)
            for other in errors.dropFirst(index + 1) { #expect(error != other) }
        }
    }

    @Test func cancellationRemainsASeparateSwiftError() {
        let error: any Error = CancellationError()
        #expect(error is CancellationError)
        #expect(!(error is NetworkError))
    }
}
