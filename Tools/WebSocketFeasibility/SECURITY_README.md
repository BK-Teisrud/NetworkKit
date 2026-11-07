# Isolated handshake/WSS feasibility (#168)

Non-shipping, opt-in native experiment; no NetworkKit dependency/import or automatic CI. This is separate from the original #165 executable/source-specific evidence. See the [approved scope](../../docs/planning/F5_SECURITY_VERIFICATION_PLAN.md).

## Reproduction boundary

The authorized 2026-11-08 run is limited to seven local scenarios per candidate and eight external application-initiated attempts total. Further attempts require renewed authorization; do not change the output/ledger filename to repeat a consumed budget. The ledger prevents accidental reuse of one authorization file, not deliberate creation of new ledgers. Native DNS/address/connection internal attempts are not observable or capped by the harness; counts refer to explicit native client/task openings.

Build only, using a fresh scratch path if the checkout moved:

```sh
swift build --package-path Tools/WebSocketFeasibility --scratch-path /private/tmp/networkkit-f5-security-build --product HandshakeSecurity -Xswiftc -warnings-as-errors
```

Execute only after explicit code/runtime approval for a new budget:

```sh
python3 Tools/WebSocketFeasibility/run_security.py \
  --binary /private/tmp/networkkit-f5-security-build/debug/HandshakeSecurity \
  --output /private/tmp/networkkit-security-new-observations \
  --ledger /private/tmp/networkkit-security-new-approved-budget.json \
  --external-approved
```

The runner refuses existing ledger/output files, builds nothing and retries nothing. Local fixture binding is IPv4 loopback. Fixed public destinations are Postman raw echo and BadSSL sha256/self-signed/wrong-host; only echo sends at most64-byte synthetic text/binary payloads. No external custom auth/cookie/private query/data is sent. URLSession uses ephemeral nil cookie/credential/cache stores. Native system trust stays enabled; the Foundation challenge callback observes system evaluation and returns default handling, never a credential/trust override.

## Interpretation

Exit0 / harness_completed means bounded cleanup/result capture completed, **not** a security-policy pass. policy_satisfied is a narrow per-case predicate, never the whole contract. TLS observations remain nullable; generic failure/timeout is not proof of the intended certificate defect. Public echo binary mismatch may be a service behavior or native/probe issue and is not silently relabeled as SDK failure or success.

The raw loopback observer reads at most16KiB of synthetic HTTP header bytes, checks fixed request-target/Host/header predicates and emits a fixed400 or302 response. It is not a production HTTP/WebSocket parser or framing stack. Native fixtures handle matched/missing/mismatched subprotocols. The handshakes do not establish a production auth-provider or origin/account isolation contract.

Callbacks/state observation is deliberately limited. In particular this probe does not retain Network waiting-state errors, arbitrary raw request headers or mismatch payloads. Network timeout and failed Host predicate therefore require explicit incomplete findings rather than invented causes. `terminalSeenBeforeCleanup` only reflects an error recorded before cleanup; it is not a complete terminal-state/callback-drain guarantee. Result labels are shorthand; inspect underlying flags, timing and report before drawing conclusions.

No new public API, wrapper state machine, detailed production type signatures, mobile/physical proof or production suitability follows. Consult the source-hashed report; remaining gaps return to #89 before any transport adoption or implementation work. #29/#132 remain open.
