# F5 remaining verification proposal

Status: owner explicitly approved the complete scope on 2026-11-09; execution is completed and all 124 local connections are charged. No new external calls occurred. Both manual reserve allocations were used for documented protocol correction/final ordinary-adapter and extension-offer verification. See the completion ledger and technical review; no further execution permission remains. The preceding 126-local/18-public cohort is complete and exhausted. Nothing in this document reuses that permission.

## Fixed scope and ceiling

Use the same Mac and six existing simulator routes listed in `F5_NATIVE_VERIFICATION_SCOPE.md`, sequentially, without automatic retries. No new public service calls.

| Work | Connections |
| --- | ---: |
| Corrected-candidate local core suite on Mac | 18 SDK |
| Corrected-candidate local core suite on iPhone 18.2 | 18 SDK |
| Eight fixed-frame scenarios on each of the seven routes | 56 SDK |
| Mac resource profile: eight native controls and eight SDK connections | 16 total |
| Reserved manual targeted verification after a documented correction | At most 16 SDK |
| **Overall ceiling** | **124 local connections** |

The initial planned work is 108 local connections (100 SDK and eight direct Foundation controls). The sixteen-call reserve is not an automatic retry policy: use it only for explicit source-versioned verification after a diagnosed correction, retaining the original failures. Do not exceed the total or allocate new endpoints/scenarios. If no correction needs verification, do not spend the reserve. If any gate remains unresolved when its applicable budget is exhausted, stop that verification lane and report the limitation.

## Core reruns

The Mac and first iPhone 18.2 runs found real size/close mapping problems and are retained as failures. Their old authorization is exhausted. This proposal separately permits one new eighteen-call core invocation on each with the corrected candidate. It does not repeat public WSS calls or relabel old failures.

## Fixed-frame cases

`WebSocketFrameChecks` and `WebSocketFrameFixture` are isolated test tools, not a production protocol stack. They listen only on IPv4 loopback, accept at most one connection per fixture, cap the incoming handshake at 4096 bytes and produce fixed responses no larger than approximately 4.2 KiB. The eight scenarios are:

1. Fragmented text with a UTF-8 scalar split between frames.
2. Fragmented binary totaling 4096 bytes.
3. Fragmented binary totaling 4097 bytes against a 4096-byte application limit.
4. Invalid UTF-8 text.
5. Valid empty close frame, with no fabricated wire status.
6. Forbidden wire close status 1005.
7. Invalid UTF-8 close reason.
8. HTTP 302 redirect rejection, with a second native connection treated as an unexpected follow.

The fixture uses native TCP plus test-only fixed handshake/frame bytes; Apple's CryptoKit computes the protocol handshake digest. It introduces no package dependency, installed certificate or custom SDK transport. Frame choices follow [RFC6455 fragmentation](https://www.rfc-editor.org/rfc/rfc6455.html#section-5.4), [close frames](https://www.rfc-editor.org/rfc/rfc6455.html#section-5.5.1) and [UTF-8 failure rules](https://www.rfc-editor.org/rfc/rfc6455.html#section-8.1). Native failure-domain/code observations are retained; unknown transport errors must not be renamed protocol failures solely to make a test pass.

SDK connect/send budgets are three seconds, close grace 0.5 seconds, message limit 4096 bytes; each scenario requests cancellation after the one-minute test limit. This is not a hard OS process-termination guarantee. Explicit listener/connection stop is observed. No raw frame content or error userInfo is published by the SDK.

## Resource observation

`WebSocketResourceChecks` is Mac-only and separately opt-in. It uses eight direct owned store-free Foundation connections, then eight SDK connections, each with sixteen sequential 4096-byte binary echo exchanges. Each connection gets a fresh bounded loopback fixture. Total application payload is 2 MiB across both directions/phases, all local. The sampler observes process RSS approximately every 20 ms; retain initial, native-control-after-eight-seconds, SDK immediate/eight-second/61-second samples and overall peak. A three-minute test limit requests cancellation.

This is a finite synthetic observation, not an application benchmark, leak proof, allocator attribution or memory ceiling. Both fixture and client occupy the same process; sequential warmup/order biases the native/SDK comparison. Sixty-one seconds does not prove every native operating-system allocation deadline expired. No pass threshold or production recommendation is invented from unknown application message sizes/rates.

## Boundaries and final gates

Only synthetic local data. No new external connection, physical device installation/signing, account, dependency, trust installation, purchase, tag or publication. Simulator installation/launch uses only the already selected local test hosts and runtimes. Keep all existing automatic CI selectors unchanged; the new suites remain opt-in.

Retain actual results and failed attempts by route/source version. Update I35/roadmap from the evidence. I36 still needs final technical review and explicit owner disposition; required final PR/main must pass before ordered manual closure. #29/#132 publication barriers remain unchanged. No automatic closure or production acceptance follows from approving this proposed verification.
