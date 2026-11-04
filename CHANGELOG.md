# Changelog

## Unreleased

### F4 verification and platform decision

- Raise declared minima under owner-delegated authority to iOS/iPadOS 18, macOS 15, watchOS 11 and tvOS 18. Older-family support is removed from this unreleased candidate; toolchain and SDK runtime behavior remain unchanged.
- Add bounded, explicitly selected native HTTPS file/auth/store/trust verification and ordinary-import compiled ownership/error examples. Public services remain excluded from automatic CI.
- Review a fresh unsigned consumer with the current FileTimestamp/C617.1 manifest. Verification/owner technical acceptance and required PR/main gates remain separate from publication.


### Architecture maintenance — combined delivery

- Group the existing single-module library/tests by responsibility; make feasibility discovery and device-host membership preserve relative source paths.
- Split the native loopback suite and execute four bounded local download declarations/eight ownership cases in Mac CI, with exact discovery/result checks. Public services and resource probes remain opt-in.
- Keep public API and production Swift behavior unchanged; consolidate current planning ownership, restore selected extension tasks in Work Queue and require privacy assessment in system-API changes.


- Corrected the download feature's bundled required-reason declaration: FileTimestamp / C617.1 covers fstat used for app-temporary file metadata. Tracking remains disabled and collection/tracking-domain lists remain empty; actual consumer privacy/distribution review remains separate.

### Foreground file download — I29 implementation candidate

- Added one explicit GET-to-file operation with a required output-size limit, HTTP 200-only completion and app ownership on successful return.
- Reuse existing security/auth/session/deadline/shutdown behavior; preserve files across terminal arbitration and clean discarded candidates. No download retry, overwrite/copy fallback or NetworkClient conformance change.
- File errors use bounded categories and existing diagnostic outcome other. Foundation-owned unexposed partial files and transient disk use retain the owner-approved limitations; I30–I32/native/publication gates remain outstanding.

- F2 non-publishing hardening/rehearsal is accepted through PR #135/main 41242130528; no version/tag/release is created. Physical Watch and owner publication/workload decisions remain separate gates.

### Bounded read retries — accepted technical gate

- Added explicit disabled-by-default, bodyless safe-read retry with at most one new library invocation, strict bounded Retry-After/jitter and the original total budget/account/origin/session boundaries.
- Added only attemptCount to one sanitized terminal event; no refresh, mutating replay or advanced resilience framework.
- I27 restores original initializer function-value compatibility and rechecks the budget after delay classification; the limited owner gate and PR #143/main run 41299838862 are accepted; final phase closure follows its documentation acceptance.
- Native/current/minimum/resource observations retain exact source/OS bounds. Physical Watch, actual workload suitability and publication remain separate mandatory gates; no release/version/date is created.

### Selected buffered HTTP core — accepted F2 baseline

- Implemented the shared typed-endpoint/raw-URLRequest client, buffered JSON/Data/UTF-8/empty responses and status/headers, safe structured errors and separate Swift cancellation.
- Added independent inactivity/total budgets, operation-owned cancellation, joined shutdown and owned/compatible borrowed-session profiles.
- Added the bounded authentication-header provider and disabled-by-default sanitized terminal diagnostics; no token storage/refresh, retry, streaming or advanced modules.
- Verified the selected contract/API/security scope and accepted minimum-family/non-Watch physical observations under their recorded limits. The owner-approved physical Watch phase deferral remains a mandatory pre-publication blocker, not a test pass or support reduction.
- Rehearsed installation from an immutable accepted Git revision, public native loopback reuse/cancellation and an unsigned clean iOS consumer archive. No version tag, release, distribution or production-readiness approval is created by the rehearsal.
- Resource measurements remain bounded observations; the owner's F2-only approval does not establish production workload fit or a universal memory cap.

### Historical implementation snapshots

The following entries record earlier task-local counts and the work remaining at those times. Current cumulative status is above; later accepted evidence does not rewrite historical test outcomes.

### HTTPS, loopback and redirect policy

- Added immutable normalized NetworkOrigin/NetworkSecurityPolicy, HTTPS defaults, explicit restricted loopback HTTP, and additional raw origins without inherited default headers.
- Bound the internal adapter to per-operation same-origin GET/HEAD redirect checks, five-hop/loop limits, and system-trust/no-credential challenge callbacks. Refined compatible sessions to prohibit credential stores/global session headers.
- Local suite: 121 test functions in 17 suites, including real macOS loopback redirects, denied-target counters, a failing isolated origin-check mutation and explicit scripted redirect coverage on other platforms. See docs/planning/NETWORK_SECURITY.md and #50.
- Public client, native device/TLS evidence and full deadline/authentication/shutdown work remain outstanding.

### Internal session transport and ownership

- Added one reused foreground URLSession adapter, explicit disabled-store defaults, strict/app-managed injection checks, and owned-only invalidation.
- Added isolated native URLProtocol tests (macOS/iOS/tvOS) and scripted internal I/O tests (watchOS, where URLProtocol is unsupported) for ownership, settings, concurrency, active external invalidation, request copies and unsupported inputs. Full local suite: 98 test functions in 15 suites passed.
- Public client, redirect/trust policy, complete cancellation/deadline/shutdown arbitration and release evidence remain later work. See docs/planning/SESSION_TRANSPORT.md and #49.

### Response strategies and status policy

- Added explicit JSON/Data/strict UTF-8/empty response strategies and per-operation native JSONDecoder settings.
- Added immutable per-call status policies, shared typed/raw response validation, metadata preservation, sanitized decoding/status failures, and cancellation checkpoints.
- Local suite: 84 test functions in 14 suites, including concurrent decoder isolation and an external public API consumer test. See docs/planning/RESPONSE_DECODING.md and #48 for hosted CI evidence.
- No executing client, deadline arbitration, or release claim introduced.

### Real CI and merge enforcement

- Added source integrity, macOS/iPhone/iPad/watchOS/tvOS builds/tests, public DocC, and a fail-closed quality-gate on standard runners with pinned Xcode 26.3 / Swift 6.2.4.
- Bound main's required quality-gate to GitHub Actions, with an up-to-date base requirement and no bypass. Verified PR/main evidence and enforcement are recorded in docs/planning/CI_IMPLEMENTATION.md and #47.
- CI exposed and fixed platform-dependent URL host representations; symbol extraction now explicitly builds generated test modules on clean runners.
- No publishing, paid runners, artifacts, external packages, or minimum-OS/physical-device support claim introduced.

### Headers and request encoding

- Added buffered JSON/Data/UTF-8 RequestBody, value-based Apple JSON encoding options, endpoint call options, and local request construction. JSONEncoder is created per preparation.
- Added typed/raw header precedence and Content-Type defaults, safe encoding failures, separate cancellation, and local rejection of body streams, managed framing/origin fields, and unsupported GET/HEAD bodies.
- Full local suite: 64 tests in 11 suites passed, including 100 concurrent preparations reusing JSON bodies. Public consumer and isolated strategy negative control verified. See docs/planning/REQUEST_ENCODING.md.

### Endpoint and URL foundation

- Added typed Endpoint descriptions, explicit decoded path segments, and ordered query items with repeated/nil/empty values.
- Added component encoding and shared typed/raw URL validation, conservative traversal/ambiguity rejection, same-origin raw checks, and safe descriptions/errors.
- Full local suite: 44 tests in nine suites passed. Public consumer and isolated escaping negative control verified. See docs/planning/ENDPOINT_URLS.md for API rules and remaining execution/security work.

### Configuration foundation

- Added immutable client/call settings, validated independent inactivity/total limits, and isolated per-operation snapshots.
- Added internal transport and monotonic clock boundaries; no live transport or enforced HTTP deadlines yet.
- Full local suite: 29 tests in seven suites passed, including concurrent snapshot isolation. Public consumer and precedence negative control verified. See docs/planning/CONFIGURATION.md.

### HTTP values and structured errors

- Added immutable Sendable HTTPMethod, HTTPHeaders, HTTPStatus, NetworkResponse, EmptyResponse, and NetworkError types.
- Added strict token/control validation, case-insensitive header lookup with opaque byte preservation, and sanitized default/debug/localized descriptions. CancellationError remains separate.
- Added 21 local contract tests with a verified negative control; networking and actual timeout/cancellation remain unimplemented.

### Package baseline

- Implementation started under ADR-0012 on 2026-10-20. Adapted the owner's Xcode starter into a repository-root Swift package: NetworkKit / NetworkKit, tools 6.2, Swift 6, OS minimums 17/14/10/17.
- Removed the empty example test; recorded actual macOS build and consumer-import smoke checks without claiming behavioral tests. No HTTP functionality or workflows yet.

### Project setup (historical)

- English is now the language of all documentation and editable GitHub project content; owner–assistant conversations remain in Norwegian. Existing decisions, identifiers, links, and implementation restrictions are preserved.
- Preparations completed through PR #65: one project status model, a sorted work queue, 23 implementation tasks, a separate start-authorization gate, hardened main/tag rules, immutable releases, and a test environment inventory. OPS-01 / #30 and F0 are complete; START-00 / #41 remains open.
- GATE-00 / #28 accepted: the owner approved the complete F0 planning baseline and documented defaults. Implementation remains unauthorized.
- Repository, workflow, security policy, roadmap, requirements traceability, and issue templates established.
- No library code or product release. No SemVer tag created.
- DEC-07 accepted: standard GitHub-hosted runners without paid add-ons, all four platform families on PRs, and separate release/minimum-OS checks. Action SHA pinning is enabled; no workflows exist.
- DEC-06 accepted: no automatic cookie/credential/cache storage, an injectable authentication-header provider, HTTPS with an explicit loopback exception, and bounded redirect/injection/diagnostic policies.
- DEC-05 accepted: a reused owned session plus injection, 30-second inactivity timeout / 60-second total budget, isolated state, cancellation, and controlled shutdown.
- DEC-04 accepted: typed endpoints and raw URLRequest, response wrapper, JSON/Data/text/empty responses, structured errors with a separate CancellationError, and explicit HTTP-status exceptions.
- DEC-01 accepted: iOS/iPadOS 17, macOS 14, watchOS 10, and tvOS 17; Xcode 26.3+, Swift tools 6.2, and Swift 6 language mode. The platform matrix distinguishes planned support from outstanding evidence.
- DEC-02 accepted: HTTP core first. Repository/package NetworkKit; product/module/import NetworkKit, with one library module in v1.
- DEC-03 accepted: Teisrud Development AS is the rights holder; proprietary rights policy with separate written permission required for third-party use.
