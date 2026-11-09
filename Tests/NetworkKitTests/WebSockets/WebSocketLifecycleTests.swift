#if !os(watchOS)
import Foundation
import Testing
@testable import NetworkKit

@Suite(.timeLimit(.minutes(1))) struct WebSocketLifecycleTests {
    @Test func rawMessageGatesAndLocalInvalidInputDoNotCloseHealthyConnection() async throws {
        let factory = WebSocketTestFactory()
        let connection = try await webSocketTestConnection(configuration: webSocketTestConfiguration(maximum: 4), factory: factory)
        let transport = try await factory.created.value()
        await #expect(throws: WebSocketError.messageTooLarge) { try await connection.send(.text("ééa")) }
        #expect(transport.state.withLock { $0.cancellations } == 0)
        let send = Task { try await connection.send(.text("éé")) }
        try await transport.sends.wait(1)
        let receive = Task { try await connection.receive() }
        try await transport.receives.wait(1)
        await #expect(throws: WebSocketError.operationConflict(.send)) { try await connection.send(.binary(Data())) }
        await #expect(throws: WebSocketError.operationConflict(.receive)) { try await connection.receive() }
        await transport.finishReceive(.success(.message(.binary(Data([0, 1, 2, 3])))))
        #expect(try await receive.value == .binary(Data([0, 1, 2, 3])))
        await transport.finishSend()
        try await send.value
        let second = Task { try await connection.send(.binary(Data())) }
        try await transport.sends.wait(2); await transport.finishSend(); try await second.value
        try await connection.close()
        #expect(try await connection.receive() == nil)
        await #expect(throws: WebSocketError.closed) { try await connection.send(.text("a")) }
    }

    @Test func preCancelledCallsDoNotDisturbAdmittedReceive() async throws {
        let factory = WebSocketTestFactory(), connection = try await webSocketTestConnection(factory: factory)
        let transport = try await factory.created.value()
        let pending = Task { try await connection.receive() }; try await transport.receives.wait(1)
        let gate = BudgetLatch()
        let send = Task { await gate.wait(); try await connection.send(.text("a")) }
        let receive = Task { await gate.wait(); return try await connection.receive() }
        let close = Task { await gate.wait(); try await connection.close() }
        send.cancel(); receive.cancel(); close.cancel(); await gate.open()
        await #expect(throws: CancellationError.self) { try await send.value }
        await #expect(throws: CancellationError.self) { try await receive.value }
        await #expect(throws: CancellationError.self) { try await close.value }
        #expect(transport.state.withLock { $0.cancellations } == 0)
        await transport.finishReceive(.success(.message(.text("valid"))))
        #expect(try await pending.value == .text("valid"))
        try await connection.close()
    }

    @Test(arguments: [true, false]) func activeCancellationEndsBothOperations(_ cancelSend: Bool) async throws {
        let factory = WebSocketTestFactory(), connection = try await webSocketTestConnection(factory: factory)
        let transport = try await factory.created.value()
        let send = Task { try await connection.send(.text("a")) }
        let receive = Task { try await connection.receive() }
        try await transport.sends.wait(1); try await transport.receives.wait(1)
        if cancelSend { send.cancel() } else { receive.cancel() }
        await #expect(throws: CancellationError.self) { try await send.value }
        await #expect(throws: CancellationError.self) { try await receive.value }
        await transport.finishSend(); await transport.finishReceive(.success(.message(.text("late"))))
        await #expect(throws: CancellationError.self) { try await connection.receive() }
        #expect(transport.state.withLock { $0.cancellations } >= 1)
        try await connection.close()
    }

    @Test func sendTimeoutIsSharedAndCannotBeReplacedByLateError() async throws {
        let factory = WebSocketTestFactory(), clock = BudgetTestClock()
        let connection = try await webSocketTestConnection(factory: factory, clock: clock)
        let transport = try await factory.created.value()
        let send = Task { try await connection.send(.text("a")) }
        let receive = Task { try await connection.receive() }
        try await transport.sends.wait(1); try await transport.receives.wait(1)
        clock.advance(11)
        await #expect(throws: WebSocketError.timeout(.send)) { try await send.value }
        await #expect(throws: WebSocketError.timeout(.send)) { try await receive.value }
        await transport.events(.failed(.handshakeRejected))
        await transport.finishSend(); await transport.finishReceive(.success(.message(.text("late"))))
        await #expect(throws: WebSocketError.timeout(.send)) { try await connection.send(.text("a")) }
    }

    @Test func incomingOversizeTerminatesAndNativeFailureIdentityIsPreserved() async throws {
        let factory = WebSocketTestFactory(), connection = try await webSocketTestConnection(configuration: webSocketTestConfiguration(maximum: 4), factory: factory)
        let transport = try await factory.created.value()
        let receive = Task { try await connection.receive() }; try await transport.receives.wait(1)
        await transport.finishReceive(.success(.message(.text("ééa"))))
        await #expect(throws: WebSocketError.messageTooLarge) { try await receive.value }
        await #expect(throws: WebSocketError.messageTooLarge) { try await connection.receive() }
        try await connection.close()

        let secondFactory = WebSocketTestFactory(), second = try await webSocketTestConnection(factory: secondFactory)
        let secondTransport = try await secondFactory.created.value()
        let pending = Task { try await second.receive() }; try await secondTransport.receives.wait(1)
        let error = WebSocketError.transport(.init(domain: NSURLErrorDomain, code: -1202))
        await secondTransport.finishReceive(.failure(error))
        await #expect(throws: error) { try await pending.value }
        await #expect(throws: error) { try await second.receive() }
    }

    @Test(arguments: [UInt16?.none, UInt16?(1000), UInt16?(1001)])
    func orderlyPeerCloseEndsAndSnapshotsMetadata(_ code: UInt16?) async throws {
        let factory = WebSocketTestFactory(), connection = try await webSocketTestConnection(factory: factory)
        let transport = try await factory.created.value()
        let pending = Task { try await connection.receive() }; try await transport.receives.wait(1)
        let info = WebSocketCloseInfo(code: code, reason: "synthetic")
        await transport.peer(info)
        #expect(try await pending.value == nil)
        #expect(try await connection.receive() == nil)
        #expect(await connection.closeInfo == info)
        await transport.peer(WebSocketCloseInfo(code: 4001, reason: "late"))
        #expect(await connection.closeInfo == info)
        await #expect(throws: WebSocketError.closed) { try await connection.send(.text("a")) }
    }

    @Test func applicationCloseIsStructuredFailureAndRepeatedCloseDoesNotEraseIt() async throws {
        let factory = WebSocketTestFactory(), connection = try await webSocketTestConnection(factory: factory)
        let transport = try await factory.created.value()
        let pending = Task { try await connection.receive() }; try await transport.receives.wait(1)
        await transport.peer(WebSocketCloseInfo(code: 4001, reason: "synthetic"))
        await #expect(throws: WebSocketError.peerClosed(code: 4001)) { try await pending.value }
        try await connection.close(); try await connection.close()
        await #expect(throws: WebSocketError.peerClosed(code: 4001)) { try await connection.receive() }
    }

    @Test func closeFallbackIsBoundedIdempotentAndHasNoPeerAckPromise() async throws {
        let factory = WebSocketTestFactory(autoClose: false), clock = BudgetTestClock()
        let connection = try await webSocketTestConnection(factory: factory, clock: clock)
        let transport = try await factory.created.value()
        await #expect(throws: WebSocketError.invalidInput(.invalidCloseReason)) {
            try await connection.close(reason: String(repeating: "a", count: 124))
        }
        let receive = Task { try await connection.receive() }; try await transport.receives.wait(1)
        let close = Task { try await connection.close(code: .goingAway, reason: "done") }
        try await transport.closeStarted.value()
        #expect(try await receive.value == nil)
        clock.advance(3)
        try await close.value; try await connection.close()
        #expect(transport.state.withLock { $0.closes.count } == 1)
        #expect(await connection.closeInfo == nil)
    }

    @Test func cancellationDuringClosingExpeditesWithoutReplacingLocalEnd() async throws {
        let factory = WebSocketTestFactory(autoClose: false), connection = try await webSocketTestConnection(factory: factory)
        let transport = try await factory.created.value()
        let close = Task { try await connection.close() }; try await transport.closeStarted.value()
        close.cancel(); try await close.value
        #expect(try await connection.receive() == nil)
        #expect(transport.state.withLock { $0.cancellations } >= 1)
    }

    @Test(arguments: [String?.none, String?("wrong")])
    func requiredSubprotocolCannotBeOmittedOrChanged(_ selected: String?) async throws {
        let factory = WebSocketTestFactory(selected: selected)
        await #expect(throws: WebSocketError.subprotocolMismatch) {
            try await webSocketTestConnection(configuration: webSocketTestConfiguration(protocols: ["expected"]), factory: factory)
        }
        #expect(factory.state.withLock { $0.transports.first?.state.withLock { $0.cancellations } } == 1)
    }

    @Test func unexpectedProtocolAndHandshakeRejectionNeverReturnAHandle() async throws {
        await #expect(throws: WebSocketError.subprotocolMismatch) {
            try await webSocketTestConnection(factory: WebSocketTestFactory(selected: "unexpected"))
        }
        let factory = WebSocketTestFactory(autoOpen: false)
        let pending = Task { try await webSocketTestConnection(factory: factory) }
        let transport = try await factory.created.value()
        await transport.events(.failed(.handshakeRejected))
        await #expect(throws: WebSocketError.handshakeRejected) { try await pending.value }
    }

    @Test func openingBudgetIsNotResetAfterProviderReturns() async throws {
        let release = BudgetLatch(), provider = WebSocketTestProvider(release: release)
        let clock = BudgetTestClock(), factory = WebSocketTestFactory(autoOpen: false)
        let config = try webSocketTestConfiguration(auth: NetworkAuthentication(provider: provider))
        let opening = Task { try await webSocketTestConnection(configuration: config, factory: factory, clock: clock) }
        await provider.started.wait(); clock.advance(9); await release.open()
        let transport = try await factory.created.value(); try await transport.started.value()
        clock.advance(2)
        await #expect(throws: WebSocketError.timeout(.connect)) { try await opening.value }
        await transport.events(.opened(selectedProtocol: nil))
        #expect(factory.state.withLock { $0.requests.count } == 1)
    }

    @Test func noncooperativeLateProviderCannotStartNetworkAfterDeadline() async throws {
        let release = BudgetLatch(), provider = WebSocketTestProvider(release: release)
        let clock = BudgetTestClock(), factory = WebSocketTestFactory()
        let config = try webSocketTestConfiguration(auth: NetworkAuthentication(provider: provider))
        let opening = Task { try await webSocketTestConnection(configuration: config, factory: factory, clock: clock) }
        await provider.started.wait(); clock.advance(11)
        await #expect(throws: WebSocketError.timeout(.connect)) { try await opening.value }
        #expect(factory.state.withLock { $0.requests.isEmpty })
        await release.open(); await provider.finished.wait()
        #expect(await provider.cancellationObserved)
        #expect(factory.state.withLock { $0.requests.isEmpty })
    }

    @Test func authenticationIsOnceBoundToHTTPSHandshakeAndConflictsFailBeforeFactory() async throws {
        let provider = WebSocketTestProvider(supplied: try HTTPHeaders(["Authorization": "synthetic-A"]))
        let factory = WebSocketTestFactory(selected: "expected")
        let config = try webSocketTestConfiguration(auth: NetworkAuthentication(provider: provider, account: "A", environment: "test"), protocols: ["expected"])
        let connection = try await webSocketTestConnection(configuration: config, factory: factory)
        let contexts = await provider.contexts
        #expect(contexts.count == 1)
        #expect(contexts.first?.origin.scheme == "https")
        #expect(contexts.first?.origin.port == 8443)
        #expect(contexts.first?.method == .get && contexts.first?.account == "A")
        #expect(factory.state.withLock { $0.requests.first?.headers["authorization"] } == "synthetic-A")
        #expect(await connection.selectedSubprotocol == "expected")
        try await connection.close()
        #expect(await provider.contexts.count == 1)
        for fields in [["Authorization": "synthetic-B"], ["Host": "forbidden"]] {
            let failing = WebSocketTestProvider(supplied: try HTTPHeaders(fields)), unused = WebSocketTestFactory()
            let configuration = try webSocketTestConfiguration(auth: NetworkAuthentication(provider: failing), headers: HTTPHeaders(["Authorization": "synthetic-A"]))
            await #expect(throws: (any Error).self) { try await webSocketTestConnection(configuration: configuration, factory: unused) }
            #expect(unused.state.withLock { $0.requests.isEmpty })
        }
    }

    @Test func providerErrorsAreSanitizedAndPreCancelledOpeningHasNoProviderCall() async throws {
        let provider = WebSocketTestProvider(failure: NSError(domain: "SECRET", code: 1, userInfo: [NSLocalizedDescriptionKey: "TOKEN"]))
        let config = try webSocketTestConfiguration(auth: NetworkAuthentication(provider: provider))
        await #expect(throws: WebSocketError.authenticationFailed) { try await webSocketTestConnection(configuration: config) }
        let unused = WebSocketTestProvider(), gate = BudgetLatch()
        let cancelled = Task {
            await gate.wait()
            return try await webSocketTestConnection(configuration: webSocketTestConfiguration(auth: NetworkAuthentication(provider: unused)))
        }
        cancelled.cancel(); await gate.open()
        await #expect(throws: CancellationError.self) { try await cancelled.value }
        #expect(await unused.contexts.isEmpty)
    }
}
#endif
