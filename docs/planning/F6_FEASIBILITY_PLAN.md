# F6 bounded feasibility proposal

Working plan, 2026-11-09. Tracking #90 / PR #177. No experimental code or execution is authorized yet. Keep all authorized feasibility additions and resulting design revisions in the same planning PR. This is not production code start.

## Phase A: offline capability and contract probes

Proposed location Tools/F6Feasibility/, with a standalone Swift tools 6.2 manifest only if necessary. Apple/standard-library dependencies only; do not link the experiment into the shipping target or root CI. Keep all root Sources, Tests, Compatibility, Package.swift, privacy manifests and existing tools unchanged. An isolated tool may contain candidate declarations, deterministic test seams and a separate Python standard-library signing verifier.

Concrete maximum scope for one approved batch:

| Probe | Maximum | Evidence / stop condition |
| --- | --- | --- |
| Compile-only candidate API shapes | 8 invocations total: Security/CryptoKit and Network capability surfaces for four platform SDK families | Record compiler/SDK/target, diagnostics and exit code. Include Watch availability/negative exclusion checks without suggesting runtime support. No linked host launch, simulator boot or process with a networking task |
| Pure signing/profile and framing vectors | 96 named cases total, each invoked once; no time-based polling | Compare independent expected values/verifier and bounded framing outcomes, preserve failures. No system Keychain, Security item creation or network APIs invoked |
| Source-based ownership/concurrency review | One pass of proposed handle, cancellation and completion contracts | Do not claim compiler success proves exactly-once native behavior or race safety |

A compilation invocation may use a small declaration-only fixture and local SDK modules; no connection, browser, listener, URLSession task, socket or external endpoint may be created. Pure HMAC inputs are fixed synthetic public test bytes, not generated production keys. Do not use Secure Enclave, read/create/delete Keychain items, import identities, create certificates or modify trust. No signing identities, entitlement/account/settings changes or device installation. Existing compiler cache permissions may require normal tool sandbox escalation; that does not expand the approved experiment.

Each invocation has a 120-second process limit. Each pure case has a 5-second limit and the suite a 120-second limit. Maximum two experiment subprocesses at once, within the global five-process limit. No automatic retries. Failed invocations/cases consume their slot and remain evidence. Compiler subprocess termination must be bounded; do not kill unrelated developer processes. A source fix and rerun needs a remaining reserved slot or a new explicit scope decision.

Split the 96 cases into 64 initial cases and 32 explicitly identified reserve cases for documented corrections. Maintain a ledger of exact identifiers and consumed limits. A reserve invocation/case is never free extra authority. Stop when the ledger is exhausted or a probe would need networking/credentials/dependencies outside this phase. Runtime native/TLS/permission conclusions remain unproven even if every offline case passes.

Compile-only budget allocation: 4 initial family invocations, then at most 4 reserved invocations after documented changes. If checking both modules requires separate commands, each is a separate invocation; combine module imports in one source where adequate. Do not count shell wrappers as permission to run unlimited compiler commands.

## Offline vector ledger proposed before execution

Initial cases are fixed below, not dynamically expanded by parameterization. Each row is one named case; each executes once. Any generated subcase counts separately against the budget and requires revising this ledger first. A case may have multiple assertions on the same fixed input, but must not run a hidden fuzz loop. The 32 reserve slots R01–R32 are used only for a documented corrected rerun of an initial case, with original identifier/source change/outcome recorded.

| Signing S01–S24 | Framing F01–F24 | Policy P01–P16 |
| --- | --- | --- |
| S01 absent body | F01 empty length-prefixed record | P01 invalid nonpositive limit |
| S02 explicit empty body | F02 exact maximum record | P02 invalid overflow limit |
| S03 fixed binary bytes | F03 over-maximum prefix | P03 invalid nonfinite timeout |
| S04 serialized JSON bytes | F04 fragmented four-byte prefix | P04 already-cancelled admission model |
| S05 percent-escaped target | F05 fragmented body | P05 duplicate-send admission model |
| S06 repeated query keys | F06 two coalesced frames | P06 duplicate-receive admission model |
| S07 explicit nondefault port | F07 residual next prefix | P07 one send and receive overlap model |
| S08 IPv6 authority | F08 EOF in prefix | P08 closed admission model |
| S09 empty path representation | F09 EOF in payload | P09 injected-session security rejection |
| S10 content type present | F10 prefix arithmetic overflow | P10 cross-origin identity rejection |
| S11 authorization present | F11 exact accumulated bound | P11 repeated identity challenge policy |
| S12 reserved signature field conflict | F12 accumulated overbound | P12 late provider result suppression model |
| S13 method mutation | F13 empty delimiter record | P13 signed retry rejection |
| S14 target mutation | F14 delimiter split across reads | P14 signed redirect refusal policy |
| S15 body mutation | F15 delimiter inside binary payload | P15 credential diagnostics redaction |
| S16 auth mutation | F16 consecutive delimiters | P16 unsupported Watch-native capability |
| S17 content type mutation | F17 multiple delimiter records | — |
| S18 wrong key MAC | F18 partial delimiter suffix | — |
| S19 duplicate nonce | F19 EOF before delimiter | — |
| S20 expired signature | F20 forbidden delimiter in outbound payload | — |
| S21 future created timestamp | F21 delimiter length invalid | — |
| S22 maximum signing body exceeded | F22 requested payload bound invalid | — |
| S23 metadata escaping | F23 declared byte-count mismatch | — |
| S24 retired key ID | F24 deterministic cleanup of parser state | — |

Policy model cases establish only pure rules, not native callback or actor-race correctness. Profile vector failures (including target reconstruction ambiguity) are retained design findings, not permission to weaken the oracle. Framing proposal for these offline cases: unsigned 32-bit big-endian payload length excluding the prefix; zero-length payload allowed. Delimiter profile excludes delimiter from delivered payload, allows empty records, rejects an outbound payload containing the delimiter, has no escape mechanism, and treats unterminated EOF as truncated input. Delimiter is 1–16 bytes supplied by the app; mandatory payload/accumulation bounds are checked independently. This selects no production wire protocol for an app.

## Phase B: native/runtime proof, not yet specified or approved

After Phase A, select actual candidates and write an executable-specific ledger for controlled loopback peers, signed requests, TLS/pinning/mTLS and any Bonjour/QUIC/multicast/physical peer-to-peer routes. Include counts of connection attempts (including fixtures/controls), packets/bytes, durations, retry/recovery slots, owned-process shutdown, route coverage and evidence retention. No default batch of "all available tests".

Public echo/BadSSL is insufficient for client-identity selection, pin rollover, a signing verifier, radio routes or multicast permissions. An isolated synthetic TLS fixture may need short-lived test keys/certificates and an explicit non-production trust boundary; this needs a concrete proposal/approval and must never change SDK production trust or install a root certificate. Prefer offline evaluation for policy units, and native tests that retain system trust for positive production-path proof. Test-only anchors are not positive system-trust evidence.

Physical permission, peer-to-peer and multicast evidence may need host capability/profile changes and actual devices. No existing F2/F5 approval is reused for a new F6 host or capability. If a required environment is unavailable, record the gap and ask for a scope/evidence decision; do not silently replace it with simulator-only acceptance. No paid environment or new infrastructure is assumed.

## Outputs and planning gate

Publish sanitized versioned case ledger, commands/tool versions, source hashes, expectations/results, original failures and remaining uncertainty. Strip local paths containing personal account/device identifiers from public logs. Preserve full private logs separately. Update the existing inventory, platform and contract documents, plus #90 and project priority; do not create a PR per probe. Phase A completion does not close #90 or authorize Phase B/production.

Before planning acceptance require selected scope dispositions, exact public API and wire profile, phase-specific feasibility evidence or explicit unresolved decision, implementation acceptance/decomposition and owner contract decision. Keep #13/#18 and #29/#132 boundaries honest. No implementation issues are marked Ready from an offline probe alone.
