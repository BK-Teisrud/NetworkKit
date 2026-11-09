# Foreground WebSockets

The WebSocket API supports foreground connections on iOS/iPadOS, macOS and tvOS. Direct watchOS WebSockets are excluded. The repository technical review and I36 issue track verification/acceptance; this guide does not establish production readiness.

Create a throwing ``WebSocketConfiguration`` with a WSS endpoint and an explicit positive `maximumMessageBytes`, then call ``WebSocketConnection/connect(configuration:)``. The connection owns a fresh session without cookie, credential or cache stores. It accepts no injected session. System trust remains enabled; redirects and automatic credential authentication are rejected.

Receive one raw ``WebSocketMessage`` at a time. Text is measured in UTF-8 bytes. One send and one receive may overlap; duplicate calls of either kind fail. There is no library message stream, reconnect, heartbeat scheduler, subscription protocol or background continuity. The application owns foreground lifetime and any new connection.

## Connection ownership

This compiled example chooses 4 KiB for illustration; it is not a library default or an application workload recommendation. The caller owns the returned connection, awaits `receive()` for each optional text/binary message and closes it when leaving the foreground. A `nil` result means orderly completion. No real server protocol or subscription format is assumed.

<!-- DOC-EXAMPLE: connect -->
```swift
/// This example chooses 4 KiB; the application must select its own message limit.
func openStatusConnection(endpoint: URL,
                          authentication: NetworkAuthentication? = nil) async throws -> WebSocketConnection {
    let configuration = try WebSocketConfiguration(
        endpoint: endpoint, maximumMessageBytes: 4096, authentication: authentication,
        timeouts: WebSocketTimeouts(connect: 10, send: 10, close: 2))
    return try await WebSocketConnection.connect(configuration: configuration)
}
```

## Lifetime and cancellation

An already-cancelled caller has no effect before admission. Cancelling an admitted send or receive terminates the connection. An orderly peer close ends receive with `nil`; repeated receives also return `nil`. Other terminal causes remain errors. Local invalid input does not close a healthy connection.

Explicitly close connections when leaving the foreground. Close is idempotent and uses a bounded grace period before cancellation fallback. Completion does not guarantee peer acknowledgement or immediate operating-system resource reclamation. If the owning application task is already cancelled, run explicit cleanup from an uncancelled task; calling close from the cancelled task itself has no side effect.

<!-- DOC-EXAMPLE: close -->
```swift
func closeFromCancelledOwner(_ connection: WebSocketConnection) async {
    await Task.detached {
        try? await connection.close()
    }.value
}
```

## Limits and authentication

The required message limit bounds accepted application messages, not all native buffering or total process memory. Connect, send and close default to 10, 10 and 2 seconds respectively; explicit finite positive budgets may be at most 24 hours. An idle open connection has no automatic library lifetime deadline.

Optional ``NetworkAuthentication`` is selected explicitly per configuration. Its provider runs once within the connect budget and receives a GET/HTTPS handshake origin for WSS, with the configured account/environment binding. It must cooperate with cancellation: ignored cancellation may retain provider work after logical termination, but a late result must not start a connection. No token storage, refresh or replay is provided.

Do not log raw endpoints, headers, message contents or peer close reasons. Default connection, configuration, message and close-info descriptions redact these values. Structured ``WebSocketError`` values avoid retaining native error userInfo.
