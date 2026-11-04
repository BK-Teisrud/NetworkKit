import Foundation
import Darwin
import os

/// Private deterministic failure seam, never an app storage/plugin boundary.
internal struct DownloadFileOperations: Sendable {
    var preserve: @Sendable (URL, URL) throws -> Void = { source, destination in
        try source.withUnsafeFileSystemRepresentation { sourcePath in
            try destination.withUnsafeFileSystemRepresentation { destinationPath in
                guard let sourcePath, let destinationPath,
                      renamex_np(sourcePath, destinationPath, UInt32(RENAME_EXCL)) == 0 else {
                    // Exclusive same-volume rename only: no overwrite, copy or partial destination.
                    throw DownloadError.fileSystem(.preserve)
                }
            }
        }
    }
    var inspect: @Sendable (URL) throws -> Int64 = { url in
        try url.withUnsafeFileSystemRepresentation { path in
            guard let path else { throw DownloadError.fileSystem(.inspect) }
            let descriptor = Darwin.open(path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK)
            guard descriptor >= 0 else { throw DownloadError.fileSystem(.inspect) }
            defer { _ = Darwin.close(descriptor) }
            var value = stat()
            guard fstat(descriptor, &value) == 0,
                  value.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG), value.st_size >= 0,
                  fchmod(descriptor, mode_t(S_IRUSR | S_IWUSR)) == 0 else {
                throw DownloadError.fileSystem(.inspect)
            }
            return Int64(value.st_size)
        }
    }
    var remove: @Sendable (URL) throws -> Void = { url in
        try url.withUnsafeFileSystemRepresentation { path in
            guard let path else { throw DownloadError.fileSystem(.remove) }
            if unlink(path) != 0 && errno != ENOENT { throw DownloadError.fileSystem(.remove) }
        }
    }
    var destination: @Sendable () -> URL = {
        FileManager.default.temporaryDirectory.appendingPathComponent("NetworkKit-\(UUID().uuidString).download")
    }
}

/// One operation retains candidates through terminal arbitration. Filesystem changes occur
/// only in its child; cleanup/handoff runs only after NetworkOperation has joined that child.
internal final class DownloadFileOwner: Sendable {
    private let candidate = OSAllocatedUnfairLock<URL?>(initialState: nil)
    private let operations: DownloadFileOperations
    init(operations: DownloadFileOperations) { self.operations = operations }

    /// Must occur immediately after a native URL is returned, before cancellation checks.
    func adopt(_ url: URL) { candidate.withLock { $0 = url } }

    func preserve(maximumBytes: Int64) throws -> DownloadedFile {
        guard let source = candidate.withLock({ $0 }), source.isFileURL else {
            throw DownloadError.fileSystem(.preserve)
        }
        let destination = operations.destination()
        do { try operations.preserve(source, destination) }
        catch { throw DownloadError.fileSystem(.preserve) }
        candidate.withLock { $0 = destination }
        let size: Int64
        do { size = try operations.inspect(destination) }
        catch { throw DownloadError.fileSystem(.inspect) }
        guard size >= 0 else { throw DownloadError.fileSystem(.inspect) }
        guard size <= maximumBytes else { throw DownloadError.sizeLimitExceeded }
        return DownloadedFile(url: destination, byteCount: size)
    }

    /// Success is already committed; no new cancellation check or file IO may discard it.
    func handoff() { candidate.withLock { $0 = nil } }

    func cleanup() throws {
        guard let url = candidate.withLock({ $0 }) else { return }
        try operations.remove(url)
        candidate.withLock { $0 = nil }
    }
}
