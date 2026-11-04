import Foundation
import Testing
import os
@testable import NetworkKit

private actor FileTestTransport: NetworkTransport {
    private(set) var calls = 0
    let work: @Sendable (URLRequest, DownloadFileOwner) async throws -> URLResponse
    init(_ work: @escaping @Sendable (URLRequest, DownloadFileOwner) async throws -> URLResponse) { self.work = work }
    func send(_ request: URLRequest) async throws -> TransportResponse { throw NetworkError.decoding }
    func download(_ request: URLRequest, owner: DownloadFileOwner) async throws -> URLResponse {
        calls += 1
        return try await work(request, owner)
    }
}
private final class FileSink: NetworkDiagnosticSink {
    private let state = OSAllocatedUnfairLock(initialState: [NetworkDiagnosticEvent]())
    var events: [NetworkDiagnosticEvent] { state.withLock { $0 } }
    func record(_ event: NetworkDiagnosticEvent) { state.withLock { $0.append(event) } }
}
private actor FileProvider: AuthenticationHeaderProvider {
    private(set) var calls = 0
    private let fields: [String: String]
    init(fields: [String: String] = ["Authorization": "synthetic-file-secret"]) { self.fields = fields }
    func headers(for context: AuthenticationContext) async throws -> HTTPHeaders {
        calls += 1
        return try HTTPHeaders(fields)
    }
}
private struct FileFixture: Sendable {
    let root: URL
    let source: URL
    let destination: URL
    init(bytes: Int = 8) throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false,
                                               attributes: [.posixPermissions: 0o700])
        source = root.appendingPathComponent("native")
        destination = root.appendingPathComponent("preserved")
        try Data(repeating: 65, count: bytes).write(to: source)
    }
    var files: DownloadFileOperations {
        var value = DownloadFileOperations()
        let destination = destination
        value.destination = { destination }
        return value
    }
    func remove() { try? FileManager.default.removeItem(at: root) }
    var sourceExists: Bool { FileManager.default.fileExists(atPath: source.path) }
    var destinationExists: Bool { FileManager.default.fileExists(atPath: destination.path) }
}
private func fileResponse(_ request: URLRequest, status: Int = 200, headers: [String: String] = ["X-File": "synthetic"]) -> HTTPURLResponse {
    HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: headers)!
}

private actor ScopedFileProvider: AuthenticationHeaderProvider {
    private(set) var contexts: [AuthenticationContext] = []
    func headers(for context: AuthenticationContext) async throws -> HTTPHeaders {
        contexts.append(context)
        return try HTTPHeaders(["Authorization": "synthetic-" + (context.account ?? "none")])
    }
}
private final class FileCommitSink: NetworkDiagnosticSink {
    private let action = OSAllocatedUnfairLock<(@Sendable () -> Void)?>(initialState: nil)
    func set(_ value: @escaping @Sendable () -> Void) { action.withLock { $0 = value } }
    func record(_ event: NetworkDiagnosticEvent) {
        if event.outcome == .success { action.withLock { $0 }?() }
    }
}
@Suite(.timeLimit(.minutes(1))) struct DownloadTests {
    private let base = URL(string: "https://example.invalid")!

    @Test(arguments: [0, 8]) func successfulFileIsAppOwnedAndNeverDeletedByShutdown(bytes: Int) async throws {
        let fixture = try FileFixture(bytes: bytes); defer { fixture.remove() }
        let sink = FileSink(), provider = FileProvider()
        let transport = FileTestTransport { request, owner in
            #expect(request.value(forHTTPHeaderField: "Authorization") == "synthetic-file-secret")
            owner.adopt(fixture.source)
            return fileResponse(request)
        }
        let configuration = NetworkConfiguration(baseURL: base, authentication: .init(provider: provider), diagnostics: sink)
        let client = try APIClient(configuration: configuration, transport: transport, downloadFiles: fixture.files)
        let result = try await client.download(URLRequest(url: base), maximumBytes: 8)
        #expect(result.value.byteCount == Int64(bytes))
        #expect(result.status.code == 200 && result.headers["x-file"] == "synthetic")
        #expect(try Data(contentsOf: result.value.url) == Data(repeating: 65, count: bytes))
        #expect(!fixture.sourceExists && fixture.destinationExists)
        #expect(await provider.calls == 1)
        #expect(await transport.calls == 1)
        await client.shutdown()
        #expect(fixture.destinationExists)
        #expect(sink.events.count == 1 && sink.events.first?.attemptCount == 1)
        #expect(sink.events.first?.outcome == .success)
        #expect(!String(describing: result.value).contains(fixture.root.path))
    }

    @Test(arguments: [0, -1]) func invalidLimitStopsBeforeProviderAndTransport(limit: Int64) async throws {
        let provider = FileProvider(), sink = FileSink()
        let transport = FileTestTransport { request, _ in fileResponse(request) }
        let client = try APIClient(configuration: .init(baseURL: base, authentication: .init(provider: provider), diagnostics: sink), transport: transport)
        await #expect(throws: NetworkError.invalidRequest(.invalidConfiguration)) {
            try await client.download(URLRequest(url: base), maximumBytes: limit)
        }
        #expect(await provider.calls == 0)
        #expect(await transport.calls == 0)
        #expect(sink.events.first?.attemptCount == 0)
    }

    @Test(arguments: ["method", "body", "range", "if-range", "default-range", "call-range"])
    func unsupportedRequestsStopBeforeProviderAndTransport(kind: String) async throws {
        let provider = FileProvider()
        let transport = FileTestTransport { request, _ in fileResponse(request) }
        var request = URLRequest(url: base)
        if kind == "method" { request.httpMethod = "POST" }
        if kind == "body" { request.httpBody = Data() }
        if kind == "range" || kind == "if-range" { request.setValue("synthetic", forHTTPHeaderField: kind) }
        let headers = kind == "default-range" ? try HTTPHeaders(["Range": "bytes=0-1"]) : HTTPHeaders()
        let options = try DownloadOptions(headers: kind == "call-range" ? HTTPHeaders(["If-Range": "synthetic"]) : HTTPHeaders())
        let client = try APIClient(configuration: .init(baseURL: base, headers: headers, authentication: .init(provider: provider)), transport: transport)
        await #expect(throws: NetworkError.invalidRequest(.unsupportedRequest)) {
            try await client.download(request, maximumBytes: 8, options: options)
        }
        #expect(await provider.calls == 0)
        #expect(await transport.calls == 0)
    }

    @Test(arguments: [206, 204, 503]) func rejectedStatusRemovesNativeFileWithoutRetry(status: Int) async throws {
        let fixture = try FileFixture(); defer { fixture.remove() }
        let transport = FileTestTransport { request, owner in owner.adopt(fixture.source); return fileResponse(request, status: status) }
        let client = try APIClient(configuration: .init(baseURL: base), transport: transport, downloadFiles: fixture.files)
        do {
            _ = try await client.download(URLRequest(url: base), maximumBytes: 8)
            Issue.record("Rejected status returned a file")
        } catch NetworkError.httpStatus(let received, _) { #expect(received.code == status) }
        #expect(!fixture.sourceExists && !fixture.destinationExists)
        #expect(await transport.calls == 1)
    }

    @Test func actualSizeLimitRemovesPreservedFileAndUsesOtherDiagnosticOutcome() async throws {
        let fixture = try FileFixture(bytes: 9); defer { fixture.remove() }
        let sink = FileSink()
        let transport = FileTestTransport { request, owner in owner.adopt(fixture.source); return fileResponse(request) }
        let client = try APIClient(configuration: .init(baseURL: base, diagnostics: sink), transport: transport, downloadFiles: fixture.files)
        await #expect(throws: DownloadError.sizeLimitExceeded) { try await client.download(URLRequest(url: base), maximumBytes: 8) }
        #expect(!fixture.sourceExists && !fixture.destinationExists)
        #expect(sink.events.first?.outcome == .other && sink.events.first?.status?.code == 200)
        #expect(sink.events.first?.attemptCount == 1)
    }

    @Test(arguments: ["preserve", "inspect", "remove"]) func fileFailureMappingAndCleanup(stage: String) async throws {
        let fixture = try FileFixture(); defer { fixture.remove() }
        var operations = fixture.files
        if stage == "preserve" { operations.preserve = { _, _ in throw CocoaError(.fileWriteNoPermission) } }
        if stage == "inspect" { operations.inspect = { _ in throw CocoaError(.fileReadNoPermission) } }
        if stage == "remove" { operations.remove = { _ in throw CocoaError(.fileWriteNoPermission) } }
        let transport = FileTestTransport { request, owner in owner.adopt(fixture.source); return fileResponse(request, status: stage == "remove" ? 503 : 200) }
        let client = try APIClient(configuration: .init(baseURL: base), transport: transport, downloadFiles: operations)
        let expected: DownloadError = stage == "remove" ? .cleanupFailed(primary: .httpStatus) : .fileSystem(stage == "preserve" ? .preserve : .inspect)
        await #expect(throws: expected) { try await client.download(URLRequest(url: base), maximumBytes: 8) }
        if stage == "remove" { #expect(fixture.sourceExists) }
        else { #expect(!fixture.sourceExists && !fixture.destinationExists) }
        #expect(!expected.localizedDescription.contains(fixture.root.path))
    }

    @Test func deadlineAfterCandidateCreationRemovesDiscardedResult() async throws {
        let fixture = try FileFixture(); defer { fixture.remove() }
        let clock = BudgetTestClock()
        var operations = fixture.files
        let inspect = operations.inspect
        operations.inspect = { url in let count = try inspect(url); clock.advance(2); return count }
        let transport = FileTestTransport { request, owner in owner.adopt(fixture.source); return fileResponse(request) }
        let client = try APIClient(configuration: .init(baseURL: base), transport: transport, clock: clock, downloadFiles: operations)
        await #expect(throws: NetworkError.timeout(.totalBudget)) {
            try await client.download(URLRequest(url: base), maximumBytes: 8, options: DownloadOptions(totalTimeout: 1))
        }
        #expect(!fixture.sourceExists && !fixture.destinationExists)
        #expect(clock.pending == 0)
    }

    @Test(arguments: [false, true]) func cancellationJoinsCleanupAndPreservesCancellationError(cleanupFails: Bool) async throws {
        let fixture = try FileFixture(); defer { fixture.remove() }
        let started = BudgetLatch(), release = BudgetLatch(), clock = BudgetTestClock()
        var operations = fixture.files
        if cleanupFails { operations.remove = { _ in throw CocoaError(.fileWriteNoPermission) } }
        let transport = FileTestTransport { request, owner in
            owner.adopt(fixture.source)
            await started.open(); await release.wait()
            return fileResponse(request)
        }
        let client = try APIClient(configuration: .init(baseURL: base), transport: transport, clock: clock, downloadFiles: operations)
        let call = Task { try await client.download(URLRequest(url: base), maximumBytes: 8) }
        await started.wait(); call.cancel(); await release.open()
        await #expect(throws: CancellationError.self) { try await call.value }
        #expect(fixture.sourceExists == cleanupFails)
        #expect(!fixture.destinationExists && clock.pending == 0)
    }

    @Test func exclusivePreservationDoesNotOverwriteOrDeleteCollisionTarget() async throws {
        let fixture = try FileFixture(); defer { fixture.remove() }
        try Data("unrelated".utf8).write(to: fixture.destination)
        let transport = FileTestTransport { request, owner in owner.adopt(fixture.source); return fileResponse(request) }
        let client = try APIClient(configuration: .init(baseURL: base), transport: transport, downloadFiles: fixture.files)
        await #expect(throws: DownloadError.fileSystem(.preserve)) { try await client.download(URLRequest(url: base), maximumBytes: 8) }
        #expect(!fixture.sourceExists)
        #expect(try Data(contentsOf: fixture.destination) == Data("unrelated".utf8))
    }
    @Test(arguments: [false, true]) func nativeReturnAdoptsBeforeCancellationCheck(borrowed: Bool) async throws {
        let fixture = try FileFixture(); defer { fixture.remove() }
        let started = BudgetLatch(), release = BudgetLatch()
        let external = URLSession(configuration: URLSessionTransport.configuration())
        defer { external.invalidateAndCancel() }
        let work: URLSessionTransport.DownloadOperation = { _, request, _ in
            await started.open(); await release.wait()
            return (fixture.source, fileResponse(request))
        }
        let transport = try borrowed
            ? URLSessionTransport(session: external, downloadOperation: work)
            : URLSessionTransport(downloadOperation: work)
        let client = try APIClient(configuration: .init(baseURL: base), transport: transport, downloadFiles: fixture.files)
        let call = Task { try await client.download(URLRequest(url: base), maximumBytes: 8) }
        await started.wait(); call.cancel(); await release.open()
        await #expect(throws: CancellationError.self) { try await call.value }
        #expect(!fixture.sourceExists && !fixture.destinationExists)
        await client.shutdown()
    }

    @Test func shutdownJoinsFileChildAndCleanupBeforeClosingAdmission() async throws {
        let fixture = try FileFixture(); defer { fixture.remove() }
        let started = BudgetLatch(), cancelled = BudgetLatch(), release = BudgetLatch()
        let clock = BudgetTestClock()
        let transport = FileTestTransport { _, owner in
            owner.adopt(fixture.source)
            await started.open()
            do { try await clock.sleep(until: clock.now().advanced(by: .seconds(7200))) }
            catch { await cancelled.open(); await release.wait(); throw error }
            throw NetworkError.invalidResponse(.nonHTTPResponse)
        }
        let client = try APIClient(configuration: .init(baseURL: base), transport: transport, clock: clock, downloadFiles: fixture.files)
        let call = Task { try await client.download(URLRequest(url: base), maximumBytes: 8) }
        await started.wait()
        let shutdown = Task { await client.shutdown() }
        await cancelled.wait()
        #expect(fixture.sourceExists)
        await release.open()
        await #expect(throws: CancellationError.self) { try await call.value }
        await shutdown.value
        #expect(!fixture.sourceExists && !fixture.destinationExists && clock.pending == 0)
        await #expect(throws: NetworkError.invalidRequest(.clientClosed)) {
            try await client.download(URLRequest(url: base), maximumBytes: 8)
        }
    }

    @Test(arguments: [7, 8, 9], ["absent", "short", "long", "encoded"])
    func storedBytesOverrideLengthAndEncodingMetadata(limit: Int64, metadata: String) async throws {
        let fixture = try FileFixture(); defer { fixture.remove() }
        var fields: [String: String] = [:]
        if metadata == "short" { fields["Content-Length"] = "1" }
        if metadata == "long" { fields["Content-Length"] = "999999" }
        if metadata == "encoded" { fields = ["Content-Encoding": "gzip", "Content-Length": "1"] }
        let headers = fields
        // Model the file returned by Foundation after transfer. No real decompression claim.
        let transport = FileTestTransport { request, owner in owner.adopt(fixture.source); return fileResponse(request, headers: headers) }
        let client = try APIClient(configuration: .init(baseURL: base), transport: transport, downloadFiles: fixture.files)
        if limit < 8 {
            await #expect(throws: DownloadError.sizeLimitExceeded) { try await client.download(URLRequest(url: base), maximumBytes: limit) }
            #expect(!fixture.sourceExists && !fixture.destinationExists)
        } else {
            let response = try await client.download(URLRequest(url: base), maximumBytes: limit)
            #expect(response.value.byteCount == 8 && fixture.destinationExists)
            #expect(try Data(contentsOf: response.value.url) == Data(repeating: 65, count: 8))
        }
    }

    @Test(arguments: ["foreign", "downgrade", "loop"])
    func deniedRedirectCandidateIsDisposed(kind: String) async throws {
        let fixture = try FileFixture(); defer { fixture.remove() }
        let followed = OSAllocatedUnfairLock(initialState: 0)
        let destination = kind == "foreign" ? URL(string: "https://other.invalid/file")!
            : kind == "downgrade" ? URL(string: "http://example.invalid/file")! : base
        let transport = try URLSessionTransport(downloadOperation: { _, request, delegate in
            let redirect = fileResponse(request, status: 302, headers: ["Location": destination.absoluteString])
            if delegate.redirectedRequest(response: redirect, proposed: URLRequest(url: destination)) != nil {
                followed.withLock { $0 += 1 }
            }
            return (fixture.source, redirect)
        })
        let client = try APIClient(configuration: .init(baseURL: base), transport: transport, downloadFiles: fixture.files)
        do { _ = try await client.download(URLRequest(url: base), maximumBytes: 8); Issue.record("Denied redirect succeeded") }
        catch NetworkError.httpStatus(let status, _) { #expect(kind != "loop" && status.code == 302) }
        catch NetworkError.invalidResponse(let reason) { #expect(kind == "loop" && reason == .redirectLimitExceeded) }
        #expect(followed.withLock { $0 } == 0)
        #expect(!fixture.sourceExists && !fixture.destinationExists)
        await client.shutdown()
    }

    @Test(arguments: ["total", "system", "inactivity"])
    func cleanupFailureCannotReplaceTimeout(mode: String) async throws {
        let fixture = try FileFixture(); defer { fixture.remove() }
        let clock = BudgetTestClock(), sink = FileSink()
        var operations = fixture.files
        operations.remove = { _ in throw CocoaError(.fileWriteNoPermission) }
        if mode == "total" {
            let inspect = operations.inspect
            operations.inspect = { url in let bytes = try inspect(url); clock.advance(2); return bytes }
        }
        let transport = FileTestTransport { request, owner in
            owner.adopt(fixture.source)
            if mode == "system" { throw URLError(.timedOut) }
            if mode == "inactivity" { throw NetworkError.timeout(.inactivity) }
            return fileResponse(request)
        }
        let client = try APIClient(configuration: .init(baseURL: base, diagnostics: sink), transport: transport, clock: clock, downloadFiles: operations)
        let reason: NetworkError.TimeoutReason = mode == "total" ? .totalBudget : mode == "system" ? .system : .inactivity
        await #expect(throws: NetworkError.timeout(reason)) {
            try await client.download(URLRequest(url: base), maximumBytes: 8, options: DownloadOptions(totalTimeout: 1))
        }
        #expect(fixture.sourceExists || fixture.destinationExists)
        #expect(sink.events.first?.outcome == .timeout(reason))
        #expect(clock.pending == 0)
    }

    @Test func cancelledAccountNeverCleansAnotherAccountsHandedOffFile() async throws {
        let first = try FileFixture(), second = try FileFixture()
        defer { first.remove(); second.remove() }
        let provider = ScopedFileProvider(), started = BudgetLatch(), release = BudgetLatch()
        let firstTransport = FileTestTransport { request, owner in
            #expect(request.value(forHTTPHeaderField: "Authorization") == "synthetic-A")
            owner.adopt(first.source); await started.open(); await release.wait()
            return fileResponse(request)
        }
        let secondTransport = FileTestTransport { request, owner in
            #expect(request.value(forHTTPHeaderField: "Authorization") == "synthetic-B")
            owner.adopt(second.source); return fileResponse(request)
        }
        let a = try APIClient(configuration: .init(baseURL: base, authentication: .init(provider: provider, account: "A", environment: "test")), transport: firstTransport, downloadFiles: first.files)
        let b = try APIClient(configuration: .init(baseURL: base, authentication: .init(provider: provider, account: "B", environment: "test")), transport: secondTransport, downloadFiles: second.files)
        let pending = Task { try await a.download(URLRequest(url: base), maximumBytes: 8) }
        await started.wait()
        let result = try await b.download(URLRequest(url: base), maximumBytes: 8)
        pending.cancel(); await release.open()
        await #expect(throws: CancellationError.self) { try await pending.value }
        await a.shutdown()
        #expect(!first.sourceExists && !first.destinationExists)
        #expect(second.destinationExists && result.value.url == second.destination)
        let contexts = await provider.contexts
        #expect(Set(contexts.compactMap(\.account)) == ["A", "B"])
        #expect(Set(contexts.map(\.requestID)).count == 2 && contexts.count == 2)
        await b.shutdown()
        #expect(second.destinationExists)
    }

    @Test func cancellationAfterCommittedSuccessDoesNotLoseAppOwnedFile() async throws {
        let fixture = try FileFixture(); defer { fixture.remove() }
        let started = BudgetLatch(), release = BudgetLatch(), sink = FileCommitSink()
        let transport = FileTestTransport { request, owner in
            owner.adopt(fixture.source); await started.open(); await release.wait()
            return fileResponse(request)
        }
        let client = try APIClient(configuration: .init(baseURL: base, diagnostics: sink), transport: transport, downloadFiles: fixture.files)
        let call = Task { try await client.download(URLRequest(url: base), maximumBytes: 8) }
        await started.wait()
        sink.set { call.cancel() }
        await release.open()
        let result = try await call.value
        #expect(call.isCancelled && result.value.url == fixture.destination && fixture.destinationExists)
        await client.shutdown()
        #expect(fixture.destinationExists)
    }

    @Test(arguments: [false, true]) func malformedResponseStillDisposesReturnedCandidate(nonHTTP: Bool) async throws {
        let fixture = try FileFixture(); defer { fixture.remove() }
        let transport = FileTestTransport { request, owner in
            owner.adopt(fixture.source)
            if nonHTTP { return URLResponse(url: request.url!, mimeType: nil, expectedContentLength: 8, textEncodingName: nil) }
            return fileResponse(request, status: 999)
        }
        let client = try APIClient(configuration: .init(baseURL: base), transport: transport, downloadFiles: fixture.files)
        await #expect(throws: NetworkError.invalidResponse(nonHTTP ? .nonHTTPResponse : .invalidStatusCode)) {
            try await client.download(URLRequest(url: base), maximumBytes: 8)
        }
        #expect(!fixture.sourceExists && !fixture.destinationExists)
    }

    @Test func symbolicCandidateCannotExposeOrRemoveItsTarget() async throws {
        let fixture = try FileFixture(); defer { fixture.remove() }
        let protected = fixture.root.appendingPathComponent("unrelated-target")
        try FileManager.default.moveItem(at: fixture.source, to: protected)
        try FileManager.default.createSymbolicLink(at: fixture.source, withDestinationURL: protected)
        let transport = FileTestTransport { request, owner in owner.adopt(fixture.source); return fileResponse(request) }
        let client = try APIClient(configuration: .init(baseURL: base), transport: transport, downloadFiles: fixture.files)
        await #expect(throws: DownloadError.fileSystem(.inspect)) { try await client.download(URLRequest(url: base), maximumBytes: 8) }
        #expect(!fixture.sourceExists && !fixture.destinationExists)
        #expect(try Data(contentsOf: protected) == Data(repeating: 65, count: 8))
    }

    @Test func diagnosticsAndErrorsRetainOnlyApprovedMetadata() async throws {
        let fixture = try FileFixture(bytes: 9); defer { fixture.remove() }
        let sink = FileSink(), secret = "synthetic-private-file-canary"
        let transport = FileTestTransport { request, owner in
            owner.adopt(fixture.source)
            return fileResponse(request, headers: ["Set-Cookie": "synthetic-private-file-canary"])
        }
        let client = try APIClient(configuration: .init(baseURL: base, diagnostics: sink), transport: transport, downloadFiles: fixture.files)
        await #expect(throws: DownloadError.sizeLimitExceeded) {
            try await client.download(URLRequest(url: base.appending(queryItems: [.init(name: "private", value: secret)])), maximumBytes: 8)
        }
        let event = try #require(sink.events.first)
        #expect(sink.events.count == 1 && event.outcome == .other && event.attemptCount == 1)
        #expect(Set(Mirror(reflecting: event).children.compactMap(\.label)) == ["requestID", "method", "status", "duration", "attemptCount", "outcome"])
        let descriptions = String(reflecting: event) + DownloadError.sizeLimitExceeded.localizedDescription
            + String(reflecting: DownloadError.cleanupFailed(primary: .fileSystem))
        #expect(!descriptions.contains(secret) && !descriptions.contains(fixture.root.path))
    }



    @Test(arguments: ["status", "size", "inspect", "transport", "response"])
    func ordinaryCleanupFailureRetainsOnlyPrimaryCategory(mode: String) async throws {
        let fixture = try FileFixture(bytes: 9); defer { fixture.remove() }
        var operations = fixture.files
        operations.remove = { _ in throw CocoaError(.fileWriteNoPermission) }
        if mode == "inspect" { operations.inspect = { _ in throw CocoaError(.fileReadNoPermission) } }
        let sink = FileSink()
        let transport = FileTestTransport { request, owner in
            owner.adopt(fixture.source)
            if mode == "transport" { throw URLError(.networkConnectionLost) }
            if mode == "response" { return URLResponse(url: request.url!, mimeType: nil, expectedContentLength: 9, textEncodingName: nil) }
            return fileResponse(request, status: mode == "status" ? 503 : 200)
        }
        let client = try APIClient(configuration: .init(baseURL: base, diagnostics: sink), transport: transport, downloadFiles: operations)
        let category: DownloadError.PrimaryFailure
        switch mode {
        case "status": category = .httpStatus
        case "size": category = .sizeLimitExceeded
        case "inspect": category = .fileSystem
        case "transport": category = .transport
        default: category = .invalidResponse
        }
        await #expect(throws: DownloadError.cleanupFailed(primary: category)) {
            try await client.download(URLRequest(url: base), maximumBytes: 8)
        }
        #expect(fixture.sourceExists || fixture.destinationExists)
        #expect(sink.events.count == 1 && sink.events.first?.outcome == .other)
    }

    @Test(arguments: ["Range", "If-Range"])
    func providerCannotEnablePartialFileRequests(header: String) async throws {
        let provider = FileProvider(fields: [header: "synthetic"]), sink = FileSink()
        let transport = FileTestTransport { request, _ in fileResponse(request) }
        let client = try APIClient(configuration: .init(baseURL: base, authentication: .init(provider: provider), diagnostics: sink), transport: transport)
        await #expect(throws: NetworkError.invalidRequest(.unsupportedRequest)) {
            try await client.download(URLRequest(url: base), maximumBytes: 8)
        }
        #expect(await provider.calls == 1)
        #expect(await transport.calls == 0)
        #expect(sink.events.first?.attemptCount == 0)
    }

}
