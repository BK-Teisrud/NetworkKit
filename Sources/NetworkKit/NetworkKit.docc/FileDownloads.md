# Foreground file downloads

Download a complete HTTP 200 response to a temporary file with an explicit output-size limit.

## Ownership and scope

Call `APIClient.download(_:maximumBytes:options:)` on the concrete client with a bodyless GET URLRequest, a positive Int64 maximum and optional ``DownloadOptions``. The result is a ``NetworkResponse`` whose ``DownloadedFile`` exposes the temporary URL and actual stored byte count. Empty HTTP 200 files are allowed. Other statuses, including 206, fail; Range/If-Range requests and request bodies are unsupported.

After successful return, the app owns moving or removing the file. Client shutdown never deletes a handed-off result. Keep the URL private; do not depend on indefinite temporary-file retention. Descriptions omit its path. The app owns retention, post-handoff file-protection/backup suitability and account deletion. No server filename selects a local path.

``NetworkClient`` remains the existing buffered-call boundary; no new requirement is imposed on its conformers. Typed file endpoints, upload, progress events, pause/resume, background/relaunch, queues and download retry are outside this operation.

## Size, timing and cleanup

The required maximum bounds the successfully returned file, measured after transfer; it is not a hard limit on Foundation's transient disk use. The body is not accumulated in a library Data value. Preservation uses an exclusive same-volume rename, with no overwrite or cross-volume copy fallback. File inspection accepts a regular file and restricts permissions to its owner. This is not a secure-erasure, crash-durability or universal resource guarantee.

Download options inherit client defaults: 30-second request inactivity and one original 60-second total budget, configurable per call. Auth preparation, transfer and validation share that budget. Cancellation/shutdown joins the worker and attempts cleanup before return. Filesystem work may delay return past the deadline.

``DownloadError`` reports size and bounded file-operation/cleanup categories. Other request/HTTP/transport/timeouts remain ``NetworkError``; CancellationError remains separate. Cancellation/timeout keep precedence even when removal fails, without a separate cleanup-error channel. Ordinary failure plus failed removal reports a cleanup error with only a primary category. Paths, raw system messages and content are not retained in those errors.

The library attempts removal of files it has actually acquired. Foundation can own internal partial files whose URL is never returned after interruption; their removal cannot be attested by NetworkKit. Filesystem refusal/crash can also leave files. No broad temporary-directory sweep is performed.

## Diagnostics and evidence

The existing optional terminal diagnostic keeps its six-field allowlist. Download file errors map to outcome `other`; no filenames, paths, byte counts, progress or cleanup event stream are added. Library attempt count is zero before invocation or one afterward. There is no automatic download retry.

The implementation has deterministic/file-backed tests, explicit native download and HTTPS probes, finite resource observations and compiled app ownership examples. The repository F4 technical review records actual Mac/simulator coverage and remaining physical-device, workload and privacy-review limits. Technical acceptance and production suitability require separate recorded decisions; API availability does not authorize a tag, release or publication.

## Bundled privacy declaration

The SDK uses fstat only to inspect the preserved temporary download file's type and size, without consuming timestamps or sending metadata to a telemetry service. Apple's required-reason category still covers that API. The bundled manifest declares FileTimestamp / C617.1 for app-container file metadata. This declaration does not authorize arbitrary filesystem inspection or establish the host app's complete privacy/distribution compliance; the app's integrated artifact and practices retain their separate review.

## Compiled app ownership examples

Use `import Foundation` and `import NetworkKit`. These exact blocks compile with an ordinary module import. The client remains reusable and caller-owned; choose the maximum from your actual app workload, rather than copying an arbitrary universal limit. `moveItem` does not overwrite an existing destination. This app policy attempts disposal on failed placement and propagates its error; it cannot guarantee filesystem deletion after refusal or a crash.

<!-- DOC-EXAMPLE: save -->
```swift
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
```

<!-- DOC-EXAMPLE: fileerrors -->
```swift
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
```

## App testing boundary

The library keeps the approved concrete download API and does not add a requirement to NetworkClient. Apps can wrap this operation behind a domain-specific boundary returning their own saved-file value or URL, and supply app-owned fake files in their tests. That avoids exposing a public initializer for SDK-created DownloadedFile or breaking existing buffered mocks. The compiled guide separately tests app placement/disposal with synthetic local files; native transfer success is verified in the explicit native suite.
