# F6 Mac feasibility results — 2026-11-09

Tracking #90 / draft PR #177. Owner authorized only the non-shipping Mac scope at b4c86d322dbabb72f4c5c94075ceb1f427ebc430. No production/API acceptance, shipping implementation, device installation or publication follows.

## Execution and budgets

Mac 15.8.1 Intel, Xcode 26.3/17C529, Swift 6.2.4, SDK 26.2; existing OpenSSL/Python SSL 3.6.1. [Full sanitized ledger](evidence/F6/MAC_NATIVE_LEDGER_2026-11-09.json) records per-invocation source hashes, results, fixture observations and private-log hashes. Source versions are not interchangeable.

| Scope | Consumed | Outcome |
| --- | --- | --- |
| Mac compiler commands | 4 of 4 | First failed on nonoptional URLCredential.certificates; builds 2–4 passed |
| Pure Swift invocations | 33 of 48 | 32 initial process passes; original W26 proof invalidated, corrected registered-waiter W26 passed; 32 distinct cases accepted |
| Local logical scenarios | 48 of 48 | 40 original + 8 documented corrections; latest 39 pass, I04 harness fail |
| Public logical observations | 4 of 4 | All four passed, sequentially, HEAD requests with zero response-body bytes retained |
| Synthetic fixture key/certificate pairs | 7 of 7 | One CA, three server leaves, three client leaves; no additional pairs generated |

Initial local process outcomes: 33 pass / 7 fail; original H06 process pass was additionally underqualified and not accepted. Eight correction invocations: seven pass / I04 fail. Original outcomes and review invalidations remain in the ledger. A passing process is not automatically valid evidence. No automatic retry, uncounted availability connection, new discovery scan or Phase A reserve was used.

The native groups/public round completed within 249 seconds of the 15-minute batch window. Fixture private directory/file permissions were checked as 0700/0600; after execution the owned fixture directory was removed and absence verified. This is deletion, not guaranteed secure erasure from backups/snapshots. No installed root, trust-store mutation, user Keychain operation, hardware signing, account/entitlement change, device/simulator launch or paid service. OS trust evaluation may use its normal services; this is not a claim of zero OS-internal trust lookup traffic.

All 122 pre-existing source/test/consumer/manifest/tool files compared with the approved baseline remained byte-identical. New executable code stays under Tools/F6Feasibility/. Root targets/dependencies/CI/privacy files and the protected untracked role review were untouched.

## Findings and retained corrections

### Identity carrier and offline rules

The actual Swift probe accepted the proposed Foundation Sendable carrier, validated an in-memory fixture identity, and completed a native mTLS request with server-confirmed expected client leaf. No custom unchecked raw SecIdentity wrapper or persistent identity import was needed. Synthetic invalid/nil/password credentials were rejected without reading a password property or using a credential store. This is source-specific feasibility, not proof for arbitrary providers, all chain shapes, Enclave identities, platform families or session/account resumption behavior.

CryptoKit output for fixed profile inputs was independently reconstructed and checked by Python. W13/W14 also rejected mutation of the covered content-type/auth fields. Original W26 used two async waiters without proving registration order; a source review invalidated that evidence. The fourth build adds an explicit two-registered-waiter barrier, and its one pure correction invocation passed. Other pure evidence belongs to build 2; it was not unnecessarily re-run under later builds.

### Actual HTTP signature reconstruction

Original H03 failed at the independent HTTP fixture. The tool had not explicitly finalized a content type for nonempty raw bodies; the profile requires covering an observed content type. The corrected request explicitly signs and sends application/octet-stream; the server observes that value and verifies the actual binary-body signature. Original raw header bytes were not retained, so do not claim an exact original auto-generated field value from this evidence alone.

Original H06 returned the expected rejection without proving the original request was valid first. That original process pass was invalidated. Corrected H06 independently verifies the original request, mutates the verifier's body input, and rejects it. H01/H02 distinguish absent versus explicit empty request construction but do not establish a universal wire distinction between them. H04 observed the selected escaped/repeated-query target, H05 header coverage and H07 redirect refusal. H08 is a real cancelled preparation-task barrier with zero admitted native tasks, not a live socket or proof of arbitrary noncooperative provider cleanup.

### Native stream/datagram observations

T01–T08 and D01–D08 process checks passed, including controlled byte fragments/EOF, simultaneous native send/receive, active cancellation, zero/size-bound datagrams, injected loss/reordering and duplicate receive rejection. The TCP tool inspects fixed returned bytes against framing oracles; it does not implement or verify the proposed shipping FramedConnection parser. Datagram tests do not establish reliability, path-MTU coverage, native buffering caps or production peer authentication. No memory/load benchmark or all-interface/radio test was run.

### TLS, pins and mTLS

Local matching current/backup DER observations passed only under an isolated process fixture anchor. Wrong pin, wrong hostname and default untrusted-root cases were rejected. Initial negative assertions guessed too narrowly at URL error codes. Corrected checks accept cancelled errors only with the matching observed delegate policy outcome (pin-rejected, trust-rejected or identity-absent), or require independent fixture evidence for identity rejection. A generic timeout/connection failure alone is never sufficient.

I01 confirmed a complete fixture TLS/mTLS handshake and expected client leaf at the server. I02 corrected evidence includes the server's missing-certificate TLS reason. I03 confirmed that a CA-valid but unwanted client can complete TLS and then be rejected by the server's leaf allowlist with HTTP 403; Foundation reported -1206. That is identity authorization rejection, not an invalid chain. I05/I06/I08 are admitted in-memory carrier/policy observations with zero native task starts, not two-account resumption or server-induced challenge proofs. I07 is a late-carrier suppression model, not a complete async provider lifecycle implementation.

L06/L08 observe cancellation on the delayed trust route; they do not prove all callback completion races or full resource drain. Source review finds the toy delegate lacks a complete logical-terminal gate before every late challenge response. A production implementation must add and verify that gate; cancellation of a native task alone is not enough. Do not reuse this test delegate as a production security adapter.

### I04 remains an explicit failed harness case

Both I04 attempts failed the harness's native-error oracle. The corrected fixture independently reports certificate_verify_code=10 (expired certificate); the Mac client surfaced NSURLErrorDomain -1004 instead of the harness's allowed TLS/cancel codes. Thus expired-client rejection was observed at the server, while the integrated assertion remains red. Keep these facts separate; neither generic -1004 nor a peer-close alone proves expiry.

Build 4 allows -1004 only for this case and only with independent server expiry proof enforced by the controller. It compiles but was NOT executed: all 48 local slots were already consumed. Original failures remain failures, no status was retroactively turned green. Any new native verification of that correction requires a separately scoped execution decision. This also means the final source is not fully verified merely because build 4 passes.

## Public system-trust controls

E01: badssl.com system trust succeeded and the observed public leaf was captured only after successful request completion. E02: the same observed leaf pin plus a synthetic backup succeeded. E03: wrong pins were rejected despite successful system trust. E04: self-signed.badssl.com was rejected with unsuccessful system trust. Negative errors were -999 with matching explicit policy observations. No body or credential was sent/retained. These are finite public observations, not a secure pin-provisioning, production rotation or general certificate-diagnosis service. They do not establish host-app ATS pin interaction or mTLS system-trust interoperability.

## Quality, plan and next decision

Retain one planning PR #177 and the broad sixteen-item inventory. Do not create extra modules, dependencies, floor bumps or speculative production tickets from this result. #90 remains In Progress, #13/#18 open and #29/#132 unchanged. Scope counters for all compiler/local/public work are exhausted; 15 unused pure correction slots do not authorize new inputs or a new build. The controller was additionally source-hardened after completion to reject closed-network scope and repeated passing cases; those guards were inspected without consuming more runtime slots.

Before production planning acceptance: resolve/verify the I04 native oracle, complete the late challenge admission/timeout gate, finalize exact public declarations and supported coverage, and obtain the remaining native discovery/listener/QUIC/multicast/physical/platform evidence or explicit owner dispositions. The toy callback/session and framing code are feasibility instruments, not a ready SDK architecture. No complete F6 go decision is justified yet. These gaps stay under the existing #90 planning owner instead of pretending research is delivered.


Concrete follow-up [PREP-F6-TLS / #178](https://github.com/BK-Teisrud/NetworkKit/issues/178), native child of #90, now tracks I04 and terminal trust completion at priority P2/order 60.1 in this same planning PR. It is blocked for further execution pending a separately prepared authorization, not a shipping defect or extra delivery PR.


## Subsequent separately authorized correction

[The #178 result report](F6_TLS_CORRECTION_RESULTS_2026-11-09.md) records new passing I04/challenge-gate evidence under a distinct owner-approved scope and source commit. The original outcomes above remain historical failures/gaps; do not substitute new source hashes or reset this original ledger. The child now awaits integrated PR/main review; broader F6 planning remains open.
