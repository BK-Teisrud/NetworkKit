# Minimum Watch/TV native verification — 2026-10-31

I21 / [#62](https://github.com/BK-Teisrud/NetworkKit/issues/62). Reviewed implementation/test source is accepted main 5d2ae116ec685c483b1dcc31db9e41a850c4e2ac, PR #125 and main run 41182672027. The root CI passed 218 macOS tests, four simulator results of 215, two unsigned host builds and 16 helpers after full-log review. Those newer CI destinations remain distinct from these minimum runs.

## Existing route, not a new host

The opt-in package's actual Xcode scheme is NetworkKitPublicHTTPSChecks-Package. A local ignored self-referencing SwiftPM workspace exposes it. Use existing task-owned tvOS 17.0 and watchOS 10.0 simulators; Watch requires the existing task-owned iOS 17 companion pair. Commands are unsigned with warnings as errors, Swift warning suppression disabled and parallel testing disabled. No runtime download, new app host, Apple profile/certificate, account/trust/support change or paid service is involved. Root regression results and physical evidence are not replaced by this opt-in route.

## TV observation and diagnosis

On Apple TV 4K (3rd generation) / tvOS 17.0, the complete suite executed 19 declarations: 17 passed, two failed, zero skips/expected failures; xcodebuild exited 65. The valid BadSSL control and self-signed rejection declarations reported system timeouts. These are failures, not proof of certificate rejection or an unavailable server. Their cause remains unproven. Four finite local resource-control observations completed. The task-started TV simulator was shut down with exit 0.

No timeout was increased and the failed suite was not automatically rerun. A separate temporary package adds only a plain Foundation diagnostic for the two affected fixed fixtures, one bounded request per fixture with the same 5/10-second request/resource settings. It preserves default trust, no credentials and no cached stores; it does not run the SDK suite or replace its failure. Watch execution is an independent platform observation.

[Sanitized evidence](evidence/MINIMUM_NATIVE_EXECUTION_2026-10-31.json) retains source hashes, actual target summaries, scalar resources, cleanup and failure disposition. Raw logs/xcresults and simulator identifiers stay private. #62/#63/#86/#64 remain open for their actual criteria; no duplicate generic environment issue or speculative production refactor is justified by this timeout alone.

The independent plain Foundation TV control completed successfully (exit 0): valid HTTPS returned 200 after approximately 1.35 seconds; the self-signed fixture was rejected with NSURLErrorDomain/-1202 after approximately 4.50 seconds. Same 5/10-second settings, no TLS delegate or bypass. These later observations demonstrate reachability/trust handling during that control, not the cause of the original timeouts or SDK suite acceptance. No failed SDK test was rerun or timeout loosened. The diagnostic used a temporary source copy; repository test/production source is unchanged.

## Watch result and next priority

Apple Watch Series 9 (45mm) / watchOS 10.0 (21R355) executed all 19 declarations: 16 passed, three failed, zero skipped/expected failures; exit 65. Six assertion/error issues belong to three declarations: one private Foundation challenge-control expectation of HTTP 200, four app-managed HTTPS cookie positive-marker assertions, and one system timeout against the hostname-mismatch fixture. The challenge control uses Foundation directly; the cookie controls use NetworkKit with a compatible app-managed session. Neither observation alone establishes an SDK root cause or a credential leak.

All four finite local resource observations completed. The task-started Watch and minimum iPhone companion were shut down successfully (both exit 0). Full logs showed no unexpected restart or test time-limit failure; individual system timeouts remain failures. No failed suite was rerun, assertion skipped, support minimum changed or bound increased.

[NET-04 #126](https://github.com/BK-Teisrud/NetworkKit/issues/126) is the next P1 CORE investigation: compare plain Foundation and SDK cookie/store/redirect behavior; compare automatic challenge handling with an explicit fixed-synthetic Foundation fixture control; preserve failures and fix only demonstrated assumptions/defects. It follows accepted NET-03 and blocks the affected #62/#63 claims. TV/public-fixture timeout investigation remains under #62; no duplicate generic environment issue is added.

Apple's [watchOS networking note TN3135](https://developer.apple.com/documentation/technotes/tn3135-low-level-networking-on-watchos) distinguishes generally available URLSession HTTP/HTTPS from restricted low-level networking. Because this test fixture uses Network framework, its simulator execution must not be taken as proof that a normal physical Watch host can run the same listener. No audio/VoIP capability is to be added merely to circumvent that constraint. Apple's [ephemeral credential-store documentation](https://developer.apple.com/documentation/foundation/urlsessionconfiguration/urlcredentialstorage) describes private in-memory stores, but is not evidence that this particular Watch challenge control succeeded. Actual physical host/scenario applicability remains under #63.

The owner reports the intended first app workload, response sizes and concurrency as unknown. These synthetic resource observations therefore do not establish app-specific suitability or residual-risk acceptance. Existing #86/#29 retain that decision; no arbitrary product limit or new feature is inferred.
