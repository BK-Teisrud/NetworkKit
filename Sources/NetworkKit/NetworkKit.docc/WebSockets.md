# Foreground WebSockets

The candidate WebSocket API supports foreground connections on iOS/iPadOS, macOS and tvOS. Direct watchOS WebSockets are excluded. Native verification and technical acceptance remain outstanding; this guide does not establish production readiness.

Create a throwing ``WebSocketConfiguration`` with a WSS endpoint and an explicit positive `maximumMessageBytes`, then call ``WebSocketConnection/connect(configuration:)``. The connection owns a fresh session without cookie, credential or cache stores. It accepts no injected session. System trust remains enabled; redirects and automatic credential authentication are rejected.

Receive one raw ``WebSocketMessage`` at a time. Text is measured in UTF-8 bytes. One send and one receive may overlap; duplicate calls of either kind fail. There is no library message stream, reconnect, heartbeat scheduler, subscription protocol or background continuity. The application owns foreground lifetime and any new connection.

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
