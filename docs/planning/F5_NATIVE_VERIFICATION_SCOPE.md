# F5 prepared native verification scope

Status: owner approved the complete cohort on 2026-11-09. Mac local execution completed with nine passing and two failing tests; no Mac rerun is authorized. Six simulator routes remain within their original ceilings. The previous three Mac public calls are completed and exhausted. This proposal does not reuse that budget.

## Proposed routes and ceilings

Run sequentially, with no automatic retries or fallback endpoints:

| Route | Local SDK connects | New public SDK connects |
| --- | ---: | ---: |
| Mac, macOS 15.8.1 (24H32), x86_64 | 18 | 0 |
| iPhone 16, iOS 18.2 simulator | 18 | 3 |
| iPad (10th generation), iPadOS 18.2 simulator | 18 | 3 |
| Apple TV 4K (3rd generation), tvOS 18.2 simulator | 18 | 3 |
| iPhone 17, iOS 26.2 simulator | 18 | 3 |
| iPad (A16), iPadOS 26.2 simulator | 18 | 3 |
| Apple TV 4K (3rd generation), tvOS 26.2 simulator | 18 | 3 |

Total ceiling: 126 local and 18 new external SDK connect calls. OS-internal network activity is not separately controllable. Each route runs once; an unsuccessful attempt remains consumed. No implicit rerun authority. No claim about OS 18.0 exactly, physical iPhone/iPad/TV, Watch or other architectures follows from these simulator routes.

## Local scenarios

Eleven serialized opt-in tests, ten single-connection scenarios plus eight connections in the repeated-lifetime scenario:

- Raw text/binary type preservation, empty text/binary, Unicode and exact 4096-byte boundary, selected subprotocol.
- Incoming 4097-byte message against the 4096-byte application limit.
- Normal peer close and repeated receive ending, with peer code/reason snapshot.
- Application close 3001 as structured failure.
- Withheld handshake and 0.2-second connect budget.
- Active receive cancellation terminating the connection.
- Cancellation after observed TCP admission while handshake is withheld.
- Abrupt connection termination.
- Missing selected protocol rejected despite native handshake acceptance.
- Eight sequential open/send/receive/close lifetimes and explicit fixture stop.
- Sixteen finite small messages queued before the application receives, then exact ordered comparison.

The test-only listener binds IPv4 loopback, uses Apple's Network framework framing, caps incoming fixture messages at 8192 bytes and 32 messages per fixture, and explicitly cancels/stops listener and accepted connections. Ordinary SDK message limit is 4096 bytes; send/connect budgets are three seconds and close grace 0.5 seconds except the specific connect-timeout case. A one-minute test limit requests cancellation; it is not a hard OS process-termination guarantee. No raw custom WebSocket production stack is introduced.

A finite scheduling interval in the native receive-cancellation test is not a proof of every admission race. Deterministic latch-based tests cover those separately. Fixture cleanup observations do not establish immediate Foundation resource reclamation or a general memory ceiling. Malformed/fragmented raw frames and comprehensive resource measurements are not covered by this cohort; review their remaining necessity explicitly after results rather than marking them passed.

## Public scenarios

Each of the six simulator routes runs the already compiled three-test public suite once: `wss://echo.websocket.org/` with only synthetic text/five-byte binary data and the documented initial empty text frame; then `wss://self-signed.badssl.com/` and `wss://wrong.host.badssl.com/`. Each is one SDK connection, no retry. Maximum message size is 4096 bytes; connect/send/close budgets are 10/10/2 seconds and each receive has a ten-second watchdog. Certificate-related codes or -1200 establish only TLS-layer rejection in future probes; -1200 alone does not identify the certificate defect. DNS, timeout or generic upgrade failure is inconclusive. The first iPhone 18.2 run retained failed narrow-code assertions despite native strict-trust rejection logs; it is not relabelled as passed.

No external load testing, private input, real credentials, trust/certificate installation, account, dependency, purchase, physical signing/installation or publication. Existing simulator test hosts may be installed and launched solely on the listed local simulators after approval. Keep existing automatic CI public selectors unchanged; these suites remain opt-in.

## Evidence and remaining gates

Retain per-route logs/result bundles, actual test counts and OS/architecture metadata, including failed startup or test attempts. Record build-only separately from execution. Stop an affected route on infrastructure problems and do not spend additional connections to probe around them. Review remaining framing, auth/provider, resources and platform requirements after these observations. I35, I36, #17 and F5 stay open until their actual criteria and owner disposition are satisfied. #29 and #132 remain unchanged.
