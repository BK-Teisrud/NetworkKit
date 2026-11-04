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

private final class NativeDiagnosticCounter: NetworkDiagnosticSink {
    private let state = OSAllocatedUnfairLock(initialState: (count: 0, invalid: 0))
    func record(_ event: NetworkDiagnosticEvent) {
        let valid = event.method == .get && event.status?.code == 200 && event.outcome == .success
        state.withLock { $0.count += 1; if !valid { $0.invalid += 1 } }
    }
    var count: Int { state.withLock { $0.count } }
    var invalid: Int { state.withLock { $0.invalid } }
}

private func nativeResidentBytes() throws -> UInt64 {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size)
    let result = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
    }
    guard result == KERN_SUCCESS else { throw NativeFixtureFailure.measurement }
    return UInt64(info.resident_size)
}

extension PublicHTTPSTests {
    @Test
    func nativeLoopbackConcurrentResourceObservations() async throws {
        try await nativeFixture { fixture, base in
            for (path, bytes, concurrency, calls) in [("payload", 65536, 4, 64), ("large", 1048576, 8, 32)] {
                for direct in (bytes == 65536 ? [false, true] : [true, false]) {
                    let diagnostics = NativeDiagnosticCounter()
                    let client = try nativeClient(base, diagnostics: diagnostics)
                    let settings = URLSessionConfiguration.ephemeral
                    settings.httpCookieStorage = nil; settings.httpShouldSetCookies = false
                    settings.urlCredentialStorage = nil; settings.urlCache = nil
                    settings.timeoutIntervalForRequest = 2; settings.timeoutIntervalForResource = 4
                    let session = URLSession(configuration: settings)
                    let before = fixture.count("/" + path)
                    let initial = try nativeResidentBytes()
                    do {
                        func perform(_ index: Int) async throws {
                            let value: Data
                            if direct { value = try await session.data(from: base.appendingPathComponent(path)).0 }
                            else {
                                value = try await nativeSend(index.isMultiple(of: 2) ? .typed : .raw,
                                    client: client, base: base, path: path, response: .data).value
                            }
                            try #require(value.count == bytes && value.allSatisfy { $0 == 120 })
                        }
                        try await perform(0)
                        let warm = try nativeResidentBytes()
                        for offset in stride(from: 0, to: calls, by: concurrency) {
                            try await withThrowingTaskGroup(of: Void.self) { group in
                                for index in offset..<min(offset + concurrency, calls) { group.addTask { try await perform(index) } }
                                try await group.waitForAll()
                            }
                        }
                        let completed = try nativeResidentBytes()
                        await client.shutdown()
                        session.invalidateAndCancel()
                        try await Task.sleep(for: .seconds(6))
                        let settled = try nativeResidentBytes()
                        #expect(fixture.count("/" + path) - before == calls + 1)
                        #expect(diagnostics.count == (direct ? 0 : calls + 1) && diagnostics.invalid == 0)
                        print("NativeLoopback resource mode=\(direct ? "foundation" : "networkkit") bytes=\(bytes) concurrency=\(concurrency) calls=\(calls + 1) rssInitial=\(initial) rssWarm=\(warm) rssCompleted=\(completed) rssAfterOriginalBudget=\(settled) settleSeconds=6")
                    } catch { await client.shutdown(); session.invalidateAndCancel(); throw error }
                }
            }
        }
    }
}

#if os(macOS)
extension PublicHTTPSTests {
    @Test func nativeLoopbackDownloadResourceObservations() async throws {
        try await nativeFixture { fixture, base in
            for (path, bytes) in [("payload", 65536), ("large", 1048576)] {
                for direct in (bytes == 65536 ? [false, true] : [true, false]) {
                    let client = try nativeClient(base)
                    let settings = URLSessionConfiguration.ephemeral
                    settings.httpCookieStorage = nil; settings.httpShouldSetCookies = false
                    settings.httpCookieAcceptPolicy = .never; settings.urlCredentialStorage = nil; settings.urlCache = nil
                    settings.requestCachePolicy = .reloadIgnoringLocalCacheData; settings.timeoutIntervalForRequest = 2
                    let session = URLSession(configuration: settings)
                    let before = fixture.count("/" + path)
                    let initial = try nativeResidentBytes()
                    let maximum = OSAllocatedUnfairLock(initialState: initial)
                    let observedBytes = OSAllocatedUnfairLock<Int64>(initialState: 0)
                    do {
                        func perform() async throws {
                            let url: URL
                            if direct {
                                let request = URLRequest(url: base.appendingPathComponent(path), timeoutInterval: 2)
                                let received = try await session.download(for: request)
                                url = received.0
                                guard (received.1 as? HTTPURLResponse)?.statusCode == 200 else {
                                    try? FileManager.default.removeItem(at: url); throw NativeFixtureFailure.measurement
                                }
                            } else {
                                let received = try await client.download(URLRequest(url: base.appendingPathComponent(path)), maximumBytes: Int64(bytes))
                                url = received.value.url
                                #expect(received.value.byteCount == Int64(bytes))
                            }
                            do {
                                let size = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber
                                try #require(size?.intValue == bytes)
                                observedBytes.withLock { $0 += Int64(bytes) }
                                try FileManager.default.removeItem(at: url)
                            } catch { try? FileManager.default.removeItem(at: url); throw error }
                            let sample = try nativeResidentBytes()
                            maximum.withLock { $0 = max($0, sample) }
                        }
                        try await perform()
                        let warm = try nativeResidentBytes()
                        for _ in 0..<4 {
                            try await withThrowingTaskGroup(of: Void.self) { group in
                                for _ in 0..<4 { group.addTask { try await perform() } }
                                try await group.waitForAll()
                            }
                        }
                        let completed = try nativeResidentBytes()
                        await client.shutdown(); session.invalidateAndCancel()
                        try await Task.sleep(for: .seconds(5))
                        let settled = try nativeResidentBytes()
                        #expect(fixture.count("/" + path) - before == 17)
                        #expect(observedBytes.withLock { $0 } == Int64(bytes * 17))
                        print("NativeLoopback download resource mode=\(direct ? "foundation" : "networkkit") bytes=\(bytes) concurrency=4 calls=17 returnedFileBytes=\(observedBytes.withLock { $0 }) rssInitial=\(initial) rssWarm=\(warm) rssSampledMax=\(maximum.withLock { $0 }) rssCompleted=\(completed) rssAfterBudget=\(settled) settleSeconds=5")
                    } catch { await client.shutdown(); session.invalidateAndCancel(); throw error }
                }
            }
        }
    }
}
#endif
