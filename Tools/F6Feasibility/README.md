# F6 offline feasibility tool

Non-shipping, explicit standalone experiment for #90 / PR #177. See [approved scope and ledger](../../docs/planning/F6_FEASIBILITY_PLAN.md) and [results](../../docs/planning/F6_OFFLINE_RESULTS_2026-11-09.md).

The owner approved only Phase A: at most eight compile commands and 96 named pure cases, with four/64 initial slots and four/32 correction reserves. The initial batch is complete: four compilers and 64 cases passed. Do not rerun this batch under a new output directory; unused reserves are only for documented corrected reruns of existing cases, not new coverage. No networking or production authority follows.

CapabilityProbe.swift is declaration/type-check only. Functions are not invoked; it imports native modules without creating network objects or accessing credentials. The Watch branch only checks security/crypto declarations and a native-exclusion marker; it is not an actual SDK API-unavailability test or device-policy proof. No unchecked Sendable wrapper is introduced.

candidate.py contains independent non-shipping signing/framing/pure admission models. verifier.py reconstructs the fixed-profile signature base without importing candidate helpers; both deliberately use Python standard-library SHA-256/HMAC. It is not an independent cryptographic primitive implementation or general RFC parser. Policy checks are pure model assertions, not shipping integration or native race tests.

run_offline.py executes one named case per owned subprocess, bounded by five seconds/case and 120 seconds/suite, and four sequential compiler probes with 120 seconds each. Existing output ledgers reject accidental same-directory reruns. The previous command was `PYTHONDONTWRITEBYTECODE=1 python3 Tools/F6Feasibility/run_offline.py --output <private-output-directory>`. This records provenance, not standing permission to execute it again. No manifest, root CI or shipping source is changed.
