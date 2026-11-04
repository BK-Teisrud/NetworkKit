import Foundation
import NetworkKit
import Testing

// DOC-EXAMPLE: save BEGIN
/// The caller reuses/owns the client and chooses a private permanent destination.
func guideSaveDownload(client: APIClient, request: URLRequest, maximumBytes: Int64,
                       destination: URL) async throws -> NetworkResponse<URL> {
    let response = try await client.download(request, maximumBytes: maximumBytes)
    let saved = try guideMoveOwnedFile(response.value.url, to: destination)
    return NetworkResponse(value: saved, status: response.status, headers: response.headers)
}

/// App policy: dispose the handed-off temporary file if permanent placement fails.
func guideMoveOwnedFile(_ temporary: URL, to destination: URL) throws -> URL {
    do {
        try FileManager.default.moveItem(at: temporary, to: destination)
        return destination
    } catch {
        try? FileManager.default.removeItem(at: temporary)
        throw error
    }
}
// DOC-EXAMPLE: save END

// DOC-EXAMPLE: fileerrors BEGIN
/// Fixed categories only; do not publish file URLs or raw filesystem errors.
func guideDownloadFailureCategory(_ error: any Error) -> String {
    switch error {
    case is CancellationError: "cancelled"
    case DownloadError.sizeLimitExceeded: "file-too-large"
    case DownloadError.fileSystem: "file-operation"
    case DownloadError.cleanupFailed: "cleanup"
    case is NetworkError: "network"
    default: "unexpected"
    }
}
// DOC-EXAMPLE: fileerrors END

@Suite struct FileDownloadExamplesTests {
    @Test func appOwnershipExampleMovesOrDisposesWithoutOverwriting() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let temporary = root.appendingPathComponent("temporary")
        let destination = root.appendingPathComponent("saved")
        try Data("synthetic".utf8).write(to: temporary)
        #expect(try guideMoveOwnedFile(temporary, to: destination) == destination)
        #expect(!FileManager.default.fileExists(atPath: temporary.path))
        try Data("second".utf8).write(to: temporary)
        #expect(throws: (any Error).self) { try guideMoveOwnedFile(temporary, to: destination) }
        #expect(!FileManager.default.fileExists(atPath: temporary.path))
        #expect(try Data(contentsOf: destination) == Data("synthetic".utf8))
    }

    @Test func publicDownloadExampleCompilesAndRejectsInvalidLimitWithoutContact() async throws {
        let base = URL(string: "https://example.invalid")!
        let client = try APIClient(configuration: .init(baseURL: base))
        do {
            await #expect(throws: NetworkError.invalidRequest(.invalidConfiguration)) {
                try await guideSaveDownload(client: client, request: URLRequest(url: base), maximumBytes: 0,
                                            destination: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
            }
            await client.shutdown()
        }
        let errors: [any Error] = [CancellationError(), DownloadError.sizeLimitExceeded,
            DownloadError.fileSystem(.preserve), DownloadError.fileSystem(.inspect), DownloadError.fileSystem(.remove),
            DownloadError.cleanupFailed(primary: .httpStatus), NetworkError.decoding, URLError(.unknown)]
        #expect(errors.map(guideDownloadFailureCategory) == ["cancelled", "file-too-large", "file-operation", "file-operation",
            "file-operation", "cleanup", "network", "unexpected"])
    }
}
