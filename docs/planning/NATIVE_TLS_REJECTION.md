# TLS-01 — native macOS untrusted-certificate rejection

Date: 2026-10-27. Task: [#104](https://github.com/BK-Teisrud/NetworkKit/issues/104), CORE/P1, Order 20.75, under #25 in F2. Baseline: `dcf0a1b57c43ea5d96e06ee1d328e2d3d86a1a76`, accepted preparation PR #103 / main run 40550211780. This is a new native negative regression, independently executable while the owner defers physical-device connection. No production source/API, session/security policy, support minimum or package dependency changes.

## Actual boundary exercised

[NativeTLSTests](../../Tests/NetworkKitTests/Transport/NativeTLSTests.swift) creates the public APIClient with its normal owned session and HTTPS/system-trust defaults. Typed Endpoint and raw URLRequest calls both reach a real URLSession TLS handshake with a Python standard-library listener bound to 127.0.0.1 on a kernel-assigned port. No scripted transport, URLProtocol, test delegate, injected session or trust override handles those calls.

Each fixture generates a fresh, disposable RSA/SHA-256 self-signed server certificate using the existing /usr/bin/openssl. Its SAN includes localhost and 127.0.0.1, with server-auth usage and CA:FALSE. The test URL uses matching 127.0.0.1, so this is untrusted-chain evidence, not an independently controlled hostname-mismatch test. The certificate/key exist only in a private temporary directory; nothing is installed into a keychain or trust store. No operational credential, public service or external endpoint is created.

A passing result requires NetworkError.transport with NSURLErrorDomain and serverCertificateUntrusted (-1202) or serverCertificateHasUnknownRoot (-1203). Success, cancellation, timeout, request/decoding errors, generic connection failure and secureConnectionFailed alone are insufficient. These expected codes identify the tested certificate condition; the test does not treat every failed HTTPS request as security evidence.

## Fixture liveness and cleanup

Reuse the existing BoundedFixtureProcess helper. Readiness is bounded to six seconds, including a three-second certificate subprocess budget. The generator handles termination and kills/reaps its own child on failure; its output never contains key/certificate contents. The directory is created with mode 0700 and the child sets umask 077. Existing Python SSL and /usr/bin/openssl are test tools, not distributed SDK dependencies; no installation is performed.

The child becomes ready only after loading its certificate and opening the TLS listener. Test inactivity/total budgets are three/ten seconds, with a one-minute suite bound. The shared fixture helper bounds TERM/KILL cleanup; files are removed after confirmed child termination and checked absent. Setup failure and ordinary test-assertion failures also clean up; deinit provides a final process/file cleanup attempt. Failure to clean up is test failure, not accepted evidence. No finite userspace timeout is a hard real-time OS guarantee.

Safe phase labels identify typed/raw start, certificate-specific rejection code and completed fixture cleanup. No URL, private key, certificate, request headers or payload is printed. All request data is synthetic. Unexpected errors are recorded without formatting raw system error descriptions; the client still shuts down after both request paths.

## Local verification

On macOS 15.8.1 / 24H32 x86_64, Xcode 26.3 / 17C529, Swift 6.2.4, the full warnings-as-errors suite passed **218 tests in 28 suites**. Both public inputs produced certificate-specific **-1202**, followed by the fixture-cleaned phase. The host uses /usr/bin/openssl LibreSSL 3.3.6 and Python SSL OpenSSL 3.6.1 for this run. Hosted macOS runtime/tool versions must be treated as their own evidence, not assumed identical.

This adds one macOS-only test declaration/suite. Other selected runtime destinations retain 215 declarations / 26 suites; there is no dummy pass or hidden skip reported as native TLS on them. The source inventory records 218 declarations including three macOS-only declarations. Required exact candidate PR/main checks and available native phase logs must be recorded on #104 before completion. DocC/source integrity results are recorded with the candidate PR.

## Negative control

In an isolated archive of the accepted product baseline plus the new test, change only the fixture destination from its active TLS listener to https://127.0.0.1:1. The copy compiled, then both typed/raw calls failed the certificate-specific assertion (exactly two issues), while the fixture-cleaned phase still completed. Repository source remained unchanged. [Sanitized control result](evidence/TLS01_NEGATIVE_CONTROL.json) records the command, source identity/hash and expected failure. This confirms a generic connection rejection is not accepted as native certificate evidence; no production trust bypass or unsafe mutation is involved.

A deployment target printed by a compiler/test runner is not evidence of executing that minimum OS. Local results here execute on macOS 15.8.1, not macOS 14.

## Evidence handoff and remaining gaps

This contributes a native macOS owned-session untrusted-certificate case to ENV-02/T3. It does not establish a successful system-trusted handshake, independent hostname-mismatch rejection, borrowed-session/profile coverage, macOS 14 execution, mobile/TV minimum runtimes, physical mobile-device behavior or all challenge methods. A rejected self-signed certificate cannot stand in for a deliberately mismatched certificate with an otherwise trusted chain.

#62/#63 retain the complete ENV-02 contract and actual target access. Controlled system-trusted HTTPS remains unavailable/unknown, and the owner continues to defer physical-device connection. Existing host/device inventory is unchanged; usable host DDI metadata is not per-device execution proof. #86 requires this selected regression's acceptance as well as native/platform/resource reconciliation; #29 retains explicit owner-risk disposition and publication authorization.

Forward assessment: one bounded implementation issue, TLS-01 / #104, is justified by executable local negative evidence that was previously missing. Its Order 20.75 precedes blocked I21/I22 execution without making their access preparation depend on it. No additional generic issue, milestone, production refactor, timer change, advanced TLS feature or tool upgrade is justified. Keep F2 open and retry-first F3 deferred.

## Candidate quality checks

Source integrity passed package/source/workflow policies, JSON/local links and all four CI-helper tests. DocC built the package/tests and converted with warnings as errors; the public NetworkKit graph remains 319 records. The full local 218-test result and isolated two-assertion negative control above accompany the same candidate. No production refactor or additional generic issue is justified. The live project overview was consolidated to one current priority list while preserving maintenance, parallel-work and quality rules; detailed incident/acceptance history remains in issues/PRs and repository evidence.
