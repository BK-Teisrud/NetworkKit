import Foundation
import CryptoKit
import Security

struct SigningHandle: Sendable {
    let keyID: String
    let authenticate: @Sendable (Data) async throws -> Data
}
struct SignedProbe: Sendable {
    let method: String
    let target: String
    let body: Data
    let headers: [String: String]
    var json: [String: Any] { ["method": method, "target": target, "body64": body.base64EncodedString(), "headers": headers] }
}
func quoted(_ value: String) throws -> String {
    try require(!value.isEmpty && value.utf8.count <= 128 && value.utf8.allSatisfy { (32...126).contains($0) }, "identifier")
    return "\"" + value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
}
func metadataExpiry(_ created: Int64) throws -> Int64 {
    let (value, overflow) = created.addingReportingOverflow(60)
    try require(!overflow, "expiry-overflow"); return value
}
func signed(target: String = "https://example.invalid/", body: Data = Data(),
            headers: [String: String] = [:], keyID: String = "test-key", maximum: Int = 65536) throws -> SignedProbe {
    try require(body.count <= maximum && maximum > 0, "body-limit")
    try require(Set(headers.keys.map { $0.lowercased() }).isDisjoint(with: ["signature", "signature-input", "content-digest", "content-encoding"]), "reserved")
    var fields = headers
    fields["content-digest"] = "sha-256=:" + Data(SHA256.hash(data: body)).base64EncodedString() + ":"
    var names = ["@method", "@target-uri", "content-digest"]
    names += ["content-type", "authorization"].filter { fields[$0] != nil }
    let method = body.isEmpty ? "GET" : "POST"
    let values = fields.merging(["@method": method, "@target-uri": target]) { _, right in right }
    let parameters = "(" + names.map { "\"" + $0 + "\"" }.joined(separator: " ") + ");created=1000;expires=1060;nonce=\"AAAAAAAAAAAAAAAAAAAAAA\";keyid=" + (try quoted(keyID)) + ";alg=\"hmac-sha256\""
    let base = names.map { "\"" + $0 + "\": " + values[$0]! }.joined(separator: "\n") + "\n\"@signature-params\": " + parameters
    let key = SymmetricKey(data: Data((0..<32).map { UInt8($0) }))
    let mac = Data(HMAC<SHA256>.authenticationCode(for: Data(base.utf8), using: key))
    fields["signature-input"] = "sig1=" + parameters
    fields["signature"] = "sig1=:" + mac.base64EncodedString() + ":"
    return SignedProbe(method: method, target: target, body: body, headers: fields)
}
func validateCredential(_ value: URLCredential?) throws {
    guard let value else { throw ProbeFailure.failed("nil-identity") }
    try require(value.persistence == .none && value.identity != nil, "invalid-identity")
    try require(value.certificates.allSatisfy { CFGetTypeID($0 as CFTypeRef) == SecCertificateGetTypeID() }, "invalid-chain")
}
func originPolicy(_ source: URL, expected: URL, failures: Int = 0) throws {
    try require(source.scheme == expected.scheme && source.host == expected.host && (source.port ?? 443) == (expected.port ?? 443) && failures == 0, "origin-policy")
}
func pinSet(_ pins: [Data]) throws {
    try require(pins.count >= 2 && pins.count <= 8 && pins.allSatisfy { $0.count == 32 } && Set(pins).count == pins.count, "pins")
}
func fixtureCredential(_ root: URL, name: String) throws -> URLCredential {
    let bytes = try Data(contentsOf: root.appendingPathComponent(name + ".key.der"))
    let certBytes = try Data(contentsOf: root.appendingPathComponent(name + ".cert.der"))
    let attrs: [CFString: Any] = [kSecAttrKeyType: kSecAttrKeyTypeRSA, kSecAttrKeyClass: kSecAttrKeyClassPrivate]
    guard let key = SecKeyCreateWithData(bytes as CFData, attrs as CFDictionary, nil),
          let cert = SecCertificateCreateWithData(nil, certBytes as CFData),
          let identity = SecIdentityCreate(nil, cert, key) else { throw ProbeFailure.failed("in-memory-identity") }
    let result = URLCredential(identity: identity, certificates: [cert], persistence: .none)
    try validateCredential(result); return result
}
