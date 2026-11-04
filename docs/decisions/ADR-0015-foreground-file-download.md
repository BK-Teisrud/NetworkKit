# ADR-0015: Bounded foreground file download

Date: 2026-11-01
Status: Accepted planning/detailed design; I28 completed; subsequent explicit I29–I32 implementation authorization recorded below
Owner: @BK-Teisrud
Issue / requirement: PLAN-F4 #88; NK-09 #16 / specification §4.9; platform domain #26 / §4.19

## Context and alternatives

After the bounded F3 technical gate closed, the owner selected foreground download to file. File types, production sizes and a concrete app/server workload are unknown. Alternatives are continuing app-owned URLSession transfers, a broad upload/background/resume framework, or one bounded foreground GET increment. Select the last option without inventing workload guarantees.

## Decision and rationale

Accept revision 1 of the [complete contract](../planning/F4_FOREGROUND_DOWNLOAD_PROPOSAL.md#owner-approved-consolidated-contract--revision-1): URLRequest-based GET only, explicit per-call maximum, HTTP 200 including empty files, original configurable 30/60 defaults, file-backed response and app ownership at successful handoff. No oversized successful result; transient disk use may exceed the limit. Existing buffered typed/raw APIs and F3 retry remain unchanged.

No uploads, progress stream, typed file endpoint convenience, range/resume, background/relaunch, retry, queue or storage framework. Preserve auth once, per-task security, owned/borrowed sessions, joined cancellation/shutdown and safe descriptions. Structured file errors remain separate from existing public error enums. Cleanup is attempted and joined, not guaranteed against filesystem failure or crash; cancellation/timeout retain precedence without a secondary cleanup-error channel.

## Feasibility, privacy and compatibility

A saved-file URL and per-task delegate are documented API routes; runtime behavior is unverified. A separately authorized bounded feasibility task must prove lifetime, redirect/trust, supported session ownership and cleanup before shipping implementation. No borrowed-session delegate replacement or silent session substitution. Preserve all existing signatures and fixed diagnostic allowlist. Server filenames never select paths. The app owns move/removal, retention and account deletion after handoff. Unknown workloads and unavailable physical evidence remain explicit; no hard disk/memory or secure-erasure guarantee.

## Approval and verification

The owner approved the complete publicly reviewable [revision 1 proposal](https://github.com/BK-Teisrud/NetworkKit/issues/88#issuecomment-6558541234) on 2026-11-01. Translated reply: “Approve the planning proposal; still no code.” No prototype, shipping source, test execution, publication or additional feature is authorized. Required planning PR/main acceptance is still outstanding. #88 remains open for original specification reconciliation, native feasibility and detailed issue/dependency acceptance. Separate code-start decisions follow; planning approval must never satisfy them automatically.

## Consequences and deferred scope

F4 uses one selected delivery lane; no extra background milestone or date is justified. Domain #16/#26 stay open for deferred catalogs. #29 and physical Watch #132 remain separate mandatory publication barriers. F4 native acceptance is not silently deferred to those barriers. Existing F2/F3 evidence is retained unchanged, and later planning #89/#90 remains independent.

## Supersedes / superseded by

Selects one post-core extension for planning; no change to the historical F2 release candidate, ADR-0014 read-retry contract or ADR-0013 Watch publication decision.

## Subsequent feasibility-only instruction — 2026-11-01

After PR #151/main run 41312825323 passed, the owner explicitly authorized only I28's bounded non-shipping local synthetic experiment. START-F4 #145 is completed. [The first checkpoint](../planning/I28_DOWNLOAD_FEASIBILITY_2026-11-01.md) provides partial native evidence and unresolved feasibility criteria; #88/#146 remain open. Earlier no-code statements retain their original planning scope and are superseded only for I28. I29–I32/public API, signing/device installation and publication remain unauthorized.

## Detailed I28 disposition — 2026-11-01

The owner explicitly approved the [exact API/error/diagnostic design and native-partial limitation](../planning/I28_DOWNLOAD_DESIGN.md): “Approve the detailed design and limitation; no I29 code.” Candidate ownership survives terminal arbitration; inaccessible Foundation-owned partial files cannot be enumerated or attested deleted. New file errors use existing diagnostic outcome .other; NetworkClient, existing error enums/signatures and core/retry behavior stay unchanged. Final documentation PR/main acceptance precedes I28/#88 metadata completion. This is bounded feasibility/plan acceptance, not I29–I32 code permission, production support or publication. Original source-specific experimental evidence remains unchanged.

## Subsequent I29–I32 implementation instruction — 2026-11-01

After accepted PR #154/main run 41323512108 and completed #88/#146, the owner explicitly replied: “Approve code start for I29–I32.” Only the accepted detailed download design is authorized, in order beginning I29 #147. Earlier no-I29 statements remain historical and are superseded for these four selected tasks. New signing/device-installation steps, purchases and publication remain excluded; #29/#132 retain their mandatory barriers.
