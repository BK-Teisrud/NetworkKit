import Foundation
import Testing
@testable import NetworkKit

@Suite struct RetryDecisionTests {
    private let receipt = Date(timeIntervalSince1970: 784111777) // Sun, 06 Nov 1994 08:49:37 GMT
    private func status(_ code: Int) throws -> NetworkError {
        .httpStatus(try HTTPStatus(code), headers: HTTPHeaders())
    }

    @Test func methodAndBodyValidation() throws {
        for method in ["GET", "HEAD", "POST", "PUT", "DELETE", "PATCH", "OPTIONS", "get", "CUSTOM"] {
            for body in 0...2 {
                let token = try HTTPMethod(method)
                try RetryDecision.validate(.disabled, method: token, hasBody: body == 1, hasBodyStream: body == 2)
                if ["GET", "HEAD"].contains(method) && body == 0 {
                    try RetryDecision.validate(.oneRetryForSafeReads, method: token, hasBody: body == 1, hasBodyStream: body == 2)
                } else {
                    #expect(throws: NetworkError.invalidRequest(.invalidConfiguration)) {
                        try RetryDecision.validate(.oneRetryForSafeReads, method: token, hasBody: body == 1, hasBodyStream: body == 2)
                    }
                }
            }
        }
    }

    @Test func exactStatusAndDomainAllowlist() throws {
        for code in 100...599 {
            #expect(RetryDecision.isEligible(try status(code), accepted: .successful) == [429, 503].contains(code))
            #expect(!RetryDecision.isEligible(try status(code), accepted: try HTTPStatusPolicy(codes: [code])))
        }
        for domain in [NSURLErrorDomain, "OtherDomain"] {
            for code in [-1001, -1003, -1004, -1005, -1009, -1200, -1202, -999, 0] {
                #expect(RetryDecision.isEligible(.transport(.init(domain: domain, code: code)), accepted: .successful)
                        == (domain == NSURLErrorDomain && [-1004, -1005].contains(code)))
            }
        }
        for failure: NetworkError in [.encoding, .decoding, .timeout(.system), .timeout(.inactivity),
                                     .timeout(.totalBudget), .invalidRequest(.clientClosed),
                                     .invalidRequest(.authenticationProviderFailure), .invalidResponse(.redirectLimitExceeded)] {
            #expect(!RetryDecision.isEligible(failure, accepted: .successful))
        }
    }

    @Test func strictHintsAndAllDateForms() {
        for value in ["Sun, 06 Nov 1994 08:49:38 GMT", "Sunday, 06-Nov-94 08:49:38 GMT", "Sun Nov  6 08:49:38 1994"] {
            #expect(RetryAfter.minimum(fields: [value], receipt: receipt) == 1)
        }
        #expect(RetryAfter.minimum(fields: [], receipt: receipt) == 0)
        #expect(RetryAfter.minimum(fields: ["\t 30 \t"], receipt: receipt) == 30)
        #expect(RetryAfter.minimum(fields: ["Sun, 06 Nov 1994 08:49:00 GMT"], receipt: receipt) == 0)
        #expect(RetryAfter.minimum(fields: ["1", "1"], receipt: receipt) == nil)
        for value in ["", "-1", "+1", "1.0", "NaN", "inf", "31", "1, 2", "18446744073709551616",
                      String(repeating: "0", count: 129), "Sun, 06 Nov 1994 08:49:38 GMT, 1",
                      "Mon, 06 Nov 1994 08:49:38 GMT", "Sun, 31 Feb 1994 08:49:38 GMT",
                      "Sun, 06 Nov 1994 08:49:38 UTC", "Sun, 06 Nov 1994 08:49:38 GMT\n"] {
            #expect(RetryAfter.minimum(fields: [value], receipt: receipt) == nil)
        }
    }

    @Test func rollingObsoleteYear() {
        #expect(RetryAfter.minimum(fields: ["Saturday, 01-Jan-00 00:00:00 GMT"], receipt: receipt)
                == 946684800 - receipt.timeIntervalSince1970)
        // 2094 is more than 50 years ahead of 2026: interpret 94 as 1994.
        let now = Date(timeIntervalSince1970: 1793448000)
        #expect(RetryAfter.minimum(fields: ["Sunday, 06-Nov-94 08:49:38 GMT"], receipt: now) == 0)
    }

    @Test func delayBoundariesAndAttemptLimit() throws {
        let failure = try status(503)
        func delay(_ hint: [String] = [], jitter: Double = 0.25, remaining: Double = 60,
                   attempts: Int = 1, policy: RetryPolicy = .oneRetryForSafeReads) -> Double? {
            RetryDecision.delay(policy: policy, attempts: attempts, failure: failure, accepted: .successful,
                                retryAfterFields: hint, receipt: receipt, jitter: jitter, remaining: remaining)
        }
        #expect(delay() == 0.25)
        #expect(delay(jitter: 0.5) == 0.5)
        #expect(delay(["30"]) == 30)
        #expect(delay(["30"], remaining: 30) == nil)
        #expect(delay(["31"]) == nil)
        #expect(delay(["bad"]) == nil)
        #expect(delay(remaining: 0.25) == nil)
        #expect(delay(remaining: 0.25001) == 0.25)
        for attempts in [-1, 0, 2, 3] { #expect(delay(attempts: attempts) == nil) }
        #expect(delay(policy: .disabled) == nil)
        for jitter in [Double.nan, .infinity, 0, 0.249, 0.501] { #expect(delay(jitter: jitter) == nil) }
        for budget in [Double.nan, .infinity, 0, -1] { #expect(delay(remaining: budget) == nil) }
    }
}
