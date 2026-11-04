import Foundation
import os

/// One per operation. Locked state is never held while invoking completion handlers.
internal final class NetworkTaskDelegate: NSObject, URLSessionTaskDelegate {
    private struct State: Sendable {
        var followed = 0
        var visited: Set<String>
        var failure: NetworkError?
    }
    private let state: OSAllocatedUnfairLock<State>
    private let origin: NetworkOrigin
    private let method: String
    private let policy: NetworkSecurityPolicy
    private let disableAutomaticStorage: Bool

    init(request: URLRequest, policy: NetworkSecurityPolicy, disableAutomaticStorage: Bool) throws {
        origin = try policy.validateRequest(request)
        method = request.httpMethod ?? "GET"
        self.policy = policy
        self.disableAutomaticStorage = disableAutomaticStorage
        state = OSAllocatedUnfairLock(initialState: State(visited: [request.url!.absoluteString]))
    }

    var failure: NetworkError? { state.withLock { $0.failure } }

    func redirectedRequest(response: HTTPURLResponse, proposed: URLRequest) -> URLRequest? {
        guard [301, 302, 303, 307, 308].contains(response.statusCode),
              method == "GET" || method == "HEAD", proposed.httpMethod == method,
              proposed.httpBody == nil, proposed.httpBodyStream == nil,
              let source = response.url, let destination = proposed.url,
              (try? NetworkOrigin(source)) == origin,
              (try? policy.validateRequest(proposed)) == origin else { return nil }
        let allowed = state.withLock { state in
            guard state.failure == nil else { return false }
            guard state.followed < 5, !state.visited.contains(destination.absoluteString) else {
                state.failure = .invalidResponse(.redirectLimitExceeded)
                return false
            }
            state.followed += 1
            state.visited.insert(destination.absoluteString)
            return true
        }
        guard allowed else { return nil }
        var result = proposed
        if disableAutomaticStorage || origin.scheme == "http" {
            result.httpShouldHandleCookies = false
            result.cachePolicy = .reloadIgnoringLocalCacheData
        }
        return result
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        let approved = redirectedRequest(response: response, proposed: request)
        // A recorded loop/hop-limit failure is terminal. Do not depend on
        // Foundation finishing delivery of a declined empty redirect response.
        // Ordinary policy-denied redirects have no failure and keep their response.
        if failure != nil { task.cancel() }
        completionHandler(approved)
    }

    static func challengeDisposition(for method: String) -> URLSession.AuthChallengeDisposition {
        method == NSURLAuthenticationMethodServerTrust ? .performDefaultHandling : .cancelAuthenticationChallenge
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(Self.challengeDisposition(for: challenge.protectionSpace.authenticationMethod), nil)
    }

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(Self.challengeDisposition(for: challenge.protectionSpace.authenticationMethod), nil)
    }
}
