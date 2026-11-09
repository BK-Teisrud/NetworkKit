#if !os(watchOS)
import Foundation
import Testing
@testable import NetworkKit

private enum WebSocketCallerContext {
    @TaskLocal static var marker: String?
}
private actor WebSocketContextProvider: AuthenticationHeaderProvider {
    private(set) var contexts: [AuthenticationContext] = []
    func headers(for context: AuthenticationContext) async throws -> HTTPHeaders {
        contexts.append(context)
        return try HTTPHeaders(["Authorization": "synthetic-\(context.account ?? "none")",
                                "X-Caller": WebSocketCallerContext.marker ?? "missing"])
    }
}

@Suite(.timeLimit(.minutes(1))) struct WebSocketRaceTests {
    @Test func staleSendCompletionCannotFailTheNextSend() async throws {
        let factory = WebSocketTestFactory(), connection = try await webSocketTestConnection(factory: factory)
        let transport = try await factory.created.value()
        let first = Task { try await connection.send(.text("first")) }; try await transport.sends.wait(1)
        let old = try #require(transport.state.withLock { $0.sendCallback })
        await transport.finishSend(); try await first.value
        let second = Task { try await connection.send(.text("second")) }; try await transport.sends.wait(2)
        await old(.failure(.protocolViolation)) // Await the actor ingestion, not a scheduler guess.
        await transport.finishSend(); try await second.value
        #expect(transport.state.withLock { $0.requests.count } == 2)
        try await connection.close()
    }

    @Test func staleReceiveCompletionCannotReplaceTheNextMessage() async throws {
        let factory = WebSocketTestFactory(), connection = try await webSocketTestConnection(factory: factory)
        let transport = try await factory.created.value()
        let first = Task { try await connection.receive() }; try await transport.receives.wait(1)
        let old = try #require(transport.state.withLock { $0.receiveCallback })
        await transport.finishReceive(.success(.message(.text("first"))))
        #expect(try await first.value == .text("first"))
        let second = Task { try await connection.receive() }; try await transport.receives.wait(2)
        await old(.success(.message(.text("stale"))))
        await transport.finishReceive(.success(.message(.text("second"))))
        #expect(try await second.value == .text("second"))
        try await connection.close()
    }

    @Test func elapsedOpeningAndSendDeadlinesWinOverSuccessfulLateCallbacks() async throws {
        let factory = WebSocketTestFactory(autoOpen: false), clock = BudgetTestClock()
        let opening = Task { try await webSocketTestConnection(factory: factory, clock: clock) }
        let transport = try await factory.created.value(); try await transport.started.value()
        clock.advance(10)
        await transport.events(.opened(selectedProtocol: nil))
        await #expect(throws: WebSocketError.timeout(.connect)) { try await opening.value }

        let secondFactory = WebSocketTestFactory(), secondClock = BudgetTestClock()
        let connection = try await webSocketTestConnection(factory: secondFactory, clock: secondClock)
        let secondTransport = try await secondFactory.created.value()
        let send = Task { try await connection.send(.text("late")) }; try await secondTransport.sends.wait(1)
        secondClock.advance(10)
        await secondTransport.finishSend()
        await #expect(throws: WebSocketError.timeout(.send)) { try await send.value }
    }

    @Test func noLibraryIdleOrTotalLifetimeDeadlineIsAdded() async throws {
        let factory = WebSocketTestFactory(), clock = BudgetTestClock()
        let connection = try await webSocketTestConnection(factory: factory, clock: clock)
        let transport = try await factory.created.value()
        let receive = Task { try await connection.receive() }; try await transport.receives.wait(1)
        clock.advance(86401)
        await transport.finishReceive(.success(.message(.text("still-open"))))
        #expect(try await receive.value == .text("still-open"))
        try await connection.close()
    }

    @Test func aRepeatedCloseCallerCanExpediteAnAlreadyCommittedClose() async throws {
        let factory = WebSocketTestFactory(autoClose: false), connection = try await webSocketTestConnection(factory: factory)
        let transport = try await factory.created.value()
        let first = Task { try await connection.close() }; try await transport.closeStarted.value()
        let repeated = Task { try await connection.close() }
        repeated.cancel()
        try await repeated.value; try await first.value
        #expect(transport.state.withLock { $0.closes.count } == 1)
        #expect(try await connection.receive() == nil)
    }

    @Test func committedLocalCloseIsNotReplacedByTransportFailure() async throws {
        let factory = WebSocketTestFactory(autoClose: false), connection = try await webSocketTestConnection(factory: factory)
        let transport = try await factory.created.value()
        let close = Task { try await connection.close() }; try await transport.closeStarted.value()
        await transport.events(.failed(.transport(.init(domain: NSURLErrorDomain, code: -1202))))
        try await close.value
        #expect(try await connection.receive() == nil)
        #expect(await connection.closeInfo == nil)
    }

    @Test func actorFailureCannotBeOverwrittenByCallerCancellationOrLateData() async throws {
        let factory = WebSocketTestFactory(), connection = try await webSocketTestConnection(factory: factory)
        let transport = try await factory.created.value()
        let receive = Task { try await connection.receive() }; try await transport.receives.wait(1)
        await transport.events(.failed(.protocolViolation))
        receive.cancel()
        await transport.finishReceive(.success(.message(.text("late"))))
        await #expect(throws: WebSocketError.protocolViolation) { try await receive.value }
        await #expect(throws: WebSocketError.protocolViolation) { try await connection.receive() }
    }

    @Test func subprotocolComparisonRejectsUnicodeCanonicalLookalikes() async throws {
        let factory = WebSocketTestFactory(selected: "\u{212A}") // Unicode Kelvin sign compares canonically with K.
        #expect("\u{212A}" == "K")
        await #expect(throws: WebSocketError.subprotocolMismatch) {
            try await webSocketTestConnection(configuration: webSocketTestConfiguration(protocols: ["K"]), factory: factory)
        }
    }

    @Test func explicitProviderBindingIsIsolatedAndInheritsCallerTaskContext() async throws {
        let provider = WebSocketContextProvider(), firstFactory = WebSocketTestFactory(), secondFactory = WebSocketTestFactory()
        let firstConfiguration = try webSocketTestConfiguration(auth: NetworkAuthentication(provider: provider, account: "A"))
        let secondConfiguration = try webSocketTestConfiguration(auth: NetworkAuthentication(provider: provider, account: "B"))
        let connections = try await WebSocketCallerContext.$marker.withValue("synthetic-context") {
            async let a = webSocketTestConnection(configuration: firstConfiguration, factory: firstFactory)
            async let b = webSocketTestConnection(configuration: secondConfiguration, factory: secondFactory)
            return try await (a, b)
        }
        #expect(firstFactory.state.withLock { $0.requests.first?.headers["authorization"] } == "synthetic-A")
        #expect(secondFactory.state.withLock { $0.requests.first?.headers["authorization"] } == "synthetic-B")
        #expect(firstFactory.state.withLock { $0.requests.first?.headers["x-caller"] } == "synthetic-context")
        let contexts = await provider.contexts
        #expect(contexts.count == 2 && Set(contexts.map(\.requestID)).count == 2)
        try await connections.0.close(); try await connections.1.close()
    }

    @Test func cancellationWhileProviderIgnoresItStillPreventsTransportCreation() async throws {
        let release = BudgetLatch(), provider = WebSocketTestProvider(release: release), factory = WebSocketTestFactory()
        let configuration = try webSocketTestConfiguration(auth: NetworkAuthentication(provider: provider))
        let opening = Task { try await webSocketTestConnection(configuration: configuration, factory: factory) }
        await provider.started.wait(); opening.cancel()
        await #expect(throws: CancellationError.self) { try await opening.value }
        await release.open(); await provider.finished.wait()
        #expect(await provider.cancellationObserved)
        #expect(factory.state.withLock { $0.requests.isEmpty })
    }
}
#endif
