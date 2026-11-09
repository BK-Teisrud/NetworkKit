# F6 QUIC correction proposal for #179

Prepared 2026-11-09, same draft PR #177. Planning only: new code, compilation, fixture creation and execution require separate owner authorization. The consumed c70a780 experiment stays immutable; no unused reserve is transferred.

## Evidence and correction rationale

The [original results](F6_NATIVE_RESEARCH_RESULTS_2026-11-09.md) retain Q01–Q09 failures. Q10 independently establishes one OpenSSL-to-native stream, not the native group extraction path. Own-process diagnostics show protocol join/clone failure despite a viable loopback path. Do not call this general network failure or an OS defect.

Read-only inspection found three prototype issues to investigate together:

- The QUIC listener uses one finite newConnectionLimit. SDK listener.h documents a decrementing creation credit rather than an active-connection cap. Whether this credit obstructs the later stream route is unproven. Replace it in the isolated QUIC fixture with bounded native credit sufficient for this scope (at most eight), while independently admitting only one transport group and at most four flow contexts per endpoint. Extra groups/contexts must fail the case and be cancelled; they never expand authority. Leave the passing TCP prototype unchanged.
- Group and flow state handlers ignore waiting errors. Capture a bounded state history (at most 32 entries per object, including phase/error domain/code) and trust callback counts. A waiting error alone is diagnostic, not a successful TLS rejection. Negative cases require a qualifying handshake error and no successful application exchange; a timeout remains failed/incomplete.
- Extraction currently fails before direction/datagram/ownership assertions. Compare a stream-only configuration, the existing datagram-enabled configuration and a two-process native peer before changing production design. Keep stream options minimal; use metadata to verify actual mode/direction/ALPN, never infer them from the requested configuration.

Apple SDK sources: Network.framework/Headers/listener.h (new-connection credit and mutually exclusive handlers), connection_group.h (nil endpoint for multiplex extraction; start extracted connections), and the installed Swift Network interface. These support API mechanics; the proposed root causes still require execution. No production guarantee is inferred.

## Proposed new envelope

| Resource | Maximum |
| --- | --- |
| Compiler commands | 4 sequential Mac executable builds: one initial, three documented correction commands |
| Pure oracle/control invocations | 8: four initial fixed inputs plus four failed-input correction slots |
| Local transport sessions | 16: twelve initial sessions below plus four failed-scenario correction slots |
| New synthetic key/certificate pairs | 2: one CA and one server-current, created once |
| External sessions | 0 |
| Concurrent owned children | 2, within the overall five-process limit |

Only Tools/F6Feasibility/NativeResearch/ experiment sources/controller and result documentation may change. Reuse earlier fixture helper read-only. No shipped SDK, root manifest, CI, tests, API, package, dependency, OS floor, Keychain, installed trust, signing, physical device, account or entitlement changes. Nothing starts on import/default invocation.

Use a separate correction ledger; never reset/overwrite previous usage. Record command/source hashes and admitted counters before each action. All failed/aborted started attempts consume slots. Prior compiler8 remains a historical artifact, not a way to bypass new compiler accounting.

## Exact cases and staged execution

Pure controls O01–O04: O01 timeout without native witness cannot pass a negative handshake oracle; O02 unrelated transport error cannot pass ALPN rejection; O03 a trust-rejection witness plus qualifying terminal handshake error may pass, but ready/application-data observation invalidates it; O04 state-history overflow remains bounded and explicitly flagged. These validate the oracle, not actual TLS behavior. No broad pure/model rerun.

Each native row consumes one session, even when two owned processes participate. Loopback address is 127.0.0.1 with ephemeral port only; no probe/health-check socket.

| ID | Initial session | Observation |
| --- | --- | --- |
| C01 | 1 | Native stream-only group, datagram support disabled, default bidirectional extraction; exact request/reply, ALPN, context/transport counts |
| Q01 | 1 | Original stream case with datagrams enabled, retaining original assertions |
| C02 | 1 | Stream-only native client and native peer in separate processes, explicit bounded control channel, same request/reply; distinguish same-process correlation |
| C03 | 1 | Independent existing OpenSSL client against corrected native peer, exact four-byte exchange, CA/hostname/ALPN verification and exit status |
| Q02–Q05 | 4 | Original server/client unidirectional, datagram-only and mixed-mode assertions; no silent fallback |
| Q06–Q07 | 2 | Original wrong ALPN and untrusted peer, strengthened oracle and bounded state/trust evidence |
| Q08–Q09 | 2 | Original sibling survival and group-close child-resolution assertions |

Run O01–O04 then build and C01 first. If C01 fails, stop dependent positive cases and use only a documented correction to that failed input; no blind repetition of the remaining matrix. After C01 passes, run Q01/C02/C03. Q02–Q05/Q08–Q09 require the corresponding native group bootstrap to pass. Q06/Q07 may run independently to diagnose handshake behavior. Every unrun case stays unproved. A correction slot may repeat only a named failed input after an identified source/oracle change. No new scenario, parameter expansion, stress loop or implicit retry.

Each native case: 20 seconds total including readiness, peer startup and cleanup; group at most 240 seconds, total native runtime window 600 seconds. Each compiler command: 120 seconds. Each pure invocation: five seconds. Bound each endpoint to four native flow contexts, sixteen sends and 64 KiB sent/received per session. Do not claim these controls cap native buffers or all OS-internal attempts.

Keep one admitted transport per case. If an unexpected extra group/context/transport is observed, terminate the case and consume its slot; do not proceed under a fiction that it was free. Split-process C02/C03 have at most two owned children. Capture process termination/cleanup and ordinary removal of the two fixture pairs, without claiming secure erasure.

## Completion and backlog consequences

Preserve old failures and report exact source versions. Passing this round can complete selected #179 evidence only after review of all criteria and integrated PR/main. It does not complete native Bonjour/multicast/peer-to-peer, other-platform runtime proof, exact API approval or F6 production start. #29/#132 remain unchanged.

If native stream/datagram mechanics remain unproved after this budget, stop and present the concrete evidence. Do not silently reduce scope, add a library, raise OS floors or seek further authority under a generic continue message. #179 remains the single investigation issue; no extra PR/issue solely to record another attempt.
