# F6 logical QUIC startup experiment scope

Prepared 2026-11-09 for #179/#90, same draft PR #177. Owner approved the [startup/error design direction](F6_QUIC_ADAPTER_REVIEW.md) only, explicitly no new code. The owner subsequently approved this exact scope. [Execution is now closed with selected controls passing](F6_QUIC_STARTUP_RESULTS_2026-11-09.md); the proposal below is retained as its authorization baseline. All prior ledgers/scopes remain closed and unchanged.

## Changed hypothesis and source boundary

Verify the [coordinator design](F6_QUIC_STARTUP_DESIGN.md) rather than wait for a particular native TLS error. Own the real verification callback, record its actual decision, and seal logical startup independently of native error delivery. Require matching native-ready/negotiated-ALPN/trust evidence before any handoff or application-data admission. Do not convert a generic error or timeout into a security diagnosis. Old Q06/Q07 probes remain failed.

New non-shipping files only under Tools/F6Feasibility/NativeResearch/: StartupCoordinator.swift, StartupMain.swift and run_startup.py. Reuse existing parent helpers/Values.swift/State.swift/QUICPeer.swift and fixture setup read-only; compile without the old ProbeMain.swift entry point. No root SDK/API/manifest/tests/CI/privacy/dependency/OS floor changes. No dynamic loader/private API bridge or new package.

The coordinator remains the callback owner through connection handoff. Every handler is answered once, even if verification is called repeatedly or after handoff. Bound experiment handler registrations to four per endpoint and reject/report overflow. Captured provider/evaluation work may continue, but cannot revive logical startup or answer a completed handler. No lock is held during native callback invocation/cancellation/caller resumption.

Read-only SDK findings: SecProtocolOptions.h documents one or more verify callbacks and provides sec_protocol_options_set_tls_resumption_enabled. The experiment disables client TLS resumption and requires an actual fresh trust callback. This is a deliberately fresh-handshake scope, not resumption support. Missing/resumed trust binding remains a production design gate. No session export or additional connection to acquire trust. Obtain ALPN through actual supported metadata before handoff; missing metadata is failed/unproved admission, never assumed success. Do not adopt a newer API without baseline availability checks.

## Proposed limits

| Resource | Maximum |
| --- | --- |
| Mac compiler commands | 4: one initial plus three documented failed-build/candidate corrections; 120 s each |
| Pure Swift coordinator tests | 20: twelve exact initial cases below plus eight failed-input corrections; 5 s each |
| Local transport sessions | 18: six initial inputs, six failed-input corrections and up to six changed-source final verifications |
| Synthetic pairs | 2, once: fixture CA and server-current |
| External connections | 0 |
| Concurrent owned children | 2; overall user limit remains five processes |

Use a new fixed-path scope ledger that records approved commit, commands/source hashes and consumed slots before execution. No reset/reopening after cleanup. A started failure/timeout consumes a slot. No old reserves or old fixture reuse. Four-context, sixteen-send and 64-KiB send/receive limits apply per endpoint/session. Handler count is separate from flow count. One admitted transport group per peer, unexpected extra group/context fails and stops that case. No hidden health connection.

All traffic is 127.0.0.1 with ephemeral fixture port. Each native input has 20 s aggregate deadline including normal peer/client startup and teardown; each explicit batch at most 180 s, total native window at most 900 s including correction gaps. Separately record forced teardown if needed. No LAN/discovery/multicast/radio/device operations. No external service, installed trust, user Keychain, personal signing, account/entitlement change, purchases or publication.

## Exact pure Swift inputs

Exercise the actual new coordinator with controlled callback/side-effect recorders, not a parallel Python model or error-description matcher.

| ID | Required observation |
| --- | --- |
| L01 | Already-cancelled caller admits no native/provider work |
| L02 | Native ready alone does not return a connection |
| L03 | Context-bound trust plus matching ALPN and readiness admits once |
| L04 | Local trust rejection followed by ready cannot admit/data-send |
| L05 | Startup timeout drains each registered handler once and returns one timeout |
| L06 | Cancellation then late acceptance cannot revive startup |
| L07 | Observed mismatching ALPN rejects before handoff/data |
| L08 | Missing ALPN cannot be presumed valid |
| L09 | Generic native failure stays transport; absent callback stays timeout, neither is invented trust rejection |
| L10 | Late provider/evaluation result cannot answer an already completed handler |
| L11 | Missing/resumed-context trust proof cannot borrow another connection's acceptance |
| L12 | A verification callback after handoff is answered; later rejection closes connection without a second startup result |

Fixed schedules and negative controls are not exhaustive concurrency proof. Corrected reruns repeat only failed inputs after a recorded source change; no hidden fuzz/parameter expansion.

## Exact six native inputs

| ID | Candidate sessions | Required controlled observation |
| --- | --- | --- |
| S01 | 1 | Fresh trusted fixture, real trust acceptance and matching negotiated ALPN; one handoff and exact bounded request/reply |
| S02 | 1 | Untrusted fixture triggers actual local verification rejection, one logical trust error and zero handoff/data; verify callback completion once; native result retained separately |
| S03 | 1 | Wrong ALPN with matching valid S01 control, actual peer handshake evidence, no handoff/data and one bounded logical transport/timeout result; no fabricated ALPN diagnosis from generic error |
| S04 | 1 | Hold a real registered verification callback, cancel logical startup, then release late evaluation; callback/caller each complete once with no admitted data |
| S05 | 1 | Hold a real registered verification callback beyond a short explicit startup budget, then release evaluation; one timeout, refusal and no late admission |
| S06 | 1 | Observe native readiness/trust but hold the handoff decision; close/cancel before releasing it; no caller connection/data admission or second result |

Each row is one native candidate handshake and its loopback peer, not a separate control connection. S04/S05/S06 use fixed test-only barriers to order real observations; do not forge a native event. A callback not reached cannot satisfy a scenario. S03 requires controlled peer evidence and S01 success; timeout alone is insufficient. No TLS-domain code is mandatory under the owner-approved design, but raw diagnostic evidence is retained without inventing causality.

Run twelve Swift controls after the first build, then S01 before dependent negatives. If S01 fails, stop dependent native inputs; only documented correction of that failed prerequisite may proceed. Six correction sessions repeat only named failed inputs after a relevant source/oracle change. Up to six final verifications consolidate older relevant-source observations on the final compiled candidate, at most once per input. Do not repeat a passing identical-source input or consume spare slots merely because they exist. Preserve all failures and distinguish skipped prerequisites from passes.

## Output and remaining scope

On completion/failure close the runtime, terminate owned children, remove the two-pair private fixture and verify directory absence. Publish sanitized versioned ledger, exact usage, source-specific outcomes and callback/ownership witnesses; keep raw logs privately with hashes. No keys/cert material in git and no secure-erasure claim.

This may establish the selected logical-startup behavior only. It does not retrospectively pass Q06/Q07, finish #179 or select final public API/production code. Empty QUIC datagrams Q04 and complete mixed mode Q05 remain blocked and are not retried by this scope. Resumption, other platforms, discovery/multicast/P2P and #90's exact contract remain separate gates. #178 still awaits integrated PR/main, #13/#18 and #29/#132 remain open. Keep the same planning PR; no new milestone/issue solely for this investigation.
