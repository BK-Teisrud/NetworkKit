import Foundation

/// Private deterministic inputs; sleep/deadline ownership stays with NetworkClock.
internal struct RetryTiming: Sendable {
    var wallNow: @Sendable () -> Date = { Date() }
    var jitter: @Sendable () -> TimeInterval = { Double.random(in: 0.25...0.5) }
}
