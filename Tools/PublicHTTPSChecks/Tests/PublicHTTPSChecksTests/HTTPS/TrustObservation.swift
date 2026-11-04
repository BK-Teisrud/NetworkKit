import Foundation
import NetworkKit
import Security
import Testing
import os

/// Corroboration only: ordinary ephemeral URLSession, system default trust handling.
/// Never returns a credential or accepts a failed trust decision.
final class TrustObservation: NSObject, URLSessionTaskDelegate {
    private struct State: Sendable { var challengeSeen = false; var trustError: Int?; var knownDomain = false }
    private let state = OSAllocatedUnfairLock(initialState: State())

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trust = challenge.protectionSpace.serverTrust {
            var error: CFError?
            _ = SecTrustEvaluateWithError(trust, &error)
            let code = error.map { CFErrorGetCode($0) }
            let known = error.map { CFEqual(CFErrorGetDomain($0), kCFErrorDomainOSStatus) } ?? false
            state.withLock { $0.challengeSeen = true; $0.trustError = code; $0.knownDomain = known }
        }
        completionHandler(.performDefaultHandling, nil)
    }

    func corroborate(base: URL, name: String, input: Input, expectedTrustError: Int) async -> Bool {
        let settings = URLSessionConfiguration.ephemeral
        settings.httpCookieStorage = nil; settings.urlCredentialStorage = nil; settings.urlCache = nil
        settings.timeoutIntervalForRequest = NetworkTimeouts.default.inactivity
        settings.timeoutIntervalForResource = NetworkTimeouts.default.total
        let session = URLSession(configuration: settings)
        defer { session.invalidateAndCancel() }
        var code: Int?
        var knownTransportDomain = false
        do { _ = try await session.data(for: URLRequest(url: base), delegate: self) }
        catch { let error = error as NSError; code = error.code; knownTransportDomain = error.domain == NSURLErrorDomain }
        let observation = state.withLock { $0 }
        print("PublicHTTPS corroboration \(name) \(input.rawValue): challenge=\(observation.challengeSeen) trust-code=\(observation.trustError.map(String.init) ?? "none") transport-code=\(code.map(String.init) ?? "none")")
        return observation.challengeSeen && observation.knownDomain && observation.trustError == expectedTrustError
            && knownTransportDomain && code == URLError.secureConnectionFailed.rawValue
    }
}
