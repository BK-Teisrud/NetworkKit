# F6 native feasibility scope proposal

Proposed only, 2026-11-09, #90 / PR #177. Offline Phase A authorization does not cover this work. This document defines a possible first Mac-only batch for owner review; it does not authorize code, connections, test keys/certificates or production capability. It does not complete F6's physical/multiplatform evidence.

## Concrete execution manifest

The [execution manifest](F6_NATIVE_EXECUTION_MANIFEST.md) refines source files, commands, seven synthetic pairs, exact 32 initial Swift cases plus 16 correction cases, native expectations, process ownership and cleanup. Its explicit refinements supersede inconsistent wording in this earlier proposal; no execution is authorized yet.

## Proposed executable and isolation

Extend only Tools/F6Feasibility/ with a standalone Swift tools 6.2 executable and controlled Python/OpenSSL fixtures. No external package, shipping target, root CI, signing identity, Apple account, host entitlement, Keychain, installed certificate/trust store or device installation changes. A fixture manifest names every source, command, scenario, counter and cleanup owner before execution. Existing Phase A ledgers remain immutable; its correction reserves cannot fund this batch.

First batch: Mac 15.8.1 Intel only. Explicit loopback addresses and OS-assigned ports; bind no LAN interfaces. No Bonjour advertisement/browsing, radio peer-to-peer, multicast joins or QUIC traffic in this batch. Those remain independent named gaps with later route-specific plans, not silently deferred delivered requirements.

## Proposed connection ledger: at most 48 local plus four external

Each initial row below is one logical candidate connection, including negative/timeout/cancel outcomes. One fixture peer accepts that same connection; it is not an additional candidate attempt. No preflight connection, health-check socket, automatic application retry or uncounted control. Native/system internal wire attempts are not claimed to equal logical counts. Record accepted sockets, request/message counts and observed native tasks where visible. If a scenario requires another candidate connection, it consumes a separately recorded reserve slot or stops.

| Group | Eight initial cases, one local connection each |
| --- | --- |
| H01–H08, signing over local HTTP fixture | absent body; empty body; binary body; percent-escaped/repeated-query target; auth/content-type coverage; independent body mutation rejection; redirect refused; cancelled/late signer starts no further request |
| T01–T08, TCP/framing | partial receive; coalesced length frames; split delimiter; truncated EOF; overlength rejection; one simultaneous send/receive; active receive cancellation; bounded close/late callback |
| D01–D08, connected UDP | zero datagram; exact configured maximum; configured oversize send rejected; received oversize/truncation rejection; controlled loss timeout; reordered fixed pair; duplicate receive rejection; cancellation/cleanup |
| L01–L08, isolated fixture TLS/pins | valid scoped fixture anchor/matching leaf; wrong leaf pin; rotated backup leaf; invalid hostname; invalid chain; cancelled verification; TLS minimum compatibility; pending shutdown/late trust result |
| I01–I08, isolated fixture mTLS | valid identity; no identity; wrong identity; expired identity; repeated challenge policy; wrong-origin policy; cancelled setup/provider; distinct account binding refuses reuse |

Forty initial connection slots total; R01–R08 are correction reruns of one named failed scenario only, with source change, original log and result retained. No new scenario or missing-route replacement. Some pre-admission failures may use zero physical connections but still consume their logical scenario slot; they do not free a spare connection for another case. Each connection is bounded to 20 seconds, 16 messages/requests and 64 KiB payload in either direction. Setup/provider/close deadlines are recorded separately within the process bound; no wait/retry loop.

Potential public controls, explicitly separate and sequential:

1. HTTPS badssl.com with system trust, capture the public leaf DER after successful trust for a synthetic observation only.
2. Same host, previously observed matching DER pin plus a synthetic distinct backup, system trust still required.
3. Same host, two nonmatching synthetic pins; must reject despite system trust.
4. HTTPS self-signed.badssl.com; must reject under unmodified system trust.

Each external candidate has a 15-second total budget, one request, response body not retained and at most 4 KiB read for the observation. Three valid-host connections are not a production pin-provisioning or rotation scheme. Certificate changes between controls remain failures/inconclusive observations, not permission to learn and accept a replacement silently. No credentials/private URLs or uploads. Native trust services may perform their own auxiliary requests outside application visibility; do not promise an exact DNS/OCSP/AIA wire count. External controls are supplemental, not mTLS/rotation fixture evidence. Endpoint source provenance is reviewed without a live probe; the counted observation determines reachability. No extra live preflight request is permitted.

## Synthetic TLS boundary and test material

Proposal permits at most seven ephemeral test key/certificate pairs: one fixture CA; three server leaves (current, backup, hostname mismatch); three client leaves (valid, wrong identity, expired). Generate only in a private temporary directory, permissions 0700/direct files 0600, using an existing local OpenSSL executable. Keys are local test fixtures and never published, installed, imported into Keychain or used for an Apple account/signing operation. Public reports retain only nonsecret hashes/conditions/outcomes. Exact commands and names must be reviewed before generation; no wildcard extra certificate batch.

An isolated test adapter may use that CA as a per-evaluation fixture anchor only on the explicit loopback fixture. The default production-shaped path must reject the same untrusted fixture without this test configuration. Never add a production trust override or change installed anchors. Positive fixture results establish handshake/pin/identity mechanics under the synthetic test anchor; they do not establish default system trust. The separate public controls establish only their recorded system-trust observations. Neither substitutes for a real authenticated application server.

Construct test SecIdentity in memory from the generated test key and certificate using supported Security APIs; reject a path that would require persistent identity import. Validate URLCredential persistence=.none and identity/chain shape. Do not invoke user Keychain/enclave or prompt for keys. Native trust fetching is disabled on synthetic trust objects without AIA/CRL URLs to avoid accidental external fixture activity. If Security APIs cannot provide this isolated test boundary, stop and revise the plan rather than install a root or bypass production verification.

## Compilation, pure Swift cases and process limits to specify before execution

The native harness needs an explicitly separate compiler ledger; do not count it as a Phase A correction. Proposal: at most four Mac build commands (one initial and three documented correction builds) and 32 named initial pure Swift cases plus 16 correction-only cases for credential carrier validation, signing/profile vectors and exactly-once state/cleanup models. The exact identifiers/assertions are listed in the execution manifest; none is authorized by this draft. Full multiplatform API consumer compilation remains a later acceptance requirement.

Maximum two experiment subprocesses concurrently, total at most five work processes. The controller must own/clean up its fixture child and terminate only its own process group. One native group at a time, no polling public availability. Per-group 180-second bound, whole batch 15 minutes; communicate at natural group boundaries rather than block a tool call for the whole batch. On failure retain source/command/log and stop that scenario; bounded correction reserves are explicit, never automatic.

## Gate before requesting this batch

- List exact source/executable commands, certificate-generation commands, 32 Swift case identifiers, ports/routes/fixtures and cleanup ledger.
- Resolve signing's production HTTPS-only rule versus local cleartext fixture: allow an explicit tool-only adapter that cannot be selected from SDK public API; this proves reconstruction only, not HTTPS admission or secure transport. A signed local request must never make the shipping profile accept HTTP.
- Resolve identity-bound factory, trust callback ownership and app ATS compatibility in candidate declarations.
- Obtain separate owner approval for this concrete code/runtime/key/certificate/network scope. Current document is not that approval.

Keep PR #177 open as the same planning workstream. Scope/contract decisions and honest remaining gaps still precede production start; #13/#18, #29/#132 and watchOS native exclusion remain unchanged. Physical/QUIC/Bonjour/peer-to-peer/multicast coverage is neither accepted nor erased by a successful Mac batch.
