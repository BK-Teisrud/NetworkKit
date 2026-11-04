/// Explicit compatibility contract for an app-owned injected URLSession.
/// The library's owned session always uses strict storage settings.
public enum SessionStorageProfile: Sendable {
    /// No cookie/credential/cache store or automatic cookie handling.
    case strict
    /// App owns HTTPS cookie/cache policy, account isolation, capacity and deletion.
    /// Credential stores, global headers, external delegates and background sessions
    /// remain unsupported. Active stores cannot be used for loopback HTTP;
    /// additional raw origins cannot inherit automatic cookie handling.
    case appManaged
}
