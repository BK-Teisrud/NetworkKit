# F1 HTTP core verification

I11 / [#52](https://github.com/BK-Teisrud/NetworkKit/issues/52), reviewed 2026-10-21.
This report verifies the initial HTTP slice against the approved F1 boundary. The final
I11 PR, commit hashes, actual hosted test counts and phase-transition outcome are recorded
on #52 after its PR and main checks pass. F1 acceptance does not authorize a release or
claim complete v1 production readiness.

## Delivery audit

All I01–I10 issues are closed with completed acceptance evidence. The following PRs
were read back from GitHub as merged; I06 has separate bootstrap/enforcement PRs.

| Task | Delivered behavior | Merged PR | Merge revision |
| --- | --- | --- | --- |
| [I01 / #42](https://github.com/BK-Teisrud/NetworkKit/issues/42) | Package/product/targets | [#67](https://github.com/BK-Teisrud/NetworkKit/pull/67) | `c9bcac3d2e0c` |
| [I02 / #43](https://github.com/BK-Teisrud/NetworkKit/issues/43) | HTTP values and structured errors | [#68](https://github.com/BK-Teisrud/NetworkKit/pull/68) | `194024399cc7` |
| [I03 / #44](https://github.com/BK-Teisrud/NetworkKit/issues/44) | Immutable configuration and internal seams | [#69](https://github.com/BK-Teisrud/NetworkKit/pull/69) | `235da22aeb8b` |
| [I04 / #45](https://github.com/BK-Teisrud/NetworkKit/issues/45) | Endpoint and safe URL construction | [#70](https://github.com/BK-Teisrud/NetworkKit/pull/70) | `fcc684d8ac6b` |
| [I05 / #46](https://github.com/BK-Teisrud/NetworkKit/issues/46) | Buffered bodies and header precedence | [#71](https://github.com/BK-Teisrud/NetworkKit/pull/71) | `dc3688cc4e4c` |
| [I06 / #47](https://github.com/BK-Teisrud/NetworkKit/issues/47) | Real platform CI and enforced quality-gate | [#72](https://github.com/BK-Teisrud/NetworkKit/pull/72) | `fe47c58da976` |
| [I06 / #47](https://github.com/BK-Teisrud/NetworkKit/issues/47) | Required-check negative control and enforcement | [#73](https://github.com/BK-Teisrud/NetworkKit/pull/73) | `e2c85b583c0c` |
| [I07 / #48](https://github.com/BK-Teisrud/NetworkKit/issues/48) | Response strategies and status policy | [#74](https://github.com/BK-Teisrud/NetworkKit/pull/74) | `43739acff880` |
| [I08 / #49](https://github.com/BK-Teisrud/NetworkKit/issues/49) | Owned/borrowed session transport | [#75](https://github.com/BK-Teisrud/NetworkKit/pull/75) | `d29272d97349` |
| [I09 / #50](https://github.com/BK-Teisrud/NetworkKit/issues/50) | HTTPS/origin/loopback/redirect/trust policy | [#76](https://github.com/BK-Teisrud/NetworkKit/pull/76) | `00f648d525a4` |
| [I10 / #51](https://github.com/BK-Teisrud/NetworkKit/issues/51) | Shared public typed/raw pipeline | [#77](https://github.com/BK-Teisrud/NetworkKit/pull/77) | `a09605739b92` |

I01–I05 predate hosted CI. Their original local checks are not retroactively described
as four-platform PR checks. Their cumulative behavior is exercised by I06 onward and
by the I10/F1 suites. [I10 PR run 39650778950](https://github.com/BK-Teisrud/NetworkKit/actions/runs/39650778950)
and [main run 39652280325](https://github.com/BK-Teisrud/NetworkKit/actions/runs/39652280325)
passed all seven jobs; each log records 135 test functions / 18 suites on five runtimes.
The baseline reviewed here is `a09605739b92e53954b4ce4f3a6fb9b1825af8ce`.

## Contract-to-test review

Test names below identify executable assertions, not a coverage-percentage target.
Existing detailed task guides retain their dated evidence.

| F1 contract and traceability | Executable evidence | Assessment |
| --- | --- | --- |
| Package NetworkKit, product/import NetworkKit, one module, no dependencies, Swift 6 / tools 6.2; #27 / I01 | source-integrity manifest checks; public consumer tests; generic platform builds | Delivered; later API/resource/release reviews remain open |
| Methods, buffered JSON/Data/text bodies, header precedence; #8 / ADR-0005 | RequestEncodingTests; F1AcceptanceTests.typedAndRawPOSTHaveRequestAndResponseParity | Delivered; no stream/multipart/transfer/interceptor API |
| Safe base/path/query construction; #9 / ADR-0005 | EndpointURLTests; ordered repeated/nil/empty query in the F1 POST parity test | Delivered; no automatic API versioning |
| JSON/Data/strict UTF-8/explicit empty responses and metadata; #10 / ADR-0005 | ResponseDecodingTests; HTTPPipelineTests; F1AcceptanceTests.invalidUTF8IsDecodingFailureForBothInputs | Delivered; no streaming or custom format framework |
| Status before decoding, explicit status replacements, structured redacted errors; #11 / ADR-0005 | HTTPPipelineTests status/transport tests; F1AcceptanceTests.HTTPFailurePrecedesDecoderWithoutRetry and encodingFailureDoesNotSendOrPoisonClient | Delivered for current pipeline; complete terminal-cause arbitration remains I12/I13 |
| Immutable client/call defaults and owned/borrowed injection; #22 / ADR-0006 | ConfigurationTests; SessionTransportTests; PublicResponseAPITests; F1 POST parity test | Delivered foundation; strict public injection only; remaining storage/lifecycle review in F2 |
| HTTPS/system trust and origin boundaries; #25 / ADR-0007 | NetworkSecurityTests; RedirectIntegrationTests; F1AcceptanceTests.extraRawOriginDropsDefaultsAndDeniedOriginDoesNotSend and loopbackCredentialsFailBeforeTransport | Delivered initial policy; full TLS/device/privacy review remains F2 |
| Deterministic tests and actual CI enforcement; #23 / ADR-0008 | CI driver/helper tests; I06 negative control; current required quality-gate; public client and native/scripted integration tests | Delivered F1 verification infrastructure; full timing/race/device matrix remains F2 |

The six new F1AcceptanceTests functions cover complete client calls with a recording
internal transport. They check exact POST body/method/URL/query/header/timeout parity
and equal response values/metadata; encoding failure with zero sends and later recovery;
503 rejected before a forbidden custom decoder with one send; invalid UTF-8 errors on
both inputs; raw extra-origin default-header isolation and denied-origin zero sends;
and loopback credential rejection before transport on both inputs. These are scripted
client contracts, not new native networking evidence. No production implementation,
public API, dependency, workflow or ruleset is changed by I11.

## Platform and verification boundaries

The cumulative baseline uses standard macos-15 arm64, image 20260907.0337.1, macOS 15.7.9,
Xcode 26.3 / 17C529, Swift 6.2.4 and SDKs 26.2. Executed destinations are macOS plus
iPhone 17, iPad (A16), Apple Watch Series 11 (42mm) and Apple TV 4K (3rd generation),
simulators OS 26.2. Exact UUIDs/environment details are in each CI log.

Local I11 verification passed **141 test functions / 19 suites**, Swift warnings as
errors, on macOS 15.8.1 x86_64 with the same Xcode/Swift baseline. The I11 PR and main
must each pass source integrity (including three helper tests), four generic platform
build/test jobs, DocC and quality-gate; actual five-runtime counts are recorded on #52.
No documentation-only matrix bypass is used. The existing I06 negative-control evidence
is retained; no destructive experiment or rule change is needed to repeat it here.

Native URLSession/URLProtocol integration is covered on macOS/iOS/tvOS. watchOS cannot
intercept with URLProtocol, so those scenarios use the explicitly injected internal I/O
seam. Real redirect integration uses macOS loopback servers; other platforms invoke the
actual delegate callback with scripted I/O. No public host, real token or external test
service is used. Trust challenge disposition tests do not prove a complete native TLS
matrix, certificate rejection behavior on physical devices, or real watch traffic.

Deployment targets 17/14/10/17 are compiled requirements, not proof of running on those
minimums. Newer simulator/host results do not replace I21/I22 evidence. The bounded SDK
checks and actual builds remain distinct from minimum-runtime behavioral verification.

## Findings, deviations and retained v1 work

The initial client is consistent with the selected F1 behavior. No product-scope change
or new F3–F6 feature is introduced. The following boundaries remain explicit:

| Boundary / finding | Resolution and follow-up |
| --- | --- |
| POST/encoding failure and origin security had separate component coverage; the gate needs full-client assertions | Six gate-level regression functions added in this PR |
| Current scope/platform/readiness summaries still said the public client was unimplemented | Current summaries corrected; dated historical evidence remains identified as historical |
| Early tasks did not have four-platform PR CI | Record their original local evidence honestly; use the cumulative real CI suites for gate acceptance |
| watchOS URLProtocol interception unavailable; native redirect harness limited to macOS | Existing test-infrastructure adaptation retained and disclosed; real device/native TLS evidence remains I19/I22 |
| 30-second inactivity is applied; stored 60-second total budget has no watchdog yet | I12 / #53 must enforce total time, cancellation causes, no late success and cleanup, including numeric extremes; no full timeout claim in F1 |
| No complete active-operation shutdown/race registry | I13 / #54; owned versus borrowed cleanup remains mandatory |
| Strict public borrowed-session profile; app-managed profile is internal | I16 / #57 reviews public compatibility and storage guarantees |
| Header provider and optional privacy-safe diagnostics not implemented | I14 / #55 and I15 / #56; no retry/refresh/OAuth/Keychain module implied |
| Full API/availability, security/privacy, resources, minimum OS and physical proof still required | I17–I23 / #58–64 and REL-01 / #29 remain open |

These are recorded phase boundaries and the existing infrastructure adaptation, not
waivers of the accepted v1 requirements. No missing F2 contract is marked delivered.

## Phase transition and epic accounting

The F1 gate covers the concrete I01–I11 tasks. Domain epics span phases and stay open
until all selected requirements have final evidence. On successful #52 acceptance,
the six remaining open F1 domain epics move to F2 for their remaining selected work:

| Epic | F1 evidence | Remaining F2 delivery/review |
| --- | --- | --- |
| #8 HTTP and requests | I05/I10; POST and raw parity | I12/I13 timing/lifecycle, I18/I19 final API/security |
| #9 Endpoints and URL construction | I04 and client parity | I18 API/availability and I21/I22 runtime evidence |
| #10 Responses and data handling | I07/I10 response and gate tests | I12 cancellation checkpoints, I18 final API and I21/I22 runtime evidence |
| #11 Error handling | I02/I07/I10 and error parity | I12/I13 terminal causes, I15 diagnostics, I19 review |
| #22 Configuration | I03/I08/I10 and precedence tests | I12/I13 limits/lifecycle, I16 storage profiles, I18 review |
| #23 Testing and mocking | I06/I11 and current suites | I17 consolidated matrix, I21/I22 runtime/device evidence |

This changes the milestone tracking of remaining work, not its priority, scope, native
parent relationships or completion state. Do not close these epics merely to empty F1.
After the epics are accounted for and #52 is completed with successful PR/main evidence,
close the F1 milestone. I12 / #53 is next in the serial queue. F2 and REL-01 remain open;
no tag, release, publishing, purchases or additional account access is authorized here.
