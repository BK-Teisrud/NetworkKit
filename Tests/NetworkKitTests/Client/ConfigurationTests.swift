import Foundation
import Testing
import os
@testable import NetworkKit

@Suite struct ConfigurationTests {
    private let baseURL = URL(string: "https://example.invalid/private?token=SECRET")!

    @Test func defaultsAndIndependentOverrides() throws {
        let defaults = NetworkConfiguration(baseURL: baseURL)
        let inherited = try ConfigurationSnapshot(configuration: defaults, options: NetworkCallOptions())
        #expect(inherited.timeouts.inactivity == 30)
        #expect(inherited.timeouts.total == 60)
        let client = NetworkConfiguration(baseURL: baseURL, timeouts: try NetworkTimeouts(inactivity: 50, total: 120))
        let call = try ConfigurationSnapshot(configuration: client, options: NetworkCallOptions(totalTimeout: 10))
        #expect(call.timeouts.inactivity == 50)
        #expect(call.timeouts.total == 10)
        let other = try ConfigurationSnapshot(configuration: client, options: NetworkCallOptions(inactivityTimeout: 2))
        #expect(other.timeouts.inactivity == 2)
        #expect(other.timeouts.total == 120)
        #expect(client.timeouts.total == 120)
    }

    @Test(arguments: [Double.nan, .infinity, -.infinity, 0, -1])
    func invalidLimits(limit: Double) {
        let error = NetworkError.invalidRequest(.invalidConfiguration)
        #expect(throws: error) { try NetworkTimeouts(inactivity: limit) }
        #expect(throws: error) { try NetworkTimeouts(total: limit) }
        #expect(throws: error) { try NetworkCallOptions(inactivityTimeout: limit) }
        #expect(throws: error) { try NetworkCallOptions(totalTimeout: limit) }
    }

    @Test func positiveFiniteLimits() throws {
        for limit in [Double.leastNonzeroMagnitude, 0.001, 1, Double.greatestFiniteMagnitude] {
            let options = try NetworkCallOptions(inactivityTimeout: limit, totalTimeout: limit)
            let snapshot = try ConfigurationSnapshot(configuration: NetworkConfiguration(baseURL: baseURL), options: options)
            #expect(snapshot.timeouts.inactivity == limit)
            #expect(snapshot.timeouts.total == limit)
        }
    }

    @Test func concurrentSnapshotsAreIndependent() async throws {
        var input = ["Authorization": "SECRET", "X-Client": "original"]
        let configuration = NetworkConfiguration(baseURL: baseURL, headers: try HTTPHeaders(input))
        input["X-Client"] = "changed"
        let results = try await withThrowingTaskGroup(of: ConfigurationSnapshot.self) { group in
            for index in 1...100 {
                group.addTask {
                    try ConfigurationSnapshot(configuration: configuration,
                        options: NetworkCallOptions(headers: HTTPHeaders(["x-client": String(index)]), totalTimeout: Double(index)))
                }
            }
            var results: [ConfigurationSnapshot] = []
            for try await snapshot in group { results.append(snapshot) }
            return results
        }
        #expect(results.count == 100)
        #expect(Set(results.compactMap { $0.headers["X-Client"] }).count == 100)
        for result in results {
            #expect(result.baseURL == baseURL)
            #expect(result.headers["authorization"] == "SECRET")
            #expect(result.headers["x-client"] == String(Int(result.timeouts.total)))
            #expect(result.timeouts.inactivity == 30)
        }
        #expect(configuration.headers["x-client"] == "original")
    }

    @Test func descriptionsExcludeConfigurationSecrets() throws {
        let headers = try HTTPHeaders(["Authorization": "SECRET"])
        let configuration = NetworkConfiguration(baseURL: baseURL, headers: headers)
        let options = try NetworkCallOptions(headers: headers)
        for text in [String(describing: configuration), String(reflecting: configuration),
                     String(describing: options), String(reflecting: options)] {
            #expect(!text.contains("SECRET"))
            #expect(!text.contains("example.invalid"))
            #expect(!text.contains("Authorization"))
        }
    }
}

private actor StubTransport: NetworkTransport {
    private(set) var requests: [URLRequest] = []
    let result: TransportResponse
    init(result: TransportResponse) { self.result = result }
    func send(_ request: URLRequest) async throws -> TransportResponse {
        requests.append(request)
        return result
    }
}

/// Small advancement fixture for the seam; OperationBudgetTests covers watchdog races.
private final class AdvancingClock: NetworkClock {
    private struct State: Sendable {
        var instant: ContinuousClock.Instant
        var deadlines: [ContinuousClock.Instant] = []
    }
    private let state: OSAllocatedUnfairLock<State>
    init(start: ContinuousClock.Instant) { state = OSAllocatedUnfairLock(initialState: State(instant: start)) }
    var deadlines: [ContinuousClock.Instant] { state.withLock { $0.deadlines } }
    func now() -> ContinuousClock.Instant { state.withLock { $0.instant } }
    func sleep(until deadline: ContinuousClock.Instant) async throws {
        try Task.checkCancellation()
        state.withLock {
            $0.deadlines.append(deadline)
            if deadline > $0.instant { $0.instant = deadline }
        }
    }
}

@Suite struct ExecutionBoundaryTests {
    @Test func scriptedTransportWithoutNetworking() async throws {
        let url = URL(string: "https://example.invalid")!
        let response = HTTPURLResponse(url: url, statusCode: 201, httpVersion: nil, headerFields: nil)!
        let transport: any NetworkTransport = StubTransport(result: TransportResponse(data: Data([42]), response: response))
        let result = try await transport.send(URLRequest(url: url))
        #expect(result.data == Data([42]))
        #expect((result.response as? HTTPURLResponse)?.statusCode == 201)
        let stub = transport as! StubTransport
        #expect(await stub.requests.count == 1)
    }

    @Test func monotonicDeadlineWithoutWaiting() async throws {
        let start = ContinuousClock().now
        let fake = AdvancingClock(start: start)
        let clock: any NetworkClock = fake
        let deadline = clock.now().advanced(by: .seconds(60))
        try await clock.sleep(until: deadline)
        #expect(clock.now() == deadline)
        try await clock.sleep(until: start)
        #expect(clock.now() == deadline)
        #expect(fake.deadlines == [deadline, start])
    }

    @Test func productionClockCancellation() async throws {
        let clock = ContinuousNetworkClock()
        let sleeper = Task {
            try await clock.sleep(until: clock.now().advanced(by: .seconds(3600)))
        }
        sleeper.cancel()
        do {
            try await sleeper.value
            Issue.record("A cancelled sleep must throw")
        } catch is CancellationError {
            // Expected: cancellation must not be converted to a transport failure.
        }
    }
}
