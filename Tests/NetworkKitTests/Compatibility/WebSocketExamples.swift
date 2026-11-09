#if !os(watchOS)
import NetworkKit

// DOC-EXAMPLE: close BEGIN
func closeFromCancelledOwner(_ connection: WebSocketConnection) async {
    await Task.detached {
        try? await connection.close()
    }.value
}
// DOC-EXAMPLE: close END
#endif
