# F5 handshake and WSS feasibility proposal

Date: 2026-11-07. Tracking: #89. Status: planning-only proposal beyond completed #165; no further experiment code or external probes authorized.

## Purpose and predecessor

#165 establishes finite native local mechanics only. PR #166/main210a8bbae8d017ca7cb94983e390df8676ea0355/run42412525675 is accepted after all seven checks/full-log review. Do not repeat its16 cases to generate more passes. Investigate the remaining transport-selection blockers against the [connection proposal](F5_CONNECTION_CONTRACT_DRAFT.md) before selecting an SDK transport/API.

## Complementary evidence routes

| Route | Proposed use | Limits |
| --- | --- | --- |
| Controlled IPv4 loopback fixture | Exact request-target/Host/header/subprotocol observations; redirect-to-second-origin contact counters; missing/mismatched protocol and handshake rejection | Local WS is not TLS proof. Native handshake handlers do not expose all request-target details, so a separately scoped bounded test-only handshake observer/fixed rejection fixture may be needed. No custom production HTTP/WebSocket stack. |
| Postman public raw echo, `wss://ws.postman-echo.com/raw` | One small text and one small binary exchange on each candidate with default system trust | Provider documentation identifies this endpoint, not guaranteed present-day runtime availability, SLA or auth/redirect control. No stress/resource/oversize tests or private data. If binary echo is transformed or unsupported, record it rather than inventing success. |
| Existing BadSSL public certificate fixtures | Valid TLS control and independent self-signed/wrong-host rejection observations using each native candidate | These hosts need not implement WebSocket. TLS success versus upgrade rejection must be separated. Generic failure alone does not establish the intended certificate defect or WebSocket functionality. |

The public route avoids provisioned hosting/certificates for these specific observations. It is not a controlled trusted WSS server and cannot replace all security fixtures. If a requirement remains unprovable, stop and report the gap; do not quietly relax it or create/install trust roots.

Postman endpoint basis: [official Echo documentation](https://learning.postman.com/docs/developer/echo-api) and [provider announcement](https://blog.postman.com/introducing-postman-websocket-echo-service/), reviewed2026-11-07. Certificate fixture basis: [BadSSL](https://badssl.com/). Service changes/outages must remain failures/inconclusive observations, without automatic retries or fallback hosts.

## Proposed finite experiment boundary

A future explicit code authorization would cover only isolated additions under Tools/WebSocketFeasibility/, not production SDK source, public API, root product/dependency, device host or CI. Keep the completed experiment/evidence intact and give this run its own source hashes, output directory and failure history. Native clients retain system trust: no verification bypass/custom anchors, keychain changes, provisioning, profiles/signing, account setup, paid runner, new dependency or deployment.

Proposed external maximum: eight connection attempts total, sequentially: for each of two candidates, one Postman echo attempt and three BadSSL TLS observations (valid sha256, self-signed, wrong-host). Only the positive echo attempt sends application messages: fixed synthetic ASCII text and binary, each at most64 bytes, no actual Authorization/Cookie, private URL/query or owner/app data. External endpoint allowlist is fixed. At most10s opening,2s send/receive/close waits and20s subprocess harness bound per attempt. No automatic retry, alternate provider or stress traffic. If positive service/control fails, preserve it and classify dependent conclusions accordingly.

Proposed local maximum: seven fresh connections per candidate, sequentially, using only loopback. Cases: exact request target/header observation; matched protocol; missing selected protocol; mismatched selected protocol; fixed handshake rejection; redirect with denied-origin contact counter; cancellation/late callback during bounded opening. At most10s opening and20s per-case harness stop. This is a feasibility proposal, not a verified way to enforce each policy. A test-only raw handshake observer/fixed rejection response must be bounded, synthetic and narrowly documented; never become a production parser/framer/server.

Optional default-trust diagnostic observation may inspect platform trust results without accepting invalid trust or changing policy. Record exact distinction between TLS-established, HTTP-upgrade-rejected and WebSocket-open. Do not reclassify all handshake failures as certificate rejection. Malformed native errors, changed fixtures and unsupported controls remain explicit incomplete findings.

## Stop/go and remaining design

Deliver a source-hashed report for path/query/Host handling, reserved-header/subprotocol controls, redirect contact behavior, default-trust positive/negative outcomes, termination and limits for each candidate. Network framework remains first candidate, not an adopted transport. Do not add a shared adapter framework or reuse HTTP retry/deadline state.

If the chosen native route cannot enforce redirect/credential/origin/subprotocol policy without custom protocol/TLS code, stop for an architecture decision. The proposal may need revision or URLSession may prove preferable; do not silently fall back between transports in production.

This experiment would not prove a real auth provider's cancellation safety, async terminal race correctness, sustained backpressure, mobile/physical/minimum behavior or app workload suitability. Those need explicit detailed design/test gates before feature delivery. A successful public echo does not approve production suitability or publication.

After owner plan acceptance and required documentation PR/main, create one bounded follow-up feasibility issue if justified and request separate explicit code start. #89 stays In Progress until contract/ADR and actual task decomposition are accepted; #17 undelivered; #29/#132 open. Direct Watch WebSocket remains deferred. No further implementation is authorized by this document.
