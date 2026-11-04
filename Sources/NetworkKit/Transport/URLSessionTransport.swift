import Foundation

/// Internal URLSession transport for APIClient, with per-operation redirect/trust policy.
internal actor URLSessionTransport: NetworkTransport {
    typealias StoragePolicy = SessionStorageProfile

    typealias DataOperation = @Sendable (URLSession, URLRequest, NetworkTaskDelegate) async throws -> TransportResponse
    static let systemDataOperation: DataOperation = { session, request, delegate in
        let (data, response) = try await session.data(for: request, delegate: delegate)
        return TransportResponse(data: data, response: response)
    }

    typealias DownloadOperation = @Sendable (URLSession, URLRequest, NetworkTaskDelegate) async throws -> (URL, URLResponse)
    static let systemDownloadOperation: DownloadOperation = { session, request, delegate in
        try await session.download(for: request, delegate: delegate)
    }

    let session: URLSession
    let ownsSession: Bool
    private let storagePolicy: StoragePolicy
    private let dataOperation: DataOperation
    private let downloadOperation: DownloadOperation
    private let securityPolicy: NetworkSecurityPolicy
    private let baseURL: URL?
    private var invalidated = false

    /// Starts from ephemeral, then explicitly disables even in-memory automatic stores.
    static func configuration(timeouts: NetworkTimeouts = .default) -> URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        config.urlCredentialStorage = nil
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.waitsForConnectivity = false
        config.timeoutIntervalForRequest = timeouts.inactivity
        // Keep the platform resource limit; a 60-second cap would contradict longer calls.
        // The monotonic per-operation total budget is implemented separately in I12.
        return config
    }

    /// Custom protocolClasses are an internal test seam, never a public plugin system.
    init(ownedConfiguration: URLSessionConfiguration = URLSessionTransport.configuration(),
         dataOperation: @escaping DataOperation = URLSessionTransport.systemDataOperation,
         downloadOperation: @escaping DownloadOperation = URLSessionTransport.systemDownloadOperation,
         securityPolicy: NetworkSecurityPolicy = .default, baseURL: URL? = nil) throws {
        guard let copy = ownedConfiguration.copy() as? URLSessionConfiguration else {
            throw NetworkError.invalidRequest(.invalidConfiguration)
        }
        try Self.validate(copy, storagePolicy: .strict)
        session = URLSession(configuration: copy)
        ownsSession = true
        storagePolicy = .strict
        self.dataOperation = dataOperation
        self.downloadOperation = downloadOperation
        self.securityPolicy = securityPolicy
        self.baseURL = baseURL
    }

    init(session: URLSession, storagePolicy: StoragePolicy = .strict,
         dataOperation: @escaping DataOperation = URLSessionTransport.systemDataOperation,
         downloadOperation: @escaping DownloadOperation = URLSessionTransport.systemDownloadOperation,
         securityPolicy: NetworkSecurityPolicy = .default, baseURL: URL? = nil) throws {
        guard session.delegate == nil else { throw NetworkError.invalidRequest(.unsupportedRequest) }
        try Self.validate(session.configuration, storagePolicy: storagePolicy)
        self.session = session
        ownsSession = false
        self.storagePolicy = storagePolicy
        self.dataOperation = dataOperation
        self.downloadOperation = downloadOperation
        self.securityPolicy = securityPolicy
        self.baseURL = baseURL
    }

    private static func validate(_ configuration: URLSessionConfiguration, storagePolicy: StoragePolicy) throws {
        guard (configuration.httpAdditionalHeaders ?? [:]).isEmpty else {
            throw NetworkError.invalidRequest(.unsupportedRequest)
        }
        guard configuration.identifier == nil else { throw NetworkError.invalidRequest(.unsupportedRequest) }
        guard configuration.timeoutIntervalForRequest.isFinite, configuration.timeoutIntervalForRequest > 0,
              configuration.timeoutIntervalForResource.isFinite, configuration.timeoutIntervalForResource > 0 else {
            throw NetworkError.invalidRequest(.invalidConfiguration)
        }
        if storagePolicy == .appManaged && configuration.urlCredentialStorage != nil {
            throw NetworkError.invalidRequest(.unsupportedRequest)
        }
        if storagePolicy == .strict {
            guard configuration.httpCookieStorage == nil, !configuration.httpShouldSetCookies,
                  configuration.httpCookieAcceptPolicy == .never, configuration.urlCredentialStorage == nil,
                  configuration.urlCache == nil, configuration.requestCachePolicy == .reloadIgnoringLocalCacheData else {
                throw NetworkError.invalidRequest(.invalidConfiguration)
            }
        }
    }

    private func validatedTask(_ input: URLRequest) throws -> (URLRequest, NetworkTaskDelegate) {
        try Task.checkCancellation()
        guard !invalidated else { throw NetworkError.invalidRequest(.clientClosed) }
        guard input.httpBodyStream == nil else { throw NetworkError.invalidRequest(.unsupportedRequest) }
        let origin = try securityPolicy.validateRequest(input, baseURL: baseURL, allowAdditionalOrigins: true)
        let foreignOrigin = try baseURL.map { origin != (try NetworkOrigin($0)) } ?? false
        if foreignOrigin {
            let config = session.configuration
            guard config.httpCookieStorage == nil, !config.httpShouldSetCookies else {
                throw NetworkError.invalidRequest(.unsupportedRequest)
            }
        }
        if origin.scheme == "http" {
            let config = session.configuration
            guard config.httpCookieStorage == nil, !config.httpShouldSetCookies, config.urlCache == nil else {
                throw NetworkError.invalidRequest(.unsupportedRequest)
            }
        }
        var request = input
        if storagePolicy == .strict || origin.scheme == "http" || foreignOrigin {
            request.httpShouldHandleCookies = false
            request.cachePolicy = .reloadIgnoringLocalCacheData
        }
        let delegate = try NetworkTaskDelegate(request: request, policy: securityPolicy,
                                              disableAutomaticStorage: storagePolicy == .strict || foreignOrigin)
        return (request, delegate)
    }

    func send(_ input: URLRequest) async throws -> TransportResponse {
        let (request, delegate) = try validatedTask(input)
        do {
            let result = try await dataOperation(session, request, delegate)
            try Task.checkCancellation()
            if let failure = delegate.failure { throw failure }
            return result
        } catch {
            try Task.checkCancellation()
            if let failure = delegate.failure { throw failure }
            throw error
        }
    }

    func download(_ input: URLRequest, owner: DownloadFileOwner) async throws -> URLResponse {
        let (request, delegate) = try validatedTask(input)
        do {
            let (url, response) = try await downloadOperation(session, request, delegate)
            // Native success can race cancellation. Register the file before any throwing check.
            owner.adopt(url)
            try Task.checkCancellation()
            if let failure = delegate.failure { throw failure }
            return response
        } catch {
            try Task.checkCancellation()
            if let failure = delegate.failure { throw failure }
            throw error
        }
    }

    /// Called after the client has joined its own operations. Borrowed sessions remain open.
    /// Borrowed sessions and every task belonging to their other consumers are untouched.
    func invalidateOwnedSession() {
        guard ownsSession, !invalidated else { return }
        invalidated = true
        session.invalidateAndCancel()
    }

    func shutdown() { invalidateOwnedSession() }

    deinit {
        if ownsSession {
            if !invalidated { session.invalidateAndCancel() }
        }
    }
}
