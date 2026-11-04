# ADR-0007: Security, authentication, storage, and network policy in v1

Date: 2026-10-19. Status: Core choices accepted by the owner; related defaults elaborate those choices.
Issue: [DEC-06 / #6](https://github.com/BK-Teisrud/NetworkKit/issues/6).

## Approved choices

The owner selected:

1. No automatic cookie, credential, or HTTP-cache storage by default.
2. An injectable authentication-header provider alongside explicit request headers. The app owns login, token storage, and renewal.
3. HTTPS by default, with an explicit HTTP exception only for localhost/loopback during local development. No TLS bypass or global ATS disabling.

## Decision

[SECURITY_AND_NETWORK_POLICY.md](../planning/SECURITY_AND_NETWORK_POLICY.md) elaborates these choices within the HTTP core and ADR-0005/0006. Owned sessions use ephemeral configuration with stores explicitly disabled; ephemeral alone does not mean no in-memory storage. Apps may deliberately opt into other system storage or inject a compatible session, but the actual storage profile must be explicit and must not be described as the default no-storage profile.

The authentication provider is a small asynchronous, cancellable, Sendable-compatible header boundary. It receives only necessary context and runs within the same total budget. It is not an OAuth, Keychain, or token-refresh module. Preserve URLSession system trust; defer mTLS, pinning, and custom trust policies.

Secure defaults restrict automatic redirects to validated same-origin GET/HEAD calls with a finite hop count. Do not automatically follow cross-origin redirects, HTTPS downgrades, or mutating-request replays. Raw requests do not bypass policy. Logging and error text use a small metadata allowlist and exclude credentials, payloads, and raw URLs by default.

An app-owned session is a trusted injected dependency, not a security sandbox. Check accessible configuration and task-level policy control; reject background sessions and uncontrollable delegate/policy combinations. The library cannot certify arbitrary app code, custom transports, or malicious external sessions.

## Scope and alternatives

Default system storage/cache would simplify some apps, but the owner chose minimal automatic storage. Other system storage requires explicit client/injection choices and app responsibility for isolation/deletion; no custom cache module is introduced.

Manual authentication headers alone would require fewer abstractions. The owner also selected a small provider boundary, explicitly excluding login, refresh, and credential storage.

HTTPS everywhere, including local development, was the alternative to a narrow development exception. The owner selected loopback access. The exception does not cover LAN/private IP networks, .local names, arbitrary hosts, or automatic changes to the host app's ATS policy.

A retry engine, automatic retries on 401/status errors, cache/offline/fallback strategies, telemetry, advanced security, and new transports remain outside v1. URLSession/OS may perform internal connection attempts; no library retry is not a guarantee of one wire event.

## Verification and later gates

Apple documentation was reviewed for ephemeral storage, task-level delegates/redirects, and ATS local networking. Limitations are documented; no implementation, network trial, or security tests have run. Tests are specified for origins, loopback parsing, credential isolation, redirects, storage, redaction, and injection rejection.

At adoption, DEC-07 and the F0 gate remained open. Security review and actual platform/runtime evidence are required before release. This decision is not a security certification.

## Sources

- [Apple: ephemeral](https://developer.apple.com/documentation/foundation/urlsessionconfiguration/ephemeral)
- [Apple: URLSession](https://developer.apple.com/documentation/foundation/urlsession)
- [Apple: task-level redirect](https://developer.apple.com/documentation/foundation/urlsessiontaskdelegate/urlsession%28_%3Atask%3Awillperformhttpredirection%3Anewrequest%3Acompletionhandler%3A%29)
- [Apple: NSAllowsLocalNetworking](https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity/nsallowslocalnetworking)
