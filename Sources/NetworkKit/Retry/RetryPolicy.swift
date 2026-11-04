import Foundation

/// Opt-in replay policy for safe, bodyless reads, selected through NetworkCallOptions.
/// Disabled by default; never enables token refresh or mutating replay.
public enum RetryPolicy: Sendable, Equatable {
    case disabled
    /// At most one additional library attempt for the approved failure allowlist.
    case oneRetryForSafeReads
}

/// Pure decisions only: no transport, sleeping, shared formatter or random state.
internal enum RetryDecision {
    static func validate(_ policy: RetryPolicy, method: HTTPMethod, hasBody: Bool, hasBodyStream: Bool) throws {
        guard policy == .oneRetryForSafeReads else { return }
        guard method == .get || method == .head, !hasBody, !hasBodyStream else {
            throw NetworkError.invalidRequest(.invalidConfiguration)
        }
    }

    static func isEligible(_ failure: NetworkError, accepted: HTTPStatusPolicy) -> Bool {
        switch failure {
        case .httpStatus(let status, _):
            return !accepted.accepts(status) && (status.code == 429 || status.code == 503)
        case .transport(let identity):
            return identity.domain == NSURLErrorDomain &&
                [URLError.networkConnectionLost.rawValue, URLError.cannotConnectToHost.rawValue].contains(identity.code)
        default:
            return false
        }
    }

    /// Caller supplies one jitter sample and remaining monotonic budget. Nil means
    /// preserve the current failure. Interrupted/expired operation arbitration
    /// remains the operation's responsibility, never this pure helper's.
    static func delay(policy: RetryPolicy, attempts: Int, failure: NetworkError,
                      accepted: HTTPStatusPolicy, retryAfterFields: [String],
                      receipt: Date, jitter: TimeInterval, remaining: TimeInterval) -> TimeInterval? {
        guard policy == .oneRetryForSafeReads, attempts == 1,
              isEligible(failure, accepted: accepted), jitter.isFinite,
              (0.25...0.5).contains(jitter), remaining.isFinite, remaining > 0 else { return nil }
        let minimum: TimeInterval
        if case .httpStatus = failure {
            guard let parsed = RetryAfter.minimum(fields: retryAfterFields, receipt: receipt) else { return nil }
            minimum = parsed
        } else {
            minimum = 0
        }
        let wait = max(minimum, jitter)
        guard wait <= 30, wait < remaining else { return nil }
        return wait
    }
}

/// Receives distinct field values before any duplicate normalization. A combined
/// list is rejected by strict date/decimal grammar; HTTP-date commas stay intact.
internal enum RetryAfter {
    static func minimum(fields: [String], receipt: Date) -> TimeInterval? {
        guard receipt.timeIntervalSinceReferenceDate.isFinite else { return nil }
        guard !fields.isEmpty else { return 0 }
        guard fields.count == 1, fields[0].utf8.count <= 128 else { return nil }
        let value = fields[0].trimmingCharacters(in: CharacterSet(charactersIn: " \t"))
        guard !value.isEmpty else { return nil }
        if value.utf8.allSatisfy({ (48...57).contains($0) }) {
            guard let seconds = UInt64(value), seconds <= 30 else { return nil }
            return Double(seconds)
        }
        guard let date = httpDate(value, receipt: receipt) else { return nil }
        let delta = date.timeIntervalSince(receipt)
        guard delta.isFinite else { return nil }
        return max(0, delta)
    }

    private static func httpDate(_ value: String, receipt: Date) -> Date? {
        let formats = ["EEE, dd MMM yyyy HH:mm:ss 'GMT'", "EEEE, dd-MMM-yy HH:mm:ss 'GMT'",
                       "EEE MMM d HH:mm:ss yyyy"]
        let patterns = [
            #"^[A-Z][a-z]{2}, [0-9]{2} [A-Z][a-z]{2} [0-9]{4} [0-9]{2}:[0-9]{2}:[0-9]{2} GMT$"#,
            #"^[A-Z][a-z]+, [0-9]{2}-[A-Z][a-z]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} GMT$"#,
            #"^[A-Z][a-z]{2} [A-Z][a-z]{2} ( [1-9]|[12][0-9]|3[01]) [0-9]{2}:[0-9]{2}:[0-9]{2} [0-9]{4}$"#,
        ]
        for index in formats.indices {
            guard value.range(of: patterns[index], options: .regularExpression) != nil else { continue }
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.isLenient = false
            formatter.dateFormat = formats[index]
            var input = value
            if index == 1 {
                // RFC 9110's rolling 50-year rule; avoid Foundation's fixed pivot.
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = TimeZone(secondsFromGMT: 0)!
                let year = calendar.component(.year, from: receipt)
                let pieces = value.components(separatedBy: "-")
                guard pieces.count == 3, let short = Int(pieces[2].prefix(2)) else { return nil }
                var expanded = (year + 50) / 100 * 100 + short
                if expanded > year + 50 { expanded -= 100 }
                input = pieces[0] + "-" + pieces[1] + "-" + String(expanded) + pieces[2].dropFirst(2)
                formatter.dateFormat = "EEEE, dd-MMM-yyyy HH:mm:ss 'GMT'"
                if let candidate = formatter.date(from: input),
                   let threshold = calendar.date(byAdding: .year, value: 50, to: receipt), candidate > threshold {
                    expanded -= 100
                    input = pieces[0] + "-" + pieces[1] + "-" + String(expanded) + pieces[2].dropFirst(2)
                }
            }
            // asctime uses a space-padded day, whereas DateFormatter emits one digit.
            if index == 2 { input = input.replacingOccurrences(of: "  ", with: " ") }
            guard let date = formatter.date(from: input), formatter.string(from: date) == input else { return nil }
            return date
        }
        return nil
    }
}
