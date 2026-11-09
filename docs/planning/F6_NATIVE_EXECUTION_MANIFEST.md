# F6 Mac feasibility execution manifest

Proposed execution contract, 2026-11-09. Tracking #90 / draft PR #177. Separate owner permission is required for all code and execution in this manifest; offline Phase A is complete and its reserve slots are not used here. This is a non-shipping experiment, not production code start or exact production API acceptance.

## Files and entry points to create only after approval

All new/edited executable sources are restricted to Tools/F6Feasibility/. Existing Phase A sources and consumed hashes remain retained; do not silently change/re-run their original inputs. Proposed new files:

- NativeValues.swift: candidate credential/signing/pin configuration and sanitized errors.
- NativeProbe.swift: Swift CryptoKit signer, bounded Foundation/Network adapters and exact case dispatch.
- NativeState.swift: single-resolution/cancellation state owned by the experiment.
- NativeMain.swift: explicit case arguments, no default all-tests mode or startup network work.
- native_fixture.py: owned HTTP/TCP/UDP/TLS fixture, bounded input, counters and independent signing verification.
- setup_native_fixture.py: exact OpenSSL commands described below, permission checks and fixed seven-pair inventory.
- run_native_batch.py: authorization ledger, deadlines, sequential groups and bounded owned-child cleanup. It never recursively runs Phase A.

Use one plain swiftc command rather than an extra package manifest/plugin/build graph: `xcrun swiftc -parse-as-library -swift-version 6 -warnings-as-errors -sdk <xcrun macosx SDK path> -target x86_64-apple-macosx15.0 NativeValues.swift NativeState.swift NativeProbe.swift NativeMain.swift -o <private-output>/f6-native-probe`. No signing command or Xcode app host. Exactly one initial build plus at most three documented correction builds. Compiler diagnostics are evidence; no automatic retry.

Each executable invocation selects exactly one identifier from the ledger, a private fixture manifest, an output path and required local fixture port(s). Unrecognized/duplicate/spent IDs fail before any work. No discovery, service enumeration or implicit connection on initialization. `--pure <ID>` accepts no network configuration; `--local <ID>` permits only 127.0.0.1; `--public <ID>` accepts only the two fixed HTTPS origins below. Signing over HTTP exists only in this isolated tool to inspect request reconstruction, never in the shipping profile.

## Pure Swift ledger: 32 initial plus 16 correction-only slots

One identifier is one fixed input, no hidden parameters or randomized loops. Use public synthetic HMAC bytes and fixed metadata. Python independently reconstructs/verifies Swift output without importing the Swift encoder. Native model assertions do not claim actual callback behavior.

| ID | Input and required result |
| --- | --- |
| W01 | Foundation URLCredential carried by Sendable closure, compile-time shape only; runtime closure returns no credential object |
| W02 | Synthetic password credential rejected as client identity without reading password |
| W03 | Non-identity credential with session persistence rejected before provider use |
| W04 | Nil resolved identity result rejected locally |
| W05 | Exact origin match admits policy value |
| W06 | Different host denied before credential lookup |
| W07 | Different port denied before credential lookup |
| W08 | Previous challenge failure denied by pure policy |
| W09 | Empty-body CryptoKit digest/MAC verified independently |
| W10 | Fixed binary-body digest/MAC verified independently |
| W11 | Serialized JSON UTF-8 digest/MAC verified independently |
| W12 | Escaped/repeated-query target retained exactly in canonical base |
| W13 | Present content type is covered and mutation rejected |
| W14 | Present authorization is covered and mutation rejected |
| W15 | Key ID quotes/backslashes serialized consistently |
| W16 | Caller Signature field rejected |
| W17 | Mandatory maximum body bound enforced |
| W18 | Non-disabled retry rejected for signed policy |
| W19 | Signed redirect policy always refuses |
| W20 | Same immutable handle binds key ID/MAC in fixed rotation model |
| W21 | Short MAC rejected locally |
| W22 | Invalid key ID/control characters rejected locally |
| W23 | created/expires overflow rejected |
| W24 | Retired key identifier rejected by independent verifier |
| W25 | Pending promise completed once, duplicate completion discarded |
| W26 | Two stored waiters receive the same terminal outcome |
| W27 | Logical cancel wins over a later provider result |
| W28 | Already-cancelled admission creates zero native operations |
| W29 | Invalid pin digest byte length rejected |
| W30 | Duplicate current/backup pins rejected |
| W31 | Different valid leaf DER digests represented distinctly |
| W32 | Error description omits supplied synthetic credentials/endpoint |

Reserve WR01–WR16 only rerun a named failed W case after a documented source correction. At most 48 pure case invocations total. A W case that includes independent Python verification counts as the same fixed input, not another synthetic vector. No use of real user credentials, identity access, Keychain APIs, hardware signing or certificates outside the seven fixture pairs. Five seconds per pure case, 120 seconds for initial pure suite; no blind retries.

## Fixture material: seven pairs, no installed trust or credentials

Inspect the selected existing OpenSSL executable version. On this Mac read-only inspection found OpenSSL 3.6.1 at /usr/local/bin/openssl, and Python ssl reports the same library version. Recheck metadata without connecting; an incompatible executable stops setup rather than downloading a replacement.

Create a unique private output directory (0700) and use umask 077 for every child. Paths below are relative to its fixture subdirectory. Files are 0600; directories 0700. No key files are staged or published. Exactly one root and six leaves:

| Pair | Subject / extensions | Validity |
| --- | --- | --- |
| ca | CN=NetworkKit F6 Fixture CA, basicConstraints critical CA:true, keyCertSign/cRLSign | Seven days from approved execution |
| server-current | CN=localhost, SAN DNS:localhost and IP:127.0.0.1, CA:false, digitalSignature/keyEncipherment, serverAuth | Start at execution minus one day; end at execution plus two days |
| server-backup | Same name/extensions, distinct key/certificate | Same current window |
| server-wrong-host | CN=wrong.invalid, SAN DNS:wrong.invalid, remaining server settings identical | Same current window |
| client-valid | CN=NetworkKit F6 Valid Client, CA:false, digitalSignature, clientAuth | Same current window |
| client-wrong | CN=NetworkKit F6 Other Client, otherwise valid client extensions | Same current window |
| client-expired | CN=NetworkKit F6 Expired Client, clientAuth | Start execution minus three days; end execution minus two days |

Exact command templates, applied once to each listed name only (OpenSSL output never printed if it includes key bytes):

1. CA: `openssl req -new -newkey rsa:2048 -noenc -x509 -sha256 -days 7 -subj "/CN=NetworkKit F6 Fixture CA" -addext "basicConstraints=critical,CA:true" -addext "keyUsage=critical,keyCertSign,cRLSign" -keyout ca.key.pem -out ca.cert.pem`.
2. Each of six leaves: `openssl req -new -newkey rsa:2048 -noenc -sha256 -subj <fixed subject from table> -keyout <name>.key.pem -out <name>.csr.pem`.
3. Each leaf: `openssl ca -batch -notext -config ca.cnf -extensions <server_current/server_wrong/client section> -startdate <explicit UTC timestamp> -enddate <explicit UTC timestamp> -in <name>.csr.pem -out <name>.cert.pem`.
4. Public certificate DER: `openssl x509 -in <name>.cert.pem -outform DER -out <name>.cert.der`; private-key format for in-memory Security import: `openssl rsa -in <name>.key.pem -traditional -outform DER -out <name>.key.der`. This creates a second encoding of the same key, not another key pair.

ca.cnf binds only the fixture directory's ca.cert.pem/ca.key.pem/index/serial/newcerts; initialize serial 1000 and an empty index. policy permits the specified commonName only, unique_subject=no for the current/backup hostname; default_md=sha256; copy_extensions=none. Explicit extension sections contain only the values in the table; no AIA/CRL/OCSP endpoints or arbitrary extensions. Timestamp values and resulting validity are recorded before scenarios; the controller never repairs expired fixtures by generating extra keys/certificates.

Construct SecKey and SecCertificate from fixture bytes, then SecIdentityCreate in memory. No SecItemAdd, PKCS#12 import, trust-store command, system Keychain read or signing identity use. If the in-memory import/identity association fails, retain that failure and stop dependent identity cases instead of falling back to persistent storage. Skipped dependent cases are not passes and are not silently substituted.

## Controlled peers and acceptance details

Bind exactly one active fixture service at a time to 127.0.0.1:0 and return its assigned port through stdout/pipe, not a health-check connection. The fixture stays within the experiment process limit: controller plus Swift probe and one fixture child is at most three total processes, with at most two experiment children. Compiler/setup run separately from network groups. OpenSSL children run sequentially, never while native fixture/probe children are active. This clarifies the previous two-subprocess limit: two owned children, no extra nested OpenSSL/verifier processes while they run. Independent Python verification runs in the existing fixture process.

HTTP fixture reads one request with explicit header/body byte limits, reconstructs the observed method/authority/target, and verifies the Swift canonical signature independently. No general proxy or server platform. H06 mutates the body inside the independent verification input and must fail; it does not claim the network changed a TLS-protected payload. H07 emits a redirect but does not create a second listener/connection; native task/counter evidence must show no follow-up. H08 requires zero task-starts after logical cancellation, not merely an empty fixture log.

TCP fixture sends exact predetermined fragments/EOF and bounded acknowledgements. UDP fixture sends only fixed peer-bound datagrams; loss/reorder is injected intentionally and is not a claim about OS-wide reliability or PMTU. Each datagram and all bytes still count within that case's limit.

TLS fixture uses Python SSLContext with only the selected fixture server cert/key. mTLS uses CERT_REQUIRED and the synthetic CA, then checks the presented client leaf DER against the expected client-valid digest before an application acknowledgement. I03 is expected authorization rejection of an otherwise CA-valid wrong client; do not label it a failed certificate chain or TLS handshake. I04 must be rejected for actual expired client validity. Missing identity failure must be observed at TLS/client policy, not accepted because an arbitrary transport error occurred.

L05 uses the same fixture without a test anchor in the candidate evaluation and expects default untrusted-root rejection. It is not a second unrelated CA fixture. L07 compares only the selected TLS minimum against the fixture's documented supported versions; record negotiated version, do not claim all cipher/ALPN policy. Test-only trust anchors are passed only to an explicitly isolated loopback evaluation and never exposed on a shipping API. Cleartext signing, test anchor and ephemeral identity behavior remain tool-only.

I05, I06 and I08 include native carrier/setup observations plus deliberately injected challenge/origin/account policy checks; any case that starts no connection still consumes its logical slot. They do NOT establish arbitrary server-induced repeated challenges, two-account TLS resumption isolation or identity switching under native load. Those remain separate acceptance gaps. Cancel/late-callback cases must record actual native operation/callback counters plus terminal outcome; pure state-machine assertions alone are insufficient.

## Exact budgets, public controls and cleanup

Connection IDs H01–H08/T01–T08/D01–D08/L01–L08/I01–I08 consume 40 logical local slots even when rejected before a socket exists. R01–R08 are documented failed-case correction reruns, for a maximum of 48 local slots. No new scenario, preflight connection or automatic application retry. Per slot: 20 seconds, at most 16 application messages/requests and 64 KiB payload each direction. Native retransmissions/handshake records are not misrepresented as separately controllable application payload. One group at a time, 180 seconds per group, 15-minute whole-batch controller deadline.

External E01–E04 remain exactly the four sequential controls from [native scope](F6_NATIVE_FEASIBILITY_SCOPE.md): badssl.com system-trust capture; same-host matching observed DER pin; same-host wrong pins; self-signed.badssl.com default rejection. One request, 15-second total budget, response delegate cancels after at most 4 KiB delivered body and stores no body. Foundation may buffer more internally; no global memory guarantee. No extra live availability request before the counted attempt. Source evidence is the [BadSSL project domain list](https://github.com/chromium/badssl.com/blob/master/README.md); live reachability is determined by the counted observation. Failure/inconclusive results consume the slot, never trigger fallback or relearning. System trust services' auxiliary network requests are not an exact application-controlled wire count.

Controller always records started/consumed IDs before spawning work, source hashes, fixture certificate condition/hashes (no keys), commands/tool metadata, sanitized outcome and private log hashes. Enforce one terminal result. On normal/failure/timeout: close native objects, end fixture, wait up to two seconds for the owned child, then terminate its process group with bounded escalation/wait; never kill Xcode or another developer process. Store only sanitized public evidence and private logs; remove owned private-key/certificate working material after the batch. File deletion is best effort and cannot promise secure erasure from snapshots/backups. A killed process/OS crash may leave temporary material, which is documented for manual cleanup; do not claim guaranteed destruction.

No further production APIs, dependencies, device installation/signing, entitlements, account changes, trust installation or paid services. Four builds, 48 pure cases, 48 local and four external logical attempts, seven synthetic key/certificate pairs are the total proposed new envelope. F6's final native/plattform/security scope remains unaccepted; #29/#132 and all recorded research gaps remain.
