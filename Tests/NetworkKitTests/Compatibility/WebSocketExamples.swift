#if !os(watchOS)
import Foundation
import NetworkKit

// DOC-EXAMPLE: connect BEGIN
/// This example chooses 4 KiB; the application must select its own message limit.
func openStatusConnection(endpoint: URL,
                          authentication: NetworkAuthentication? = nil) async throws -> WebSocketConnection {
    let configuration = try WebSocketConfiguration(
        endpoint: endpoint, maximumMessageBytes: 4096, authentication: authentication,
        timeouts: WebSocketTimeouts(connect: 10, send: 10, close: 2))
    return try await WebSocketConnection.connect(configuration: configuration)
}
// DOC-EXAMPLE: connect END

// DOC-EXAMPLE: close BEGIN
func closeFromCancelledOwner(_ connection: WebSocketConnection) async {
    await Task.detached {
        try? await connection.close()
    }.value
}
// DOC-EXAMPLE: close END
#endif
