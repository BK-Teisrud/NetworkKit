import Foundation
import Testing
@testable import NetworkKit

private struct TestEndpoint: Endpoint {
    typealias Response = EmptyResponse
    let path: EndpointPath
    var query: [HTTPQueryItem] = []
}

@Suite struct EndpointURLTests {
    private let baseURL = URL(string: "https://example.invalid/api/v1")!
    private let invalid = NetworkError.invalidRequest(.invalidURL)

    @Test func typedEndpointAndBasePath() throws {
        let endpoint = TestEndpoint(path: try EndpointPath(segments: ["users", "42"]))
        #expect(endpoint.method == .get)
        #expect(try endpoint.url(relativeTo: baseURL).absoluteString == "https://example.invalid/api/v1/users/42")
        #expect(try endpoint.url(relativeTo: URL(string: "https://example.invalid/api/v1/")!).absoluteString
            == "https://example.invalid/api/v1/users/42")
        #expect(try endpoint.url(relativeTo: URL(string: "https://example.invalid")!).path == "/users/42")
        let root = TestEndpoint(path: try EndpointPath(segments: []))
        #expect(try root.url(relativeTo: baseURL) == baseURL)
        #expect(try root.url(relativeTo: URL(string: "https://example.invalid/api/")!).absoluteString
            == "https://example.invalid/api/")
    }

    @Test func reservedAndUnicodeSegmentsAreData() throws {
        let segments = ["a/b", "https://other.invalid?q=x#fragment", "a b+&=?#;:@[]", "100%", "café", "e\u{301}", "日本語", "🦊", "👨‍👩‍👦"]
        let url = try TestEndpoint(path: EndpointPath(segments: segments)).url(relativeTo: baseURL)
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        #expect(components.host == "example.invalid")
        #expect(components.scheme == "https")
        #expect(components.query == nil)
        #expect(components.fragment == nil)
        let encoded = components.percentEncodedPath.split(separator: "/").dropFirst(2)
        #expect(encoded.count == segments.count)
        for (part, expected) in zip(encoded, segments) {
            #expect(part.removingPercentEncoding!.utf8.elementsEqual(expected.utf8))
        }
        #expect(components.percentEncodedPath.contains("a%2Fb"))
        #expect(components.percentEncodedPath.contains("100%25"))
        #expect(components.percentEncodedPath.contains("caf%C3%A9/e%CC%81/"))
    }

    @Test func queryOrderingRepetitionsAndOptionalValues() throws {
        let items = try [HTTPQueryItem(name: "tag", value: "one"), HTTPQueryItem(name: "tag", value: "two"),
                         HTTPQueryItem(name: "flag"), HTTPQueryItem(name: "empty", value: ""),
                         HTTPQueryItem(name: "a&=+#?", value: " a+b&c=d#?/%2F café"),
                         HTTPQueryItem(name: "", value: "")]
        let endpoint = TestEndpoint(path: try EndpointPath(segments: []), query: items)
        let url = try endpoint.url(relativeTo: baseURL)
        let c = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        #expect(c.percentEncodedQuery == "tag=one&tag=two&flag&empty=&a%26%3D%2B%23%3F=%20a%2Bb%26c%3Dd%23%3F%2F%252F%20caf%C3%A9&=")
        let decoded = c.queryItems!
        #expect(decoded.count == items.count)
        for (actual, expected) in zip(decoded, items) {
            #expect(actual.name.utf8.elementsEqual(expected.name.utf8))
            #expect(actual.value == expected.value)
        }
        #expect(decoded[2].value == nil)
        #expect(decoded[3].value == "")
        #expect(!decoded.contains(where: { $0.name == "omitted" }))
    }

    @Test(arguments: ["", ".", "..", "a/../b", "a/./b", "\\evil", "a\\b", "%2F", "%2e%2E", "%252e", "a%20b", "\u{85}"])
    func invalidSegments(_ segment: String) {
        #expect(throws: invalid) { try EndpointPath(segments: [segment]) }
    }

    @Test func asciiEscapingAndControlValidation() throws {
        for code in 0...127 {
            let text = String(UnicodeScalar(code)!)
            if code < 32 || code == 127 {
                #expect(throws: invalid) { try EndpointPath(segments: [text]) }
                #expect(throws: invalid) { try HTTPQueryItem(name: text) }
                #expect(throws: invalid) { try HTTPQueryItem(name: "q", value: text) }
            } else if text == "." || text == "\\" {
                #expect(throws: invalid) { try EndpointPath(segments: [text]) }
            } else {
                let endpoint = TestEndpoint(path: try EndpointPath(segments: [text]))
                let url = try endpoint.url(relativeTo: baseURL)
                let encoded = URLComponents(url: url, resolvingAgainstBaseURL: false)!.percentEncodedPath.split(separator: "/").last!
                #expect(encoded.removingPercentEncoding == text)
                #expect(url.host == baseURL.host)
            }
        }
    }

    @Test(arguments: ["/relative", "//example.invalid/api", "file:///tmp/a", "ftp://example.invalid/a",
                     "https:///missing-host", "https://user:SECRET@example.invalid/a", "https://example.invalid/a#SECRET",
                     "https://example.invalid/a#", "https://example.invalid/a?", "https://example.invalid/a?q=SECRET",
                     "https://example.invalid:0/a", "https://example.invalid:65536/a", "https://example.invalid/a/../b",
                     "https://example.invalid/%2e%2e", "https://example.invalid/%252e%252e", "https://example.invalid/a%2F..%2Fb",
                     "https://example.invalid/%00", "https://example.invalid/%FF", "https://example.invalid/a%5Cb",
                     "https://example%2einvalid/a", "https://example.invalid./a", "https://bad%20host/a"])
    func invalidBaseURLs(_ text: String) throws {
        // Some malformed strings are rejected by Foundation before the library sees them.
        guard let url = URL(string: text) else { return }
        let endpoint = TestEndpoint(path: try EndpointPath(segments: ["safe"]))
        #expect(throws: invalid) { try endpoint.url(relativeTo: url) }
    }

    @Test func relativeURLWithFoundationBaseIsRejected() throws {
        let relative = URL(string: "child", relativeTo: baseURL)!
        let endpoint = TestEndpoint(path: try EndpointPath(segments: []))
        #expect(throws: invalid) { try endpoint.url(relativeTo: relative) }
    }

    @Test func snapshotsKeepTheirOwnPathAndQuery() async throws {
        let endpoint = TestEndpoint(path: try EndpointPath(segments: ["original"]),
                                    query: try [HTTPQueryItem(name: "q", value: "initial")])
        let urls = try await withThrowingTaskGroup(of: URL.self) { group in
            for index in 0..<50 {
                group.addTask {
                    var copy = endpoint
                    copy.query = try [HTTPQueryItem(name: "q", value: String(index))]
                    return try copy.url(relativeTo: baseURL)
                }
            }
            var result: [URL] = []
            for try await url in group { result.append(url) }
            return result
        }
        #expect(Set(urls).count == 50)
        #expect(endpoint.query[0].value == "initial")
        #expect(urls.allSatisfy { $0.path == "/api/v1/original" && $0.host == baseURL.host })
    }

    @Test func existingEscapesStayEncodedOnce() throws {
        let base = URL(string: "https://example.invalid/caf%C3%A9/a%2Fb/100%25")!
        let endpoint = TestEndpoint(path: try EndpointPath(segments: ["new%", "literal%ZZ"]))
        let url = try endpoint.url(relativeTo: base)
        #expect(URLComponents(url: url, resolvingAgainstBaseURL: false)!.percentEncodedPath
            == "/caf%C3%A9/a%2Fb/100%25/new%25/literal%25ZZ")
    }

    @Test func safeDescriptionsAndErrors() throws {
        let path = try EndpointPath(segments: ["SECRET"])
        let query = try HTTPQueryItem(name: "SECRET", value: "SECRET")
        for text in [String(describing: path), String(reflecting: path), String(describing: query), String(reflecting: query)] {
            #expect(!text.contains("SECRET"))
        }
        do {
            _ = try TestEndpoint(path: path).url(relativeTo: URL(string: "https://SECRET@example.invalid")!)
            Issue.record("Userinfo must fail")
        } catch {
            #expect(error as? NetworkError == invalid)
            #expect(!String(describing: error).contains("SECRET"))
            #expect(!String(reflecting: error).contains("example.invalid"))
            #expect(!error.localizedDescription.contains("SECRET"))
        }
    }
}

@Suite struct RawRequestURLTests {
    private let baseURL = URL(string: "https://example.invalid/api")!
    private let invalid = NetworkError.invalidRequest(.invalidURL)

    @Test(arguments: ["https://EXAMPLE.invalid:443/other?flag&empty=&tag=a&tag=b",
                     "https://example.invalid/a%2Fb", "https://example.invalid/caf%C3%A9"])
    func validSameOriginRequestPreservesURL(_ text: String) throws {
        let url = URL(string: text)!
        let request = URLRequest(url: url)
        #expect(try RequestBuilder.prepare(request, configuration: NetworkConfiguration(baseURL: baseURL)).request.url == url)
    }

    @Test(arguments: ["https://other.invalid/api", "http://example.invalid/api", "https://example.invalid:444/api",
                     "https://example.invalid/api#fragment", "https://user:SECRET@example.invalid/api",
                     "https://example.invalid/a/../b", "https://example.invalid/%2e%2e", "https://example.invalid/%252e",
                     "https://example.invalid/%5Cevil", "https://example.invalid/%00", "https://example.invalid/%FF",
                     "https://example.invalid/?q=%00", "https://example.invalid/?q=%FF", "/relative"])
    func invalidRequestsUseSameValidation(_ text: String) throws {
        let request = URLRequest(url: URL(string: text)!)
        let reason: NetworkError.InvalidRequestReason
        switch text {
        case "https://other.invalid/api", "https://example.invalid:444/api": reason = .unpermittedOrigin
        case "http://example.invalid/api": reason = .insecureTransport
        default: reason = .invalidURL
        }
        #expect(throws: NetworkError.invalidRequest(reason)) {
            try RequestBuilder.prepare(request, configuration: NetworkConfiguration(baseURL: baseURL))
        }
    }

    @Test func missingURLAndInvalidBaseAreRejected() throws {
        var request = URLRequest(url: baseURL)
        request.url = nil
        #expect(throws: invalid) { try RequestBuilder.prepare(request, configuration: NetworkConfiguration(baseURL: baseURL)) }
        #expect(throws: invalid) {
            try RequestBuilder.prepare(URLRequest(url: baseURL), configuration: NetworkConfiguration(baseURL: URL(string: "file:///tmp")!))
        }
    }

    @Test(arguments: [
        ["https://bücher.example/api", "https://xn--bcher-kva.example:443/other"],
        ["http://localhost/api", "http://localhost:80/other"],
        ["https://[::1]/api", "https://[::1]:443/other"]
    ])
    func unicodeHostAndEffectivePorts(_ pair: [String]) throws {
        let base = URL(string: pair[0])!
        let request = URLRequest(url: URL(string: pair[1])!)
        let configuration = NetworkConfiguration(baseURL: base,
            security: NetworkSecurityPolicy(allowInsecureLoopback: true))
        #expect(try RequestBuilder.prepare(request, configuration: configuration).request.url == request.url)
    }

    @Test func typedURLPassesRawValidation() throws {
        let endpoint = TestEndpoint(path: try EndpointPath(segments: ["a/b", "space here", "é"]),
                                    query: try [HTTPQueryItem(name: "q", value: "a+b&c")])
        let typed = try endpoint.url(relativeTo: baseURL)
        #expect(try RequestBuilder.prepare(URLRequest(url: typed), configuration: NetworkConfiguration(baseURL: baseURL)).request.url == typed)
    }
}
