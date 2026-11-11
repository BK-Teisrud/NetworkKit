# PREP-F6-TLS / #178 correction results — 2026-11-09

Tracking #178, parent #90, same draft PR #177. The owner explicitly approved only the correction envelope against 55f31cf13204e1a5fb7eec6c4b5b1a94b9b107e6. This is experimental evidence, not production/API/F6 acceptance. Historical original Mac failures are not rewritten.

## Outcome and resource accounting

First Mac build passed with Swift 6 warnings-as-errors. G01–G08 all passed. L01, L06, L08, I01 and I04 all passed. No source edits occurred during execution: all 131 pre-existing implementation/tool files compared with the approved scope commit remained byte-identical. All probe observations use that source, not a later unexecuted candidate.

| Resource | Actual / approved maximum |
| --- | --- |
| Build commands | 1 / 3 |
| Pure invocations | 8 / 12 |
| Local logical attempts | 5 / 8 |
| External attempts | 0 / 0 |
| Synthetic fixture key/certificate pairs | 5 / 5, generated once |
| Correction retries | None |

Mac 15.8.1 Intel, Xcode 26.3 build 17C529, Swift 6.2.4, SDK 26.2. [Public source/result ledger](evidence/F6/TLS178_LEDGER_2026-11-09.json) retains exact per-invocation source hashes, fixture commands/validity/certificate hashes, native/peer observations and original private-log hashes. [Compiler log](evidence/F6/TLS178_BUILD_2026-11-09.log) records no diagnostics. Named raw outcome excerpts are adjacent to the ledger.

Unused two build/four pure/three local slots are correction-only reserves, not permission to repeat passing cases or add coverage. No Phase A/previous Mac quota was reused. All selected initial cases completed; no further execution is currently necessary for these particular controls. Existing user-Keychain, installed-trust, account, signing/device, dependency/product/CI and publication restrictions remain unchanged.

## Challenge gate evidence

G01–G07 exercised active/duplicate completion, registration after closing, pending/late replies, two handlers, already-admitted reply, concurrent completion, and concurrent close/completion. Each handler reads gate state reentrantly; the tests completed without deadlock. G08 uses the same joint expiry predicate as the I04 controller and rejects native -1004 without independent expiry proof.

Native positive L01 returned HTTP 200 with successful isolated fixture trust and selected DER pins. This guards against a patch that rejects every server-trust callback. Native positive I01 returned HTTP 200; the independent peer confirmed TLS 1.3 and the exact expected client leaf. This guards against a patch that rejects all identity replies.

| Native delayed case | Registered / completed | Credentials admitted | Pending | Late results suppressed | Request terminal resolutions |
| --- | --- | --- | --- | --- | --- |
| L06 task cancellation | 1 / 1 | 0 | 0 | 1 | 1 |
| L08 actual session shutdown | 1 / 1 | 0 | 0 | 1 | 1 |

Both actions are triggered by actual native trust-entry admission, rather than a guessed timer before handshake. The delayed work subsequently observes closure and is suppressed; the test awaits that work's completion before checking counters. The native outcomes are NSURLErrorDomain -999. In these cases trust evaluation itself was skipped after closing, so completedTrustCallbacks=0 is expected, not missing evidence of a completed evaluation. This establishes the selected before-admission cancellation/shutdown paths, not interruption of an evaluation already executing inside Security.

Admission linearizes under the gate lock. A reply admitted before close may physically finish afterward and is not retractable. Completion handlers run outside the lock. These fixed observations do not establish every scheduling interleaving, arbitrary callback blocking, native OS resource-drain timing or production thread-safety for a complete SDK adapter. The tool remains a non-shipping instrument.

## I04 expiry proof

Corrected I04 again surfaced NSURLErrorDomain -1004. The independent Python/OpenSSL peer recorded SSLCertVerificationError and certificate_verify_code=10, with no application data exchanged. The joint controller required both this exact expiry witness and the narrow source-specific native observation. G08 separately rejected the same native connection code without a witness. Thus the assertion no longer guesses the certificate cause from a generic connection error alone.

Original Mac I04 attempts remain failed harness runs in their original report/ledger. This separately approved corrected run supplies new, source-specific passing evidence; it does not retroactively change those outcomes or establish universal Foundation certificate-error mapping.

## Fixture isolation and cleanup

Only the newly authorized CA/server-current/server-backup/client-valid/client-expired pairs were generated. Permissions/creation use the reviewed private setup; client identity is constructed in memory and uses URLCredential persistence=.none. The fixture anchor is used only in the explicit loopback evaluation, never installed or exposed as a shipping trust override. No user Keychain/Enclave, personal signing identity, account/capability change, physical device, simulator, paid service or external endpoint was used.

The controller removed its owned fixture directory after completion; absence was verified. Certificate/key generation consumed five of five pairs and cannot regenerate material from a remaining retry balance. Logs/ledgers remain privately retained; public artifacts contain no private key or certificate bytes. Deletion is not guaranteed secure erasure from snapshots/backups or an OS-crash cleanup guarantee. OS trust internals and callbacks are not a claimed exact wire/resource census.

## Planning disposition

The selected #178 local correction evidence is ready for review. Keep #178 open/In Review until the same planning PR and main checks/full logs are accepted; do not add an artificial extra PR just to close this child. #90 remains In Progress: exact public contracts, selected capability scope and the remaining platform/discovery/listener/QUIC/peer-to-peer/multicast evidence/dispositions are still unfinished. No F6 production start or full epic closure is implied. #13/#18, #29/#132 retain their separate gates.

No new task, module, dependency, OS-floor bump or broad refactor is justified by this correction. It fixes the specific experiment gate rather than a shipping client. Proceed with the remaining comprehensive F6 plan in PR #177 without waiting for this child's eventual integrated PR/main closure.
