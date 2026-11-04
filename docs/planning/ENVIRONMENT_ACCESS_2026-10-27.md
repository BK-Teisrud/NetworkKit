# Environment access refresh — 2026-10-27

Scope: read-only preparation under [I21 / #62](https://github.com/BK-Teisrud/NetworkKit/issues/62) and [I22 / #63](https://github.com/BK-Teisrud/NetworkKit/issues/63), after RES-01 acceptance. Product baseline: `0922f40dac22cbecd62196024e3abf8f10ad352d`, main run 40459485079 succeeded with five complete runtime test results, release smoke and control type-check, without timeout/restart. #100 is complete for local attribution; actual target resources and explicit risk disposition remain open.

This refresh corrects the earlier unknown device inventory using local CoreDevice records. It does not establish fresh device communication, successful deployment or passing physical/minimum-runtime scenarios. The owner chose “not now; continue preparations” when offered a cable connection to the iPhone. Device execution remains deferred.

## Sanitized observations

[Machine-readable evidence](evidence/ENVIRONMENT_ACCESS_2026-10-27.json) contains only model/platform/version/readiness fields. Commands: `xcrun simctl list runtimes --json`, `xcrun devicectl list devices --json-output ...`, `xcrun devicectl list preferredDDI --timeout 10 --json-output ...`, `sw_vers`, `uname -m`, and `sysctl -n hw.model`. Raw discovery files stay local; device names, identifiers, serials, network addresses and user paths are omitted.

| Target | Observed record | Current preparation result |
| --- | --- | --- |
| Local Mac | MacBookPro15,2, x86_64; macOS 15.8.1 / 24H32; Xcode 26.3 / 17C529 | Local native macOS evidence exists; this is not macOS 14 access |
| iPhone | iPhone 17 Pro; iOS 27.2 / 24B119 | Pairing record present; Developer Mode enabled; local-network transport recorded, tunnel disconnected, DDI services unavailable |
| iPad | iPad Pro (11-inch) (3rd generation); iPadOS 27.0.1 / 24A446 | Pairing record present; Developer Mode disabled; tunnel unavailable, DDI services unavailable; transport not reported |
| Apple Watch | Apple Watch Ultra 2; watchOS 26.6 / 23U67 | Pairing record present; Developer Mode disabled; local-network transport recorded, tunnel disconnected, DDI services unavailable |
| Apple TV | Not listed by this CoreDevice query | Availability, exact model, OS/build and connection remain unknown; absence from this list is not proof that no TV is available |
| Other minimum-version hosts/devices | None established | Existing older-system access gap remains open |

OS/readiness fields are stored/discovered records, not a fresh on-device version check. Refresh them after a usable connection. Existing pairing records are not consent to install, launch or change settings. No pairing, Developer Mode change, OS/tool/runtime installation, app deployment or device test occurred in this refresh.

Installed runtime inventory is unchanged from PREP-01: iOS 18.2/18.5/26.2, tvOS 18.2/18.5/26.2 and watchOS 11.2/11.5/26.2, each reporting available. iPhone/iPad destinations share the iOS family but need separate evidence. No iOS/iPadOS 17, watchOS 10 or tvOS 17 runtime is installed; no macOS 14 execution environment is established. “Available” does not prove a runtime can boot or execute this package.

## Tool and developer-service readiness

The local preferred-DDI query reports usable, host-compatible iOS/watchOS/tvOS images with build 17C529 and CoreDevice 506.7. Its help explicitly warns that a preferred image can be returned even when unusable; this refresh records the actual metadata flags, not selection alone. These are host/platform facts, not successful mounting or compatibility with each discovered device OS. Per-device DDI services remain unavailable in the records.

Apple's [Xcode requirements table](https://developer.apple.com/xcode/system-requirements/) lists SDK 26.2 and a macOS 15.6-or-later host range for Xcode 26.3. Its device-support column has open-ended “or later” ranges: an OS version above the SDK alone does not prove incompatibility. Conversely, that broad table does not prove this particular host/DDI/device combination works. Connection, developer-service and deployment/test-runner checks are still required. The table also lists macOS 26.6 or later for Xcode 27.1; that is a contingency requiring a separate tool/host decision, not a reason to assume an upgrade is necessary now.

Keep package minima and tools requirements unchanged. A newer secondary execution toolchain, if needed, must record exact identities and supplement rather than silently replace the verified Xcode 26.3/Swift 6.2.4 CI baseline. No RC/beta toolchain, host upgrade or purchase is selected.

## Next executable preparation sequence

1. Keep #62 and #63 Blocked for execution while their environment Ready criteria are unsatisfied. They remain independent; lack of minimum-runtime access does not prohibit useful newer-device evidence once its own prerequisites are met.
2. At a suitable time, connect/unlock the iPhone using the owner's chosen route and refresh sanitized model/OS/connection/service status. Start with that device because its record already has Developer Mode enabled. Establish actual Xcode/DDI support before choosing a consumer/test-host route. Any system-setting change, installation, new toolchain or signing/deployment setup must be made concrete for an appropriate decision first.
3. Establish iPad/Watch readiness and any paired-host needs separately. Obtain Apple TV model/OS/build/availability. Do not infer a phone result applies to the other families.
4. For #62, establish accessible official minimum-version runtimes or devices and a macOS 14 execution host/route. Availability/download/signing/architecture and test-runner support must be confirmed before promising execution. Another Xcode version or Mac is only a candidate route; no installation or purchase is authorized by this assessment.
5. Select a controlled, reachable, system-trusted HTTPS fixture and independent invalid-chain/hostname-mismatch cases under the [security review contract](SECURITY_PRIVACY_REVIEW.md). Access remains unavailable/unknown. A Mac loopback address is not a physical-device endpoint. Do not substitute an uncontrolled public site or a trust bypass.
6. Use ENV-01–ENV-07 from [environment readiness](ENVIRONMENT_READINESS.md), recording exact candidate/toolchain/OS/harness/fixture identity and expected/observed results. Apply [RES-01 rate/budget/post-deadline distinctions](REPEATED_CALL_MEMORY.md) when measuring resources. Candidate deployment and actual physical execution are separate work from inventory.

The local Mac already supplied native HTTP reuse, cancellation and resource evidence in I20/RES-01. Reuse only the applicable recorded evidence with its original source identity; reconcile source changes/revalidation for the final candidate. Do not relabel these runs as macOS 14, native HTTPS, physical mobile devices or complete network-transition scenarios. This avoids both duplicate work and unsupported acceptance.

## Forward assessment

No additional issue or milestone is justified by discovering records and readiness gaps: #62/#63 already own environment access and actual execution, #86 reconciles evidence/risk, #64 handles archive/privacy/rehearsal, and #29 publication. The next practical dependency is available device/host access and controlled HTTPS, not another networking feature. Keep retry-first F3 planning deferred. This preparation PR closes neither platform issue and grants no release or residual-risk acceptance.
