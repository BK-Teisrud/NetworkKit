# F6 runtime comparison preparation and boot result — 2026-11-11

Tracking #179/#90, same draft PR #177. Owner approved only [scope e337478](F6_QUIC_RUNTIME_COMPARISON_SCOPE.md). The single allowed boot attempt did not complete within its 180-second bound. The experiment is closed and cleaned up before tests. This is an environment-access result, not a QUIC/datagram/API failure.

## Accounting

| Resource | Used / authorized | Observation |
| --- | --- | --- |
| Compiler commands | 1 / 6 | Legacy x86_64 iOS 26.2 executable compiled, Swift 6 warnings-as-errors |
| Pure Swift invocations | 0 / 12 | None; simulator executable route not reached |
| Loopback sessions | 0 / 24 | None |
| Synthetic pairs | 0 / 2 | No fixture/key/certificate created |
| Temporary simulators | 1 / 1 | Created, shutdown and deleted; absence verified |
| Boot attempts | 1 / 1 | Timed out; status helper terminated |
| Downloads/external tests | 0 / 0 | None |

The boot process advanced through first-boot migration and reached “Waiting on System App”, but never reported ready before the deadline. Recorded elapsed time is 180.032 seconds including controller overhead. The bounded bootstatus child was terminated; the temporary device was then shutdown and deleted successfully. A fresh device inventory confirmed absence. Existing devices/apps/data were not changed, and no physical device, signing or app-install fallback was attempted.

## Source and execution boundary

RuntimeMain.swift reuses a byte-identical copy of the legacy direct-driver prefix with a new explicit entry point. RuntimeState.swift prepares six fixed state/admission inputs. Both were compiled for the simulator; none of those inputs was run. The copied prefix hash is recorded against the original. Existing source/helper files are unchanged.

run_runtime.py owns the independent fixed-path ledger, single device/boot budget, conditional prerequisites and cleanup. The modern candidate was neither implemented nor compiled: the plan required proving the standalone simulator executable route first. No failed modern API inference follows. No attempt to run a binary under a different target, create a signed host, install a bundle, download another runtime or extend the boot deadline was made.

The legacy compiler result does not establish simulator process startup, test success, TLS trust or datagram behavior. Inventory availability and supported architecture likewise did not establish readiness. The boot timeout is not proof that this runtime is permanently incompatible; longer first boot, another runtime or other environment changes require a separate reviewed decision, not an implicit retry.

## Evidence

[Sanitized per-action ledger](evidence/F6/RUNTIME179_LEDGER_2026-11-11.json) preserves approved scope, compiler sources/command, copied-prefix hash, boot duration/exit status, zero test/material counts, cleanup and skipped cases. [Compiler log](evidence/F6/RUNTIME179_compiler-1.log) has no diagnostics. Raw creation/boot logs remain private with hashes; temporary device identity and user paths are omitted publicly.

No fixture exists. Temporary simulator shutdown/delete both exited zero and absence was verified. The new ledger is closed; unused quota is not permission for another boot or native run. No root SDK/API/manifest/tests/CI/privacy/dependency/package-floor change, installed trust, user Keychain, signing, account/capability, paid service or publication occurred.

## Backlog and next priority

#179 remains Open/Blocked: Q04 empty-message delivery and Q05 complete mixed mode remain unproved, and this route adds an unresolved simulator-readiness condition. Old startup/stream passes and native-error failures remain source-specific and unchanged. Neither required semantics nor production error contracts are waived.

Do not repeat the same Mac datagram tests or unilaterally extend this one-boot scope. Before more runtime work choose a concrete supported environment/peer path and obtain its bounded authority. In parallel, continue the [independent local-network planning lane](F6_LOCAL_NETWORK_VERIFICATION_PLAN.md) under #90/#18, and security/exact-contract preparation. These are not dependent on a separate #179 merge. Keep one planning PR; no new issue merely for this boot symptom. #178 still awaits integrated PR/main; #13/#18 and #29/#132 remain open. No F6 production start or publication is authorized.
