# F5 native transport assessment and proposed feasibility scope

Date: 2026-11-07. Tracking: #89 / #17. Status: documentation-only proposal. No client/server code was executed and no transport or public API is adopted by this review.

## Decision context

The owner selected future foreground status/data updates, no existing server, app-owned reconnection and evaluation of iOS/iPadOS 18, macOS 15 and tvOS 18. Direct generic Watch WebSocket is explicitly deferred under TN3135. HTTP support and publication #29/#132 remain unchanged. See [requirements and discovery plan](F5_FEASIBILITY_PLAN.md).

The specification names URLSessionWebSocketTask; current Apple TN3151 recommends Network framework for new WebSocket code unless there is a specific reason for URLSession. A comparison and, if selected, a documented source-specification deviation are required. Neither availability nor familiar HTTP configuration proves runtime security or resource behavior.

## Comparison

| Concern | URLSessionWebSocketTask | Network framework: NWConnection + NWProtocolWebSocket | Assessment |
| --- | --- | --- | --- |
| Current floors | SDK declares task available before all selected floors | Existing NWConnection/WebSocket options also predate selected floors | No OS bump is justified. Do not depend on newer-only Network concurrency APIs accidentally. |
| Handshake/address | URLRequest-based creation; documented redirect/authentication delegate behavior, subprotocols and automatic cookie participation | URL endpoint/parameters and WebSocket handshake headers/subprotocol options; URL path/query, Host, selected protocol and rejection behavior must be observed | Both need exact fixture assertions; never expose credentials to a new origin silently. |
| State/Swift concurrency | Native async send/receive plus task/session delegates | Queue callbacks, connection states, message metadata; wrapper would need explicit isolation/cancellation bridging | URLSession is ergonomically simpler; Network requires careful bounded bridging, not a speculative generic transport framework. |
| Framing/message limits | Whole-message receive and configurable maximumMessageSize; installed header describes continuation-frame aggregate limit | Native WebSocket framing, configurable maximumMessageSize and receiveMessage metadata | Test below/at/above limits, fragmented and slow input. Neither setting is a process-memory guarantee. |
| Control frames | Ping completion and close code/reason APIs | Ping auto-reply option and WebSocket metadata/opcodes | Do not implement protocol framing manually; define visibility and application heartbeat separately. |
| Session/security reuse | Cookies, authentication and redirects participate in Foundation semantics; HTTP delegate cannot simply be assumed suitable for a different task type | Own connection/TLS/handshake policy; no reuse of a URLSession object | Neither inherits the SDK HTTP security contract automatically. Default system trust and explicit credential binding remain required. |
| Send completion | Local completion is not remote application acknowledgement | Completion likewise needs app-level acknowledgement semantics separately | Do not promise delivery, persistence or exactly-once updates. |
| Shutdown/backpressure | Task cancellation and session ownership need terminal arbitration; pre-handshake operations may queue | Connection cancel/state callbacks and in-flight callbacks need terminal arbitration | Admit bounded work only after open, join owned work, prove idempotence and stop late callbacks from reopening state. |
| Test fixture | Can act as client against a controlled server | Native listener/handshake handler can provide an isolated local server fixture and native client | Network is a promising dependency-free fixture route; a fixture is not a production server feature. |
| Platform restrictions | Watch low-level restrictions apply despite API availability | Same Watch restriction | Neither choice bypasses the approved Watch deferral. |

## Recommendation, not adoption

Evaluate the established Network framework route first, following TN3151. Keep URLSessionWebSocketTask as a focused comparator. Choose one production route only after the spike proves the necessary state, handshake, bounds and cancellation behavior; do not ship both adapters or add a public abstraction merely because two candidates were compared.

URLSession may still win if concrete server/HTTP integration needs justify it and its native controls satisfy the contract with less complexity. A Network choice must explicitly document the deviation from the original Foundation-specific suggestion, exact isolation/cleanup cost and regression boundary. Neither requires a new package/product or external dependency. Keep HTTP APIClient/NetworkClient, retry policies and timeout contracts unchanged.

No final API, fixed production message size, subscription protocol, heartbeat, token refresh or reconnect policy is selected. A future reference test protocol demonstrates mechanics only, not a real product requirement.

## Proposed isolated non-delivering spike

This is a reviewable scope proposal, not permission to create or run code. After plan acceptance, obtain separate explicit code-start approval for a single feasibility task with these limits:

- Local-only, synthetic, finite data on the existing Mac. Use native Apple APIs, the current toolchain and existing installed simulator routes when practical. No public stress, paid services, new dependencies, certificates/profiles, device installs, account/OS changes or release/tag.
- Isolate experiment sources under `Tools/WebSocketFeasibility/`, outside the distributed target and production test host. Never add a public API, Package.swift product/dependency or change HTTP production source. A local tool-only manifest may be created within that directory if separately authorized with the spike.
- Build a small native loopback fixture with counted connections/messages, captured synthetic handshake fields and explicit finite fault modes. Accept exactly the expected loopback endpoint; no default wildcard listener, external service or reusable production server.
- Probe both candidates for one open, one text and one binary exchange, configured subprotocol/header receipt, one active receive, server close, caller cancellation and immediate shutdown. Then investigate Network first for slow/oversized/fragmented input, withheld handshake, abrupt peer loss and repeated bounded teardown. Do not claim invalid-frame coverage if a native fixture prevents constructing those frames.
- Explicitly local cleartext is acceptable only for this isolated mechanics experiment. It proves no WSS, hostname verification, system trust or on-wire credential protection. A trusted WSS fixture route is an unresolved follow-up gate; no trust bypass or provisioning is implied.
- Proposed experiment constants, not production defaults: 64 KiB receive-message setting; 1 KiB and 64 KiB-1/64 KiB/64 KiB+1 payload probes; one connection at a time; one in-flight receive and at most one in-flight send; 10-second handshake bound, 2-second close bound, 20-second per-case harness stop. At most eight repeated open/exchange/close cycles per candidate, not a benchmark. Report actual boundary behavior; do not silently equate Data length and UTF-8 scalar count or assume both APIs treat equality identically.
- Do not introduce an internal unbounded message/event queue. Record what happens to peer data while the consumer pauses and which buffering remains within the OS. Measure finite whole-process/resource observations only; no hard aggregate-memory/disk cap or production-device suitability claim.
- Preserve failures/timeouts separately from explicit followups. Record source hashes, actual compiler/SDK/runtime/architecture, test counts, resource setup and evidence gaps. No automatic reruns or unexplained pass-only summaries.

## Completion and stop/go

Required report: candidate comparison with observed handshake/path/header/subprotocol/state/error behavior, cancellation/shutdown completion and callback ordering; message-limit boundary results; counted connection/work teardown; build versus runtime versus TLS/physical evidence; complexity and remaining unknowns. Synthetic account headers must be distinct and nonsecret. Do not print arbitrary peer payloads, paths, queries or close reasons into normal diagnostics.

Stop and return a negative/incomplete finding if the chosen contract needs a custom TLS/WebSocket stack, unbounded queues, broad HTTP refactoring or unsupported platform behavior. A timeboxed failure does not justify expanding the experiment automatically. Do not call a native client success evidence for the SDK because the SDK has no WebSocket feature yet.

After the report, revisit whether a real server/use case is known enough to approve a product contract. Only then approve an ADR and create bounded implementation/verification/documentation/gate tasks. #89 is not complete from this proposal alone; #17 is not delivered. Reconnect remains a separate unselected increment.

## Evidence basis

Reviewed installed Xcode 26.3/SDK26.2 Foundation NSURLSession.h and Network Swift interface plus the following Apple primary documentation on 2026-11-07. This is source/documentation inspection, not compilation or runtime verification.

- [TN3151](https://developer.apple.com/documentation/technotes/tn3151-choosing-the-right-networking-api): transport recommendation.
- [TN3135](https://developer.apple.com/documentation/technotes/tn3135-low-level-networking-on-watchos): physical Watch restrictions.
- [URLSessionWebSocketTask](https://developer.apple.com/documentation/foundation/urlsessionwebsockettask): native task, asynchronous operations, handshake/cookie/delegate participation.
- [NWProtocolWebSocket.Options](https://developer.apple.com/documentation/network/nwprotocolwebsocket/options): native framing, limit, ping and handshake configuration.
- [Network maximumMessageSize](https://developer.apple.com/documentation/network/nwprotocolwebsocket/options/maximummessagesize): receive-message setting.
- [NWConnection.receiveMessage](https://developer.apple.com/documentation/network/nwconnection/receivemessage(completion:)): native message receipt candidate.
