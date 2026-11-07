# F5 isolated native feasibility findings

Date: 2026-11-07. Tracking: #165 / #89. Status: experiment findings; required experiment PR/main acceptance pending. This is not WebSocket feature delivery, a production transport decision or a completed #89 contract.

## Authorization and provenance

Owner-approved plan PR #164/main d4004eb60e4171b01c69e5d7604084814d88f6b5/run 42409624452 passed all seven checks/full-log review. The owner then explicitly authorized only #165's isolated non-delivering code under Tools/WebSocketFeasibility/, including its tool-only manifest. No signing/install, dependency, provisioned WSS, production change or publication is included.

Actual execution: physical Intel Mac, macOS15.8.1, Xcode26.3/17C529, Swift6.2.4 and SDK26.2. [Content-hashed evidence](evidence/F5_NATIVE_FEASIBILITY_2026-11-07.json) preserves sixteen exact scenario results, source/binary hashes, logs and failed build attempts. Working-tree content was executed; no final commit execution is asserted. All thirty distributed Swift files and the root manifest remain unchanged. No NetworkKit import exists in this experiment.

The first two builds failed before execution because a noncopyable Mutex could not be captured by value and a generic forwarding closure omitted sending semantics. A final reference-held Mutex and direct withLock access compile under Swift6 with warnings as errors. Build3 and final build4 passed; all runtime results use final build4. No runtime failure or automatic rerun is hidden.

## Actual observations

One native Network listener bound to IPv4 loopback and one candidate client per process; eight fresh connections per candidate. Both clients use native framing. Synthetic handshake subprotocol/header receipt is asserted on the server. URLSession also verifies the selected subprotocol in its open delegate. Exact path/query and Network selected-subprotocol metadata are not independently asserted: do not infer them from construction of the requested URL or fixture acceptance.

| Scenario | Network framework | URLSessionWebSocketTask | Observation scope |
| --- | --- | --- | --- |
| Text then binary | Passed | Passed | Exact 1KiB text and 1KiB binary; one 250ms pause before second receive; no internal event queue or slow-producer stress. |
| 65535-byte message | Passed | Passed | Exact stored bytes with 65536-byte native receive setting. |
| 65536-byte message | Passed | Passed | Equality accepted on this runtime; do not assume behavior across all versions. |
| 65537-byte message | Passed | Passed | Receive terminated without delivering data under this oversized fixture; no universal native error mapping inferred. |
| Cancel pending receive | Passed | Passed | Pending receive failed and bounded terminal observation completed. |
| Immediate/repeated stop | Passed | Passed | Cancellation/session invalidation observed; second stop idempotent in this harness. No peer graceful-ack guarantee. |
| Native normal peer close | Passed | Passed | Native normal-close indication plus bounded local termination; no application close-code taxonomy delivered. |
| Withheld handshake | Passed | Passed | TCP accepted, no response, open did not complete inside10s and stop completed. This is a harness deadline, not an implemented SDK timeout. |

Each scenario asserts exactly one accepted fixture connection and, except the deliberately withheld handshake, one handshake with expected synthetic header/subprotocol. Echo/size cases record received-message counts. Client termination and listener/accepted-connection cancellation complete within bounded waits. Callback terminal observation is not proof all callbacks/OS helpers or allocations have drained, nor a race-free asynchronous production adapter.

## Resource and buffering limits

The private runner invokes time -l per fresh subprocess with a20s process-group bound; no harness bound fired. Whole-process maximum RSS ranged3.07–3.86MiB for Network and4.97–5.61MiB for URLSession. These include fixture, runtime and frameworks, lack baseline attribution/statistical repeats and cannot choose a production transport on their own. Process exit replaces a long-lived post-deadline retention study; no leak, aggregate-memory cap or device-fit claim.

The receive setting bounds one native message as observed, not all native buffers. One paused consumer and one outstanding operation do not prove sustained backpressure, producer fairness or safe arbitrarily long bursts. Binary payloads are fixed synthetic bytes; text uses ASCII and does not establish multibyte boundary behavior. No SDK buffering/drop policy exists yet.

## Explicit gaps and stop/go

The approved finite run is complete with an intentionally incomplete production conclusion. No custom frame/TLS stack or broader HTTP refactor was needed for these mechanics. Retain the documentation-based recommendation to evaluate established Network framework first, but do not adopt it as SDK transport from this result.

Unverified: WSS/system trust and handshake redirect rejection; handshake path/query/Host and selected-protocol validation for Network; actual auth acquisition/account isolation and renewal; controlled fragmentation and malicious frames; abrupt transport failure; prolonged slow-consumer/burst behavior; close/cancel races; concurrent commands and Swift-async cancellation bridging; mobile minimum/current execution; physical devices; lifecycle/background/network transitions; representative app resources and actual server semantics. The fixture has an unused peer-cancel branch, not an executed loss test or TCP-reset injector. Native framing does not provide a public arbitrary-frame fragmentation control here. Do not bypass that with a custom production stack.

These gaps must be scoped before any further experiment or production implementation. There is no concrete server/use case contract beyond future status updates. Next #89 decision: identify an actual server protocol, explicitly approve a bounded synthetic reference protocol for further design, or defer delivery. Do not invent subscription/JSON/snapshot/drop defaults or create a full I-issue sequence now. A real protocol must determine snapshots/deltas, sequencing/recovery, auth, payload/rate bounds and outbound messages.

## Architecture and backlog disposition

Keep the HTTP core, NetworkClient protocol, deadlines/retry and one SDK product unchanged. The semaphore/Event and synchronous callback waits are standalone harness mechanics, not a proposed SDK architecture. A future connection state machine needs its own isolation/terminal and ownership contract. No new module, generic transport adapter framework or refactor is justified by these results. No new dependency or paid environment is needed to retain the findings.

#165 may complete as a non-delivering experiment after actual required PR/main acceptance, with its partial/negative production conclusion explicit. #89 stays In Progress for the contract/scope/ADR and eventual decomposition; #17 stays undelivered. Do not pre-create reconnect or separate security milestones. Direct generic Watch WebSocket stays owner-deferred; HTTP Watch support and #132 remain unchanged. #29/#132 publication barriers remain open. No further code, feature production suitability or publication is authorized by this report.

Reproduce only within the approved scope using the [tool instructions](../../Tools/WebSocketFeasibility/README.md); raw logs remain private and the public evidence contains only synthetic sanitized observations.
