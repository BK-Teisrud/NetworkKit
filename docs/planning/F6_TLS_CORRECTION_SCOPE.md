# PREP-F6-TLS / #178 correction scope

Owner-authorized and executed against commit 55f31cf on 2026-11-09; [results](F6_TLS_CORRECTION_RESULTS_2026-11-09.md) record all selected initial controls passed. No further execution is implied. Same planning PR #177, child of #90. The previous Mac batch remains immutable evidence: four builds, 48 local and four public attempts exhausted, I04 harness failure retained. No prior reserve is reused or reset.

The remaining sections preserve the exact pre-execution proposal approved by the owner; their earlier future/uncompiled wording is historical. The result report above owns actual execution status.

## Concrete candidate correction already prepared

NativeState.swift adds an experiment-only ChallengeGate. A lock owns pending challenge tokens and one terminal flag. Closing drains pending handlers with rejection, outside the lock. A late evaluator cannot submit an accepted credential through a drained token; duplicate completion is suppressed. Registration after closing immediately rejects. Handlers can reenter the gate without a lock deadlock. Admission linearizes under the lock: a reply already admitted before close may physically finish afterward. This does not promise to retract credentials already handed to Foundation or stop OS trust evaluation instantly.

NativeProbe.swift registers every challenge through that gate, closes it on cancellation, session shutdown, task completion or response byte overflow, and never hands an unguarded client/trust credential back directly. In delayed trust scenarios, a real trust-entry barrier triggers cancellation or session.invalidateAndCancel before trust work is released; late work must be suppressed. Exactly-once counters and empty pending state are checked after the delayed work finishes. An already cancelled request is checked before configuration/task construction. Native callbacks and session resource drain remain separate concepts.

NativeMain.swift retains I04's narrow source-specific native codes (including -1004 only for the expired-client candidate) while run_tls_correction.py requires independent server certificate_verify_code=10 before acceptance. A generic -1004 without that witness is deliberately rejected by the G08 control. The original red runs are not relabelled green.

All source changes stay in Tools/F6Feasibility/. No production API, root tests/CI/dependencies/privacy manifest, platform floor, signing identity, credential store or installed trust changes. Static Python parsing and diff checks have run; NO new Swift compiler command, pure case, connection, certificate or key has run/been generated. The code remains an uncompiled candidate until a new explicit decision.

## Proposed new envelope

| Resource | Maximum and accounting |
| --- | --- |
| Mac build commands | 3: one initial plus two documented correction builds; same four Swift sources/flags as original manifest |
| Pure gate/oracle cases | 12: G01–G08 once, then up to four failed-case correction invocations |
| Local logical attempts | 8: five initial named cases below, then up to three documented failed-case corrections |
| External requests | Zero; no BadSSL, DNS availability control or fallback |
| Synthetic fixture key/certificate pairs | Five, generated once: CA, server-current, server-backup, client-valid, client-expired |
| Concurrent experiment children | At most two (fixture and probe); never more than five logical work processes overall |

No automatic retry, running all old cases, new case identifiers, extra controls or fixture regeneration. A failed/skipped case is not a pass and consumes its started slot. Unused correction slots cannot fund a new scenario. Each failed-case rerun has its own retained source hashes/logs/reason. The new ledger uses a distinct private output directory and tls178-ledger.json, never overwrites the old ledger or copies old quotas. Direct executor launches outside the new controller are not authorized.

## Exact pure inputs

| ID | Required evidence |
| --- | --- |
| G01 | One active token allows one credential reply; duplicate result is suppressed |
| G02 | Register after closing rejects exactly once, with zero credential admissions |
| G03 | Close a pending token, then submit late credential; one rejection, no use |
| G04 | Close two pending tokens, then submit both late results; two replies total, handlers can read gate state reentrantly |
| G05 | Resolve before close; preserve the already admitted reply rather than pretend it was retractable |
| G06 | Two concurrent result submissions for one token; exactly one handler invocation |
| G07 | Concurrent close and completion; exactly one outcome with admission ordered by the lock, closed and empty final state |
| G08 | Native -1004 with no independent server expiry witness is NOT accepted as expired-client proof |

Concurrency cases use one fixed race each, not a hidden stress loop or proof of every scheduling interleaving. Every handler in G01–G07 performs a reentrant state read, which must not deadlock. G08 calls the same Python joint-proof predicate used for I04; no live transport is created. A synthetic password-based URLCredential is used only as an opaque pure-test carrier and never submitted to native authentication or read for its password. No user credentials.

## Exact initial local cases

| ID | Required outcome |
| --- | --- |
| L01 | Uncancelled fixture TLS plus current/backup DER pin set succeeds; demonstrates the gate does not reject every server-trust response |
| L06 | Cancel the actual native task after trust-entry barrier, before delayed verification admission; each registered handler completed once, zero credential admissions, at least one late result suppressed, zero pending handlers and one request terminal result |
| L08 | Same delayed path with actual session.invalidateAndCancel, not an alias for task.cancel; same counters, no post-close admission |
| I01 | Uncancelled in-memory client identity succeeds; independent peer confirms TLS and expected client leaf and HTTP 200 |
| I04 | Expired-client request fails; independent peer reports expiry verify_code=10 plus the recorded narrow native outcome; absent fixture proof cannot pass |

These do not prove production ATS interaction, arbitrary provider cooperation, host permission behavior, Swift API availability on other families, cross-account resumption, general load/resource bounds or all native state races. Existing discovery/listener/QUIC/peer-to-peer/multicast and final API gates remain. No full F6 go or production acceptance follows.

## Commands, fixtures and cleanup

Prepared controller: `PYTHONDONTWRITEBYTECODE=1 python3 Tools/F6Feasibility/run_tls_correction.py --output <new-private-directory> --action <build|setup|pure|local|cleanup>`. The action is mandatory; imports never run a batch. NativeMain is an executor, not the scope admission boundary. The controller accepts no public action and no case outside the lists above.

Build: xcrun swiftc -parse-as-library -swift-version 6 -warnings-as-errors, selected macosx SDK, x86_64-apple-macosx15.0 and NativeValues.swift/NativeState.swift/NativeProbe.swift/NativeMain.swift, writing only the private executable/logs. No app bundle, codesign, simulator or dependency install. A correction build requires a documented reason and consumes one of the two reserve builds.

Use the original [exact fixture command templates](F6_NATIVE_EXECUTION_MANIFEST.md) with only server-current/server-backup/client-valid/client-expired passed to the prepared setup function. Five pairs total including the CA; do not generate server-wrong-host/client-wrong. Same RSA-2048/SHA-256, explicit SAN/EKU/validity, private 0700 directories/0600 files, existing OpenSSL/Python libraries, no AIA/CRL endpoints. The expired client ends execution minus two days; server/client positives include current time. Record hashes/validity. No certificate/key bytes enter GitHub. Construct SecIdentity in memory and URLCredential persistence=.none; no Keychain import/read, hardware keys, personal signing or account change.

Trust anchor remains explicitly fixture-local, passed only to the loopback evaluation with network fetching disabled. It is never installed and cannot be chosen from the shipping SDK. No system-trust, root-store or ATS exception. Positive fixture trust is not ordinary system-trust proof; previous public controls keep their old source-specific status and are not repeated here.

Native fixture binds only 127.0.0.1:0, announces readiness through a pipe, accepts one candidate connection, and publishes bounded counters/conditions. No health-check socket. Per native case: 20 seconds, at most 16 application messages and 64 KiB payload each direction; five-minute native batch window, 180-second local group. Pure cases: five seconds each/120-second initial suite. Compiler: 120 seconds. The controller records started IDs before spawning children and enforces all maxima. Native/system TLS internal attempts are not misrepresented as exact application-controlled wire counts.

Normal/failure cleanup closes native work, terminates only the owned fixture/probe process group, waits two seconds, escalates only that group if necessary, and retains exact private logs plus sanitized outcome/hashes. Remove owned fixture material after the batch and verify absence. Deletion is not secure erasure from backups or a crash guarantee. No new keys may be generated to recover from a failure within this batch.

## Authorization and closure

This is one reviewable correction scope for #178, in the existing PR. The next required owner decision covers ONLY this experimental code/build/pure/local/fixture-material envelope. No execution has happened from this proposal. Do not mark #178 Done until the selected evidence, residual limitations and required PR/main checks/logs are accepted; a prepared patch or successful compile alone is insufficient. #90, #13/#18 and #29/#132 retain their separate gates.
