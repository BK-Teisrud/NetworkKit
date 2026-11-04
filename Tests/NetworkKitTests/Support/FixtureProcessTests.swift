#if os(macOS)
import Foundation
import Testing

@Suite(.timeLimit(.minutes(1))) struct FixtureProcessTests {
    @Test func missingReadinessFailsAndStopsTheChild() throws {
        let child = try BoundedFixtureProcess(script: "import time; time.sleep(30)")
        defer { #expect(child.stop()) }
        #expect(throws: BoundedFixtureProcess.Failure.startupTimeout) {
            try child.startupLine(milliseconds: 150)
        }
        #expect(child.stop())
    }

    @Test func childIgnoringTerminationIsForceStoppedWithinTheBound() throws {
        let child = try BoundedFixtureProcess(script:
            "import signal,time; signal.signal(signal.SIGTERM, signal.SIG_IGN); print('ready', flush=True); time.sleep(30)")
        defer { #expect(child.stop()) }
        #expect(try child.startupLine() == "ready")
        #expect(child.stop())
        #expect(child.forcedStop)
        #expect(child.stop())
    }
}
#endif
