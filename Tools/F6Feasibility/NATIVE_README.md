# F6 approved Mac-only feasibility batch

Non-shipping scope: [execution manifest](../../docs/planning/F6_NATIVE_EXECUTION_MANIFEST.md). Owner approved code/runtime/test material on 2026-11-09 against b4c86d3. This is not SDK implementation authorization.

The batch has finished. Four build commands, 33 pure invocations, 48 local logical attempts and four public logical attempts were consumed. All compiler slots and local/public runtime slots are exhausted. No direct invocation or new-output-directory repeat is authorized. Fifteen pure correction slots are unused and cannot fund new inputs or network work; there are no failed pure cases requiring another correction. Phase A slots are separate and untouched.

Only run_native_batch.py owns scope admission, child processes and spent-ID ledger. NativeMain is a case executor, not a security boundary preventing a person from launching it manually; direct invocation bypassing the controller is never authorized by the manifest. No batch runs by import, normal SDK tests or default CI.

32 distinct pure cases ultimately passed after invalid original W26 evidence was replaced with an explicit registered-waiter barrier. Of 40 distinct local cases, latest harness outcomes are 39 pass and I04 fail; independent I04 server evidence proves expired-certificate rejection, but the harness native error oracle failed. The changed I04 oracle compiles in the fourth build and has NOT been rerun. Original H03 failures and invalid original H06/W26 controls are retained. Four public controls pass. See the result report for exact limitations and source versions.

The synthetic CA and six leaves were generated only under the private fixture root, in-memory Security identity creation was exercised and owned fixture material was removed. No user Keychain operation, installed anchor, signing identity, entitlement, device installation, production source or dependency was used. Private logs and public leaf observations are not a release approval.

Future authorized corrections must retain the current immutable ledger and hashes. Do not reset budgets, alter native error acceptance without matching independent fixture proof, or turn loopback test anchors/HTTP signing into a shipping policy. Python fixtures reconstruct wire requests and check signatures independently; ordinary Swift/Python standard cryptographic libraries remain the primitives. Current experiment does not validate production ATS integration, general RFC conformance, real-server credentials, load, all native races or physical/platform routes.


## Prepared #178 correction

Later source edits add ChallengeGate and the separate run_tls_correction.py controller. They are uncompiled/unexecuted candidates under [the proposed correction scope](../../docs/planning/F6_TLS_CORRECTION_SCOPE.md). The original ledger/hashes/outcomes above remain historical input evidence, not verification of these later edits. No new execution authority is inferred.
