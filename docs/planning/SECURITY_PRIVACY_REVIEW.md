# I19 — security and privacy review

Current source-specific update, 2026-11-04: I29 introduced fstat for temporary download-file kind/size inspection. [I31](I31_NATIVE_DOWNLOAD_2026-11-04.md) corrects the bundled FileTimestamp/C617.1 declaration and existing resource test. The dated core analysis below describes its earlier source; original F2 archive/manifest evidence is not rewritten. Final integrated app privacy/security/publication review remains #29/I32 work.

Current gate disposition, 2026-10-31: the owner explicitly approved **only the non-publishing F2 rehearsal** with the documented runtime-retention, call-rate/payload/budget and finite-RSS limitations; see [GATE-F2 resource disposition](F2_REVIEW.md#resource-disposition-for-this-gate). The provisional eight-active-call / expected 1 MiB guidance is not an enforced cap or validated app fit. #29 still requires actual workload/device-memory suitability, security and publication authorization; #132 retains physical Watch evidence. No production suitability or release is approved. Earlier dated statements below preserve their original evidence limits.


Current public-fixture decision, 2026-10-27: the owner selected [HTTPBingo/BadSSL verification](PUBLIC_HTTPS_VERIFICATION.md), NET-01 #115, instead of provisioning a paid/private HTTPS server. Public native observations are allowed for claims they actually support. Earlier controlled-fixture requirements still apply to server-counter/zero-contact claims; minimum/physical/resource/archive/privacy and owner release gates remain. Earlier no-endpoint statements below preserve their historical context.

Date: 2026-10-26. Baseline: main `d79cc031957a1f9690d7f5e5ec9efbdca6c6d9d1` (QA-01), main CI run 40396838559 succeeded. Candidate changes add a bundled privacy manifest, its resource test and this review; no transport behavior or public API is intentionally changed. Acceptance requires candidate PR and merged-main evidence recorded on [#60](https://github.com/BK-Teisrud/SwiftNetworkKit/issues/60).

## Review result and scope

The [threat model](../security/THREAT_MODEL.md) maps T1–T9 to implementation, regression coverage and remaining owners. Reviewed source includes URLInputValidation/RequestURLBuilder/RequestBuilder, NetworkSecurityPolicy/NetworkTaskDelegate/URLSessionTransport, Authentication, NetworkOperation/ClientLifecycle/APIClient, response strategies/codecs/errors and Diagnostics. Existing authentication, security, storage, timing, concurrency and canary tests provide the corresponding regression evidence; source inventory is [tracked separately](TEST_INVENTORY.md).

No severe implementation finding was identified. Keep the existing small immutable values, one transport adapter, scoped lifecycle and sanitized observation boundary. No speculative middleware, extra module, custom trust evaluator, retry engine or secure-storage abstraction is justified. The prior QA review removed stale duplicate validation; this review does not reopen that implementation. This is maintainer review, not penetration testing or independent certification.

## Data and privacy assessment

| Data / capability | SDK behavior | App / release responsibility |
| --- | --- | --- |
| URLs, explicit headers, credentials, bodies, responses | Processed transiently to perform app-selected requests; response values/status/headers deliberately returned. No SDK-controlled destination collects telemetry | App controls purposes, recipients, consent, retention and any collected data declarations; arbitrary app traffic is not declared anonymous by this SDK |
| Provider account/environment and headers | Minimal context to app-owned provider, once per call; safe descriptions/errors; no token store or refresh | App secures provider, credential storage and account isolation |
| Cookies/cache/credentials | Strict automatic storage disabled; explicitly app-managed HTTPS cookies/cache may remain | App declares actual storage/collection, handles deletion; credentials stores remain rejected |
| Diagnostics | Disabled by default; local optional sink gets per-operation random UUID, allowlisted method, status, elapsed duration and outcome only | No stable user/device identifier or SDK transmission. App must assess any sink export, linking and retention |
| Required-reason API use | Direct production source review found no calls to the listed UserDefaults, file-timestamp, disk-space, active-keyboard or system-boot-time APIs. Timing uses Swift ContinuousClock | Reassess source and final artifacts on toolchain/API changes; source search is not a complete binary/transitive API analysis |

The bundled `Sources/NetworkKit/PrivacyInfo.xcprivacy` declares no SDK tracking, tracking domains, SDK-independent collected data or required-reason API entries. Package.swift copies it into the NetworkKit resource bundle. `PrivacyManifestTests.bundledManifestMatchesReviewedSDKPractices` loads that packaged resource and verifies its reviewed keys and values. This does not attest to a consuming app's data practices or App Store acceptance.

Apple describes [privacy manifests](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files) as declarations of data practices and required-reason API use. Review the [current API categories](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype) and [approved reasons](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons) against actual usage. The reviewed system-boot-time list names ProcessInfo.systemUptime and mach_absolute_time; it does not name ContinuousClock. We therefore do not invent an entry/reason from a guessed runtime implementation. This source-level conclusion is provisional until the final consumer/archive report is examined in #64; an observed listed API requires a documented valid purpose and corrected declaration, not a fabricated justification.

Before distribution, #64 must verify resource inclusion in the built consumer/archive and inspect Xcode's aggregate privacy report, including app/transitive/SDK behavior. Compare the report to actual source, resolve discrepancies and retain sanitized evidence. Check current [third-party SDK requirements](https://developer.apple.com/support/third-party-SDK-requirements/) for the chosen distribution format. No binary signing or App Store acceptance claim is made by a SwiftPM resource test.

## Controlled native HTTPS fixture contract

The owner reported no available/known controlled HTTPS environment on 2026-10-26. No external endpoint has been selected and no positive/negative native TLS result is claimed here. ENV-02 from [environment readiness](ENVIRONMENT_READINESS.md) remains an explicit release gap.

Before #62/#63 execute, record a maintainer-controlled, resettable fixture and revision, system-trusted certificate/hostname/validity, synthetic response script, reachable per-target URL and sanitized request counter. No password, token or private key belongs in issues/logs. Certificate ownership and provisioning must be established without purchase, trust-root installation or TLS bypass as a side effect of review. A Mac loopback URL is not a physical device endpoint.

For each required target and both typed/raw public calls, record:

1. Valid hostname, validity period and system-trusted chain: expected status/value/headers succeed under default HTTPS policy.
2. Separate invalid/untrusted chain and hostname-mismatch cases: transport fails with the observed certificate-specific error; no successful payload result. A generic DNS/connectivity failure does not establish trust rejection.
3. Redirect scenarios under HTTPS: same-origin allowed chain; cross-origin/port/downgrade targets record zero requests with synthetic credential markers absent. Do not require logging the markers themselves.
4. A credential challenge other than server trust is refused without automatic credentials. Record native callback behavior separately from existing scripted tests.

Record exact candidate commit, OS/build/architecture, physical versus simulator, toolchain, fixture revision, expected/observed results and cleanup. Never change global ATS/trust or install roots to make a case pass. Invalid-chain and hostname-mismatch conditions must be independently established, not inferred from one failing certificate. Fixture unavailability blocks release evidence, not unrelated local review/resource work.

## Local verification

On the observed macOS 15.8.1 / Xcode 26.3 / Swift 6.2.4 host, `swift test --parallel -Xswiftc -warnings-as-errors` passed 217 tests in 27 suites, including the actual bundled-resource test and existing native loopback probes. The source-integrity command passed package/resource policy, local links, JSON, workflow checks and all four CI-helper tests. The documentation command built the package/tests, emitted symbol graphs and completed DocC conversion with warnings as errors. These are local candidate results, not minimum-OS/physical-device/TLS/distribution evidence. Hosted PR/main outcomes must be linked on #60 before completed closure.

## Open dispositions and forward assessment

| Gap / residual risk | Owner and required disposition |
| --- | --- |
| Controlled HTTPS fixture access and native trust/redirect/challenge results | #62/#63, @BK-Teisrud; access currently unavailable/unknown; ENV-02 evidence required |
| Minimum-runtime and physical-device inventory/execution | #62/#63; exact older environments and device OS/builds remain unverified |
| Buffered-resource and cooperative-callback limits | #61; measure before choosing any bounded corrective work; no new streaming or limiter feature authorized |
| Aggregate manifest/archive/report and distribution compatibility | #64, checked by #86/#29; packaged resource test alone is insufficient |
| Residual-risk acceptance | @BK-Teisrud at #86/#29 must explicitly record accept/reject/mitigation against this review and final evidence; no acceptance inferred from this document or the answer about endpoint access |
| Native fixture stall recurrence | #23/#86 retain the original unresolved internal stall cause and BUG-01 evidence; preserve bounded probes and investigate any recurrence |

Next technical task after I19 acceptance is #61. #62/#63 may resolve access in parallel without depending on each other's runtime results. Existing issues cover every identified gap; no duplicate issue, extra milestone or change to v1/support minima is warranted. F2 remains open, retry-first F3 remains deferred, and no tag/release/publication is authorized. Severe findings must be fixed or affected scope removed through an explicit decision before release. I19 review completion must not close the evidence or residual-acceptance gates.

## I20 resource follow-up

The [measured resource baseline](RESOURCE_BASELINE.md) identifies sustained process-RSS growth relative to a direct URLSession control. RES-01 / #100 now owns attribution and any required fix, blocks #86, and follows I20 acceptance. This is not an attributed leak or accepted stable-memory result. The earlier #61 measurement ownership above is supplemented by this concrete follow-up; residual-risk and native-platform gates remain open.

## RES-01 attribution

The [repeated-call controls](REPEATED_CALL_MEMORY.md) identify expiry-dependent Swift sleep-helper/dispatch retention on the observed macOS runtime. No retained library operation graph requiring a product fix was established. Logical cancellation and runtime allocation lifetime remain distinct. Target resource assessment and explicit owner disposition remain #62/#63/#86/#29 work; local attribution does not waive them or change v1 clocks, timeouts or support.

## TLS-01 native negative evidence

The [macOS rejection regression](NATIVE_TLS_REJECTION.md) exercises typed/raw public calls through real system-trust handling against a disposable untrusted certificate with a matching loopback SAN. Local results are certificate-specific; no trust root or verification bypass is installed. This is owned-session macOS evidence only. #62/#63 still require trusted success, independent hostname mismatch and actual minimum/physical environments; #86/#29 retain resource/risk/release gates. #104 acceptance requires its own PR/main checks.
