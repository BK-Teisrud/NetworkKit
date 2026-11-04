#if os(macOS)
import Foundation
import Darwin

/// Test-only child process with bounded readiness and teardown; never a product timeout.
final class BoundedFixtureProcess {
    enum Failure: Error, Equatable { case startupTimeout, startupClosed, invalidStartup }
    private let process = Process()
    private let output = Pipe()
    private let exited = DispatchSemaphore(value: 0)
    private(set) var forcedStop = false

    init(script: String, arguments: [String] = []) throws {
        let exited = self.exited
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", "-u", "-c", script] + arguments
        process.standardOutput = output
        // An undrained stderr pipe could itself block a failing child.
        process.standardError = FileHandle.standardError
        process.terminationHandler = { _ in exited.signal() }
        try process.run()
    }

    func startupLine(milliseconds: Int32 = 3000) throws -> String {
        let start = DispatchTime.now().uptimeNanoseconds
        let budget = UInt64(max(milliseconds, 1)) * 1_000_000
        var data = Data()
        while data.count < 128 {
            let elapsed = DispatchTime.now().uptimeNanoseconds - start
            guard elapsed < budget else { _ = stop(); throw Failure.startupTimeout }
            let remaining = Int32(max(1, (budget - elapsed) / 1_000_000))
            var descriptor = pollfd(fd: output.fileHandleForReading.fileDescriptor, events: Int16(POLLIN), revents: 0)
            let ready = Darwin.poll(&descriptor, 1, remaining)
            if ready < 0 && errno == EINTR { continue }
            guard ready > 0 else { _ = stop(); throw Failure.startupTimeout }
            var byte: UInt8 = 0
            let count = Darwin.read(descriptor.fd, &byte, 1)
            if count < 0 && errno == EINTR { continue }
            guard count == 1 else { _ = stop(); throw Failure.startupClosed }
            if byte == 10 { return String(decoding: data, as: UTF8.self) }
            data.append(byte)
        }
        _ = stop()
        throw Failure.invalidStartup
    }

    @discardableResult func stop() -> Bool {
        guard process.isRunning else { return true }
        process.terminate()
        if exited.wait(timeout: .now() + .seconds(1)) == .success { return true }
        // Only this exact owned child's PID is used, while it is still running.
        guard process.isRunning else { return true }
        forcedStop = true
        Darwin.kill(process.processIdentifier, SIGKILL)
        return exited.wait(timeout: .now() + .seconds(1)) == .success
    }

    deinit { _ = stop() }
}
#endif
