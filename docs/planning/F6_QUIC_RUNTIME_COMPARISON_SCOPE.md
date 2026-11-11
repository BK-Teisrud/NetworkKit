# F6 QUIC runtime and API comparison proposal

Prepared 2026-11-11 for #179/#90, same draft PR #177. No new code/build/test/boot/material authority yet. Previous experiment ledgers remain closed. [Read-only inventory](evidence/F6/RUNTIME_ROUTE_PREPARATION_2026-11-11.json) establishes an installed available iOS 26.2 simulator with x86_64 and arm64 support. No runtime was booted. This makes an existing-runtime comparison possible without a download, purchase or package OS-floor change; actual boot/executable compatibility is unproved.

## Changed variables and hypotheses

The legacy direct/extracted-flow routes share implementation and send/receive helpers. Compare those immutable sources on iOS 26.2 with the prior Mac 15 findings first; then compare the OS-26 structured-concurrency QUIC/datagrams API on the same simulator runtime. This separates runtime and API construction variables, while still using Apple's implementation. Neither route is an independent QUIC peer.

Local SDK declarations expose QUIC.TLS.localIdentity/certificateValidator, NetworkConnection<QUIC>.datagrams/openStream and usableDatagramFrameSize at OS 26. Official API declarations support this proposal, not a fix claim. Use supported fixture identity/verification and actual trust/ALPN metadata, preserving the separately approved admission/error design. No raw wrapper/framing marker, empty-payload conversion, stream fallback or guessed security diagnosis.

Aioquic documents an application DATAGRAM API but is absent in the selected local Python environment. Installing it would add tooling/dependencies and requires a separate concrete decision; do not download it under this proposal. Existing OpenSSL 3.6 stream control is not an independent DATAGRAM control. The installed-runtime route is proposed first because it requires no new library, Apple identity or paid infrastructure.

## New code and runtime boundary

Only new experiment files under Tools/F6Feasibility/NativeResearch/RuntimeComparison/: RuntimeMain.swift, ModernQUICProbe.swift, RuntimeState.swift and run_runtime.py. Reuse earlier legacy driver/helper sources read-only by selecting entry points; no old evidence/controller reset. Any copied source needed to isolate an @main entry point is hashed and compared with the original; changed legacy behavior is labelled explicitly and cannot be called a pure runtime comparison.

Build simulator-only executables targeting x86_64 iOS 26.2 with the installed SDK. No root SDK/public API/manifest/CI/privacy/dependency change. A tool's OS-26 target is not a package floor or feature-support decision. Do not attempt OS-26-only APIs in a Mac-15 process.

At most one newly created temporary iPhone simulator device using the installed iOS 26.2 runtime, one boot attempt (180 s maximum). No existing simulator device or user's app/data/settings are altered. Use simctl spawn for explicitly built standalone simulator executables, not a physical device or signed app deployment. If this executable route/boot fails, stop and report; do not silently create an app host, install a bundle, sign, download a runtime or change host security. Shutdown/delete only the device created by this experiment on completion/failure. Owned temporary fixture files may be copied to a dedicated experiment path when needed and removed on cleanup.

## Proposed aggregate envelope

| Resource | Maximum |
| --- | --- |
| Compiler commands | 6: one initial legacy simulator build, one initial modern build, four documented failed-build/candidate corrections; 120 s each |
| Pure Swift route/ownership controls | 12: six initial inputs plus six failed-input corrections; 5 s each |
| Loopback transport sessions | 24: nine initial inputs, six failed-input corrections, up to nine changed-source final verifications |
| Synthetic pairs | 2 once: fixture CA and server-current; no prior material reuse |
| Temporary simulator devices/boot attempts | 1 / 1, bounded 180 s |
| External test connections/downloads | 0 / 0 |
| Concurrent owned experiment children | 2, overall at most five logical work processes |

A single candidate handshake and peer comprise one session. Native traffic is 127.0.0.1 with ephemeral port only. Loopback does not prove local-network permissions or radio behavior. At most four explicit native contexts, sixteen sends and 64 KiB sent/received per endpoint/session; one datagram flow per endpoint. No unbounded Task per callback or receive queue. At most 64 phases/case and 32 states/object with overflow flags. Unexpected extra group/context fails/stops the case.

Each native input has a 20 s aggregate deadline including ordinary launch/readiness/cleanup. Each explicit batch at most 240 s; total native runtime window 1200 s including corrections (boot/build accounted separately). Record forced teardown and child exits. A fixed new scope ledger records approval commit, source/commands/counters before execution; no reset or reopening after cleanup. Started failures consume quota. No hidden health connections, retry loops, LAN/Bonjour/multicast/P2P traffic, user Keychain, installed trust, personal signing, account/entitlement, physical install, spending or publication.

## Six initial Swift controls

V01 missing callback versus actual empty message; V02 unsupported route cannot silently fall back; V03 one datagram flow/context cap; V04 incomplete/over-capacity data rejected; V05 metadata/trust/ALPN required before application handoff; V06 cancellation/termination owns one result and late completion cannot revive route. Exercise actual new state/adapter admission code, not a Python model. These are fixed inputs, not exhaustive interleavings/native proof.

## Nine initial native inputs

| ID | Route and complete observation |
| --- | --- |
| L01 | Existing direct legacy route on iOS 26.2: exact nonempty client datagram then complete empty datagram |
| L02 | Legacy reverse direction, nonempty then empty |
| L03 | Legacy first application message empty |
| L04 | Legacy group extracted flow, exact nonempty/empty, conditional on a complete direct empty control |
| L05 | Legacy same-group complete datagram and stream isolation, conditional on L04 |
| M01 | Modern API on same runtime: exact nonempty client datagram then complete empty datagram |
| M02 | Modern reverse direction, nonempty then empty |
| M03 | Modern first application message empty |
| M04 | Modern single NetworkConnection carries complete datagrams including empty and separate reliable stream exchange with no cross-routing |

Start with legacy compile, required pure controls and L01. If authentication/readiness/nonempty control fails, stop its dependent inputs until a documented correction passes. If only empty delivery fails, L02/L03 may distinguish direction/first-message behavior. Do not run L04/L05 without complete prerequisites. After legacy route observations are captured, modern initial build and its state controls may proceed independently if the simulator executable route works. M02/M03 require M01's trust/readiness/nonempty phase; M04 requires complete modern empty delivery and an actual stream subpath. Missing prerequisites produce skipped/unproved entries, never passes. No Mac network repeat is added; compare immutable prior evidence honestly.

Six correction sessions repeat only named failed inputs after relevant source/route change with recorded reason. Up to nine final verifications consolidate older relevant-source observations on unchanged final candidates, once per input. Do not rerun a passing identical-source case, expand a scenario or consume spare slots merely because they exist. Compiler corrections are shared across both candidates; no quota transfer from old experiments.

## Cleanup and acceptance

Close the new ledger, terminate owned processes, remove the generated fixture and any owned copies, and shutdown/delete only the newly created simulator. Record cleanup limitations without secure-erasure or full OS resource-drain claims. Never publish temporary device IDs, keys/certificate material or user-specific paths; retain raw logs privately and sanitized source/command/outcome hashes publicly.

A simulator/modern success does not establish Mac-15 compatibility or justify raising package floors; a new failure is not a universal OS defect. No exact production adapter is adopted and no requirement waived. #179/#90, callback/resumption/platform/API review and #29/#132 stay open. Keep the same draft PR; planning/implementation/publication decisions remain distinct.

## References

- [Apple QUIC](https://developer.apple.com/documentation/network/quic) and [TN3213](https://developer.apple.com/documentation/technotes/tn3213-moving-from-multipeer-connectivity-to-network-framework): separate transport, reliable streams and datagram channel. Local SDK supplies exact availability/signatures.
- [Aioquic API](https://aioquic.readthedocs.io/en/latest/quic.html): send_datagram_frame exists; declaration is not installed/approved tooling or executed interoperability proof.
- [Existing native route result](F6_QUIC_DATAGRAM_ROUTE_RESULTS_2026-11-10.md): Mac direct/group observations and unresolved empty/mixed requirements.
