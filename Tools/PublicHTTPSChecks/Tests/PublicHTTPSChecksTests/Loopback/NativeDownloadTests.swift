import Foundation
import Network
import Testing
#if os(macOS)
@testable import NetworkKit
#else
import NetworkKit
#endif
import os
import Darwin

private func downloadSession(_ ownership: Ownership) -> URLSession? {
    guard ownership == .borrowed else { return nil }
    let settings = URLSessionConfiguration.ephemeral
    settings.httpCookieStorage = nil; settings.httpShouldSetCookies = false
    settings.httpCookieAcceptPolicy = .never; settings.urlCredentialStorage = nil; settings.urlCache = nil
    settings.requestCachePolicy = .reloadIgnoringLocalCacheData
    return URLSession(configuration: settings)
}

extension PublicHTTPSTests {
    @Test(arguments: Ownership.allCases)
    func nativeLoopbackDownloadFiles(ownership: Ownership) async throws {
        try await nativeFixture { fixture, base in
            let session = downloadSession(ownership)
            defer { session?.invalidateAndCancel() }
            let sink = NativeRetryEvents()
            let client = try nativeClient(base, session: session, diagnostics: sink)
            var appOwned: [URL] = []
            do {
                for (path, count) in [("payload", 65536), ("download-empty", 0), ("download-unknown", 65536)] {
                    let result = try await client.download(URLRequest(url: base.appendingPathComponent(path)), maximumBytes: 65536)
                    appOwned.append(result.value.url)
                    #expect(result.status.code == 200 && result.value.byteCount == Int64(count))
                    let size = try FileManager.default.attributesOfItem(atPath: result.value.url.path)[.size] as? NSNumber
                    #expect(size?.intValue == count)
                    #expect(try Data(contentsOf: result.value.url) == Data(repeating: 120, count: count))
                    #expect(fixture.count("/" + path) == 1)
                }
                do {
                    let result = try await client.download(URLRequest(url: base.appendingPathComponent("large")), maximumBytes: 65536)
                    appOwned.append(result.value.url); Issue.record("Oversized native download succeeded")
                } catch DownloadError.sizeLimitExceeded {}
                for (path, code) in [("download-partial", 206), ("status", 503)] {
                    do {
                        let result = try await client.download(URLRequest(url: base.appendingPathComponent(path)), maximumBytes: 65536)
                        appOwned.append(result.value.url); Issue.record("Rejected native status succeeded")
                    } catch NetworkError.httpStatus(let status, _) { #expect(status.code == code) }
                    #expect(fixture.count("/" + path) == 1)
                }
                #expect(fixture.count("/large") == 1)
                await client.shutdown()
                for url in appOwned { #expect(FileManager.default.fileExists(atPath: url.path)) }
                if let session {
                    let (url, response) = try await session.download(from: base.appendingPathComponent("download-empty"))
                    defer { try? FileManager.default.removeItem(at: url) }
                    #expect((response as? HTTPURLResponse)?.statusCode == 200)
                    #expect(fixture.count("/download-empty") == 2)
                }
                #expect(sink.events.count == 6 && sink.events.allSatisfy { $0.attemptCount == 1 })
                print("NativeLoopback download files \(ownership.rawValue): 6 library calls; stored sizes/content/counters and handoff persistence passed")
            } catch {
                await client.shutdown()
                for url in appOwned { try? FileManager.default.removeItem(at: url) }
                throw error
            }
            for url in appOwned { try FileManager.default.removeItem(at: url) }
        }
    }

    @Test(arguments: Ownership.allCases)
    func nativeLoopbackDownloadRedirects(ownership: Ownership) async throws {
        try await nativeFixture { fixture, base in
            let other = try await NativeLoopbackFixture.start()
            do {
                fixture.redirect(to: try other.base.appendingPathComponent("payload"))
                let session = downloadSession(ownership)
                defer { session?.invalidateAndCancel() }
                let client = try nativeClient(base, session: session)
                do {
                    let result = try await client.download(URLRequest(url: base.appendingPathComponent("download-redirect")), maximumBytes: 65536)
                    defer { try? FileManager.default.removeItem(at: result.value.url) }
                    #expect(result.value.byteCount == 65536)
                    #expect(fixture.count("/download-redirect") == 1 && fixture.count("/payload") == 1)
                    do {
                        let unexpected = try await client.download(URLRequest(url: base.appendingPathComponent("cross")), maximumBytes: 65536)
                        try? FileManager.default.removeItem(at: unexpected.value.url)
                        Issue.record("Cross-origin native file redirect succeeded")
                    } catch NetworkError.httpStatus(let status, _) { #expect(status.code == 302) }
                    #expect(other.count("/payload") == 0 && fixture.count("/cross") == 1)
                } catch { await client.shutdown(); throw error }
                await client.shutdown()
                #expect(await other.stop())
                print("NativeLoopback download redirects \(ownership.rawValue): same-origin contacts and denied target zero passed")
            } catch { #expect(await other.stop()); throw error }
        }
    }

    @Test(arguments: Ownership.allCases)
    func nativeLoopbackDownloadCancellation(ownership: Ownership) async throws {
        try await nativeFixture { fixture, base in
            for shutdown in [false, true] {
                let session = downloadSession(ownership)
                defer { session?.invalidateAndCancel() }
                let sink = NativeRetryEvents()
                let client = try nativeClient(base, session: session, diagnostics: sink)
                let before = fixture.downloadWrites
                let task = Task { try await client.download(URLRequest(url: base.appendingPathComponent("download-hold")), maximumBytes: 1048576) }
                do {
                    let written = try await fixture.wroteDownload(after: before)
                    try #require(written, "Fixture must send headers and a partial body before cancellation")
                    if shutdown { await client.shutdown() } else { task.cancel() }
                    do {
                        let unexpected = try await task.value
                        try? FileManager.default.removeItem(at: unexpected.value.url)
                        Issue.record("Expected cancellation of partial native download")
                    } catch is CancellationError {}
                    #expect(sink.events.count == 1 && sink.events.first?.attemptCount == 1)
                    if !shutdown {
                        let next = try await client.download(URLRequest(url: base.appendingPathComponent("download-empty")), maximumBytes: 1)
                        try FileManager.default.removeItem(at: next.value.url)
                    } else {
                        do {
                            let unexpected = try await client.download(URLRequest(url: base.appendingPathComponent("download-empty")), maximumBytes: 1)
                            try? FileManager.default.removeItem(at: unexpected.value.url)
                            Issue.record("Closed client admitted a download")
                        } catch NetworkError.invalidRequest(.clientClosed) {}
                    }
                    await client.shutdown()
                } catch {
                    task.cancel(); _ = await task.result; await client.shutdown(); throw error
                }
            }
            #expect(fixture.downloadWrites == 2 && fixture.count("/download-hold") == 2)
            #expect(fixture.count("/download-empty") == 1)
            print("NativeLoopback download lifecycle \(ownership.rawValue): partial writes, cancellation/shutdown join and admission passed; internal partial-file removal unobserved")
        }
    }
}

#if os(macOS)
extension PublicHTTPSTests {
    @Test(arguments: Ownership.allCases)
    func nativeLoopbackDownloadKnownFileCleanup(ownership: Ownership) async throws {
        try await nativeFixture { fixture, base in
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
            defer { try? FileManager.default.removeItem(at: root) }
            for mode in ["status", "size", "preserve", "inspect", "remove"] {
                let captured = OSAllocatedUnfairLock<URL?>(initialState: nil)
                let destination = root.appendingPathComponent(UUID().uuidString)
                var operations = DownloadFileOperations()
                operations.destination = { destination }
                if mode == "preserve" { operations.preserve = { _, _ in throw DownloadError.fileSystem(.preserve) } }
                if mode == "inspect" { operations.inspect = { _ in throw DownloadError.fileSystem(.inspect) } }
                if mode == "remove" { operations.remove = { _ in throw DownloadError.fileSystem(.remove) } }
                let session = downloadSession(ownership)
                defer { session?.invalidateAndCancel() }
                let work: URLSessionTransport.DownloadOperation = { session, request, delegate in
                    let result = try await session.download(for: request, delegate: delegate)
                    captured.withLock { $0 = result.0 }
                    return result
                }
                let security = NetworkSecurityPolicy(allowInsecureLoopback: true)
                let transport = try session.map { try URLSessionTransport(session: $0, downloadOperation: work, securityPolicy: security, baseURL: base) }
                    ?? URLSessionTransport(downloadOperation: work, securityPolicy: security, baseURL: base)
                let client = try APIClient(configuration: .init(baseURL: base, security: security), transport: transport, downloadFiles: operations)
                let path = mode == "status" || mode == "remove" ? "status" : "payload"
                do {
                    do {
                        let unexpected = try await client.download(URLRequest(url: base.appendingPathComponent(path)), maximumBytes: mode == "size" ? 1 : 65536)
                        try? FileManager.default.removeItem(at: unexpected.value.url)
                        Issue.record("Expected controlled native file failure")
                    } catch NetworkError.httpStatus(let status, _) { #expect(mode == "status" && status.code == 503) }
                    catch let error as DownloadError {
                        let expected: DownloadError = mode == "size" ? .sizeLimitExceeded : mode == "preserve" ? .fileSystem(.preserve)
                            : mode == "inspect" ? .fileSystem(.inspect) : .cleanupFailed(primary: .httpStatus)
                        #expect(error == expected)
                    }
                    let source = try #require(captured.withLock { $0 })
                    if mode == "remove" {
                        #expect(FileManager.default.fileExists(atPath: source.path))
                        try FileManager.default.removeItem(at: source)
                    } else { #expect(!FileManager.default.fileExists(atPath: source.path)) }
                    #expect(!FileManager.default.fileExists(atPath: destination.path))
                } catch {
                    if let source = captured.withLock({ $0 }) { try? FileManager.default.removeItem(at: source) }
                    await client.shutdown(); throw error
                }
                await client.shutdown()
            }
            #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
            #expect(fixture.count("/status") == 2 && fixture.count("/payload") == 3)
            print("NativeLoopback download known-file cleanup \(ownership.rawValue): native source/destination absence and injected refusal verified")
        }
    }
}
#endif
