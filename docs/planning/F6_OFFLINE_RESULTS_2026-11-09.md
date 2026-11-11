# F6 offline Phase A results — 2026-11-09

Tracking #90 / PR #177. Owner explicitly approved only isolated Phase A code/execution against scope commit e99857ead97676fb139240f3100feb3ef573348f. No production or Phase B start permission.

## Outcome

Four initial Swift 6 type-check commands passed with warnings treated as errors. Targets: x86_64 macOS 15, arm64 iOS 18 simulator, arm64 tvOS 18 simulator and arm64 watchOS 11 simulator; SDKs 26.2, Xcode 26.3 build 17C529, Swift 6.2.4, Intel macOS 15.8.1. Security/CryptoKit and selected Network declaration forms were accepted; no binary/host was linked or launched. Watch native declarations were conditionally omitted, not executed or proven unavailable by the compiler.

All 64 named pure cases passed: 24 signing, 24 framing and 16 policy-model cases. The Python verifier builds the fixed profile base separately from the signer and checks payload digest, MAC, required coverage, synthetic clock/replay/key cases. Primitive cryptography uses the same standard library on both paths. No Swift cryptographic function was executed and no general RFC conformance/interoperability claim follows.

Zero network attempts, device/simulator boots, Keychain/Enclave access, certificate/identity creation, trust changes, entitlements, app installs or paid services. Four compiler and 32 case correction-reserve slots remain unused; no new scenario is authorized by that balance. No original failure was discarded; this initial batch had no failures. Original private logs/ledger remain retained. [Public source/hash/result ledger](evidence/F6/OFFLINE_PHASE_A_2026-11-09.json) records exact named outcomes and original-input hashes.

## Source-based ownership review and implications

The candidate signing handle is an immutable Sendable key identifier plus Sendable closure. Compilation accepts that form, but does not prove that a provider closure pins the same physical key across rotation or cooperates with cancellation. The identity reference deliberately has no Sendable conformance: crossing SecIdentity/SecCertificate references safely through async provider/delegate boundaries remains unresolved. Do not fix that uncertainty by adding unchecked Sendable solely to satisfy the compiler.

Pure admission assertions illustrate selected before-admission/closed/duplicate/late-output rules. They do not establish native callback exactly-once completion, actual parallel actor races, permission classification or OS cleanup. Replay verification used a sequential in-memory set; production atomic multiworker replay protection remains a server duty and unverified.

The parser tests exercise specified bounded prefix/delimiter examples. They do not establish throughput, native read chunk sizes, sustained buffering, application framing compatibility or malicious-peer resource behavior. The empty-path/query/IPv6 signing cases compare pure supplied strings; Foundation's actual wire reconstruction remains unproved. Neither a string agreement nor successful HMAC verification is evidence that a real server reconstructs the same target URI.

## Plan and quality disposition

Retain the approved broad scope, all sixteen inventory items and one-plan/one-delivery PR target. No new module, dependency, OS-floor increase or broad refactor is justified by these results. Existing root Sources/Tests/Compatibility/Package.swift/privacy/other tools remain unchanged. No production implementation issue is marked Ready. #13/#18 stay open; #29/#132 publication barriers stay unchanged.

Next: resolve identity ownership/concurrency and pin representation; finalize exact public API and selected coverage; specify the native Phase B fixture/route/budget and ask for its separate authority. Current results cannot replace controlled TLS/mTLS, native signed-request verification, peer-to-peer/multicast entitlement/permission evidence or an explicit owner scope decision. Keep work in PR #177 until the complete planning criteria and PR/main verification are met.
