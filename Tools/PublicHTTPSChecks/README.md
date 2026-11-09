# Opt-in public HTTPS verification

NET-01 / #115. The owner selected HTTPBingo and BadSSL on 2026-10-27 instead of provisioning a paid/private HTTPS environment. This separate verification package is not a shipped library product or an SDK dependency. Its only package dependency is the local repository. Normal root tests never run these checks.

## Foreground WebSocket verification

The candidate adds separately opt-in suites under `WebSockets/`: public WSS observations, controlled native loopback cases, fixed-frame protocol boundaries and a finite Mac resource profile. None is part of the distributed SDK or selected by automatic CI. The ordinary root regression suite uses deterministic WebSocket doubles and does not contact public WebSocket services.

Execution requires the applicable concrete owner-approved endpoint/scenario/route budget, not just setting an environment variable. The first seven-route cohort is complete and exhausted. The separately approved completion scope is also completed/exhausted and recorded in [the exact plan](../../docs/planning/F5_COMPLETION_VERIFICATION_SCOPE.md); do not reuse old flags or repeat consumed attempts. Public probes remain disabled in this local-only completion phase. Fixed-frame TCP/handshake code is a bounded verification fixture, not a custom production WebSocket stack.

See [progress and retained findings](../../docs/planning/F5_IMPLEMENTATION_PROGRESS.md) for actual passes, failures and pending gates. Simulator, physical, build-only and production evidence remain separate. Resource RSS includes the fixture, test framework, Foundation and allocator; the native control uses immediate invalidation whereas the SDK requests bounded graceful close, so observed differences are not isolated SDK overhead.

## Current F4 candidate

ADR-0017 raises the selected floors to iOS/iPadOS18, macOS15, watchOS11 and tvOS18. Explicit `nativeHTTPSDownload` tests cover fixed small HTTPBingo payload/auth/store cases and BadSSL trust controls, with production 30/60 budgets. These four declarations/seven cases are never selected by automatic CI. The file resource test now compiles on all selected families; actual executed runtime/resource scope is recorded separately, never inferred from a build. No public stress benchmark or real credential is introduced.

## Historical I31 download selection

[I31 Mac evidence](../../docs/planning/I31_NATIVE_DOWNLOAD_2026-11-04.md) adds five explicitly selected native-download declarations / nine cases on Mac; three public scenarios / six ownership cases compile on other hosts, with no execution inference. Mac-only known-path capture uses @testable for private observation without a shipping hook; public-constructor cases use the live URLSession adapter. Historical NET-03 counts below retain their earlier scope.

```sh
swift test --package-path Tools/PublicHTTPSChecks -Xswiftc -warnings-as-errors --filter nativeLoopbackDownload
```

This selection contacts only in-process loopback fixtures, including bounded four-concurrent-call file/RSS observations against a Foundation control. It neither starts public HTTPS cases nor changes signing/trust. Partial files with no exposed URL remain unobserved. Trusted HTTPS/auth/storage, other current/physical environments and actual candidate macOS 14 evidence remain open. The named minimum simulator execution is recorded separately.

## Structure and bounded CI selection

Support/NativeLoopbackFixture.swift contains the bounded fixture and shared test-only helpers. Loopback/ separates core, storage, retry, download and resource responsibilities while preserving the original serialized PublicHTTPSTests suite and its time limit. No new shipped module/product is added. Refresh the checked-in host after source moves with `python3 scripts/ci/sync_device_sources.py`; CI validates membership rather than repairing it.

After `swift build --package-path Tools/PublicHTTPSChecks --build-tests -Xswiftc -warnings-as-errors`, run `python3 scripts/ci/native_loopback.py` to exercise the same bounded CI selection. Full native resource runs remain explicit and make no universal resource guarantee.

## Explicit execution only

On the observed Mac, from the repository root:

```sh
swift test --package-path Tools/PublicHTTPSChecks -Xswiftc -warnings-as-errors
python3 Tools/PublicHTTPSChecks/certificate_witness.py --output /private/tmp/networkkit-public-cert-witness.json
```

For iOS use the existing device-host project with the separate PublicHTTPSChecks scheme. Its test target directly references every Swift source in this package's test directory, including the NET-03 loopback checks. The default NetworkKitDeviceHost scheme still runs only the original regression suite. See [host signing/install/cleanup procedure](../DeviceTestHost/README.md). Existing host/profile authorization remains scoped; create no profile, certificate, registration or trust exception as a side effect. Recheck actual device readiness and compatible existing profile before deployment.

CI builds this package and runs only the four allowlisted local native download declarations (eight owned/borrowed cases) through scripts/ci/native_loopback.py on Mac. Discovery and xUnit results must contain the exact selection, with all eight completion markers; zero/missing/skipped/unexpected evidence fails. Public-service probes and resource measurements remain opt-in. The separate iOS scheme is built unsigned; compilation/discovery is not execution evidence. Source controls retain default-suite membership and require the public target's explicit separate scheme.

## Traffic and privacy

The public-service portion has 14 test declarations / 30 parameter cases: the original eight HTTPS tests and six native lifecycle/cookie tests. Public cases contain fixed small numbers of requests, no loops or automatic rerun/retry. NET-03 adds seven loopback-only declarations / 14 parameter cases, bringing the complete serialized opt-in suite to 21 declarations / 44 cases. The additional finite concurrency/resource loops contact only the in-process fixture, never HTTPBingo or BadSSL. The new cases include isolated positive cookie controls, follow-up requests and app-owned session checks; redirects/system attempts are not an exact wire-count guarantee. A failed certificate classification can add one bounded ordinary Foundation diagnostic request per failed input; up to four extra control requests across the certificate cases. Certificate semantics use the approved production default inactivity 30 / total 60 seconds, with a two-minute outer test guard; other ordinary public calls retain 5/10-second limits, except two calls selecting a 0.25-second total budget. Earlier short-budget failures remain recorded; their cause is unproven. No public load/performance benchmark, bulk payload, credential, real account header, personal query or unattended schedule is selected. The private loopback Foundation controls use only fixed synthetic credentials and isolated ephemeral stores; SDK HTTP calls remain credential-free. Fixed public addresses are HTTPBingo and the three named BadSSL fixtures only.

The redirect echo can contain a client IP: inspect only the expected URL fields in memory, never print/publish/save its body or arbitrary JSON-decoder errors. Logs contain fixed case IDs/input modes/status or numeric error identities. Raw tool logs/xcresults can still contain network/device details and stay private; publish sanitized scalar summaries only. Public services inherently observe the connection and ordinary protocol metadata.

## Evidence boundaries

- JSON success, 204, status 503 before decode, same-origin redirect and total-budget outcome are observations through actual native URLSession/public NetworkKit calls. The budget case does not prove the server received a call before cancellation; timing includes DNS/TLS/network scheduling.
- Valid HTTPS and two rejected certificate fixtures require correct outcomes for both typed/raw calls. The certificate assertion requires direct NSURLErrorDomain untrusted/unknown-root codes, or -1200 plus a same-device default-Foundation control observing the exact expected SecTrust failure/domain and transport code. A generic TLS, DNS, connection, timeout or cancellation failure alone cannot pass.
- Certificate witness captures public server certificates without an HTTP payload, then checks Apple SSL policies locally without adding anchors or changing client trust. Require matching valid/wrong-host leaf, trusted captured chain under the correct hostname, explicit hostname mismatch under the wrong hostname, and untrusted self-signed chain. Certificate rotation/unavailability yields inconclusive failure, not a substituted pass. This witness runs on the Mac; it is not a device peer-certificate trace.
- The optional Foundation corroboration preserves performDefaultHandling and returns no credentials. It records only whether a server-trust callback occurred, numeric SecTrust error and transport code. Only NSURLErrorDomain/-1200 with a server-trust callback, kCFErrorDomainOSStatus and exact errSecNotTrusted/errSecHostNameMismatch plus matching default-Foundation transport failure can satisfy the conditional oracle. It does not classify every -1200 as a certificate failure.
- Public services supply no maintainer-controlled server counters. Denied-destination zero-contact/secret absence, native request/contact timing, cache/challenge scenarios and quantitative resources retain controlled/local or separately observable evidence requirements. Do not infer those claims from a returned status or an echo endpoint.
- Minimum-runtime, other physical-device, transition/resource, archive/privacy-report and owner release gates remain separate. See [NET-01 findings](../../docs/planning/PUBLIC_HTTPS_VERIFICATION.md). Service outages or changed fixtures are evidence problems to investigate; no hidden skip or automatic flaky retry.

Current lifecycle/storage slice: [NET-02 #117](../../docs/planning/NATIVE_LIFECYCLE_STORAGE.md) adds cancellation/reuse, owned/borrowed shutdown and strict cookies with independent Foundation/appManaged parity and deletion controls plus explicit-header positive controls. No ordinary root/CI test starts these public scenarios.

## Explicit local-only selection

```sh
swift test --package-path Tools/PublicHTTPSChecks --filter nativeLoopback
```

This selects only the seven NET-03 declarations and sends no public-service traffic. It does not run the fifteen public declarations. See [NET-03 claims and remaining evidence](../../docs/planning/NET03_NATIVE_LOOPBACK.md). The fixture requires IPv4 loopback binding, bounded header buffering, joined listener/connection cleanup and counted contact. RSS includes test-framework, fixture, Foundation and allocator behavior; it is not isolated SDK ownership or a universal memory cap. Native minimum, physical-family and transition results remain separately recorded.

Storage-control corrections and physical Watch applicability: [NET-04](../../docs/planning/NET04_NATIVE_CONTROLS.md). Matching absent automatic storage is not a successful persistence claim.

## Standalone minimum-macOS consumer

`scripts/verification/NativeHTTPSProbe.swift` is an explicitly selected public-API verification executable for the macOS 14 route, where the approved toolchain cannot run directly. It is separate from this Swift Testing package and its 22 declarations. It does not run through normal root tests or the required PR/main CI workflow; the temporary manual-only macOS 14 workflow builds it with the approved compiler and executes the verified prebuilt binary on the actual older host. It performs ten fixed typed/raw JSON/204/trust cases and uses exact independent Foundation trust corroboration. See [route, opt-in, provenance and retirement limits](../../docs/planning/MACOS14_EXECUTION_ROUTE_2026-10-29.md). No test framework or toolchain is redistributed.

## Explicit retry selection

```sh
swift test --package-path Tools/PublicHTTPSChecks --filter PublicRetryTests
```

I26 adds one declaration with six typed/raw × ownership cases against fixed HTTPBingo 503 responses. It compares disabled/enabled invocation counts, including an isolated synthetic HTTPS cookie and memory-only cache in appManaged mode, owner-session reuse after shutdown and cookie deletion. This is a correctness check, not a public load test; no external wire counter, cache-hit guarantee or device/minimum result is implied. Normal root/CI tests do not execute it. See [native retry evidence](../../docs/planning/NATIVE_RETRY_VERIFICATION.md).

## Explicit portable read-retry counters

```sh
swift test --package-path Tools/PublicHTTPSChecks -Xswiftc -warnings-as-errors --filter nativeLoopbackReadRetryCounters
```

This new local-only declaration has four typed/raw × owned/borrowed cases and contacts only kernel-assigned IPv4 loopback fixtures. Actual iOS/iPadOS 17, tvOS 17 and watchOS 10 simulator results, source hashes and the separately pending macOS 14 route are recorded in [I26 minimum retry evidence](../../docs/planning/I26_MINIMUM_RETRY_2026-11-01.md). The previously documented seven-declaration local selection now includes this eighth declaration; older numbered evidence remains historical. It is not a new physical-device or all-network guarantee.
