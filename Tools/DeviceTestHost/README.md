# NetworkKit iOS device test host

Optional public checks: [NET-01](../PublicHTTPSChecks/README.md) adds the separate PublicHTTPSChecks target/scheme using this same host. The default scheme still executes only the shared regression suite. Public checks are manually selected; CI compiles the optional route without executing external-service tests.

PREP-02 / [#113](https://github.com/BK-Teisrud/NetworkKit/issues/113) supplies an app-hosted test route after the package's system-xctest host was rejected on a physical destination. This is local verification infrastructure, not a distributed app or another library product. The package, public APIs and support minima remain unchanged.

## Structure and permissions

- NetworkKitDeviceHost is a minimal UIKit app with a static label. Its app code never creates a client or sends requests. Swift 6, iOS 17 deployment, iPhone/iPad families; no SwiftUI dependency.
- NetworkKitDeviceTests links the local package's NetworkKit product and loads into that app through TEST_HOST/BUNDLE_LOADER. No remote package dependency, copied production source or duplicated tests.
- The shared scheme includes every existing Tests/NetworkKitTests Swift file exactly once. macOS-only child-process/native-TLS code retains its original compile-time guards. The iOS simulator run passed 215 tests in 26 suites, while macOS retains 218/28. Actual physical/minimum claims require their separate execution records.
- Debug uses ONLY_ACTIVE_ARCH=YES so the app/test target agrees with the local Swift-package build for an Intel-hosted simulator. The generic physical build still targets arm64. No minimum-OS change is used to solve an architecture mismatch.
- No custom entitlements, local-network usage key, ATS exception, app group, background capability, tracking or telemetry. Existing iOS tests are predominantly deterministic/URLProtocol/configuration checks; native macOS wire/TLS assertions do not become native iOS tests merely by being hosted.
- Proposed bundle IDs: no.teisruddevelopment.NetworkKitDeviceHost and no.teisruddevelopment.NetworkKitDeviceTests. No identifiers are registered in an Apple account by checking in this project. Signing is Manual; the host/test targets reference only the private NETWORKKIT_DEVICE_PROFILE placeholder. Team, certificate identity, profile and device IDs are supplied privately only when explicitly selected and authorized. No provisioning-update option is enabled.

## Unsigned review and simulator verification

From the repository root, build the concrete device artefact before any signing/install decision:

```sh
xcodebuild -project Tools/DeviceTestHost/NetworkKitDeviceHost.xcodeproj \
  -scheme NetworkKitDeviceHost -configuration Debug \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /private/tmp/networkkit-device-unsigned \
  CODE_SIGNING_ALLOWED=NO build-for-testing
```

For a selected installed simulator, use the same project/scheme with a concrete iOS Simulator destination, a separate derived-data directory and result bundle, CODE_SIGNING_ALLOWED=NO, -parallel-testing-enabled NO and test. Do not install runtimes automatically. Actual results are recorded in [the preparation evidence](../../docs/planning/IOS_DEVICE_TEST_HOST.md); compilation alone is no execution result.

CI source integrity checks complete membership, local-package-only dependency and host wiring. Negative controls remove one test file, substitute a tool host and substitute a remote package; each must fail. ios-core additionally builds this project for generic iOS without credentials before the existing package simulator matrix. This adds no CI signing/deployment or new workflow/runner. Future test files must be added to the Sources phase and group; the integrity guard prevents silent omission.

## Authorized physical execution

1. Confirm connected/unlocked device, active DDI services and actual OS/build. Obtain explicit approval for this concrete host's signing/install/test route. The earlier package-test approval does not install this new app.
2. Select an existing valid development identity/team and an existing profile that permits the host/test identifiers on that device. Inspect identifiers locally. Do not create/register/download a new profile or certificate, change account settings, or use automatic provisioning without a separate decision. If no suitable existing profile is available, stop with that exact obstacle.
3. Build-for-testing for the concrete physical destination with CODE_SIGNING_ALLOWED=YES and the selected private signing settings. The checked-in default is Manual; use NETWORKKIT_DEVICE_PROFILE only for a compatible manually managed profile. An already present Xcode-managed profile requires a local CODE_SIGN_STYLE=Automatic override with that profile placeholder empty; omit -allowProvisioningUpdates and -allowProvisioningDeviceRegistration so xcodebuild cannot create/update portal profiles, App IDs, certificates or device registrations. Supply the existing team and development-identity selector privately. Before installation, verify signatures and that the embedded profile UUID equals the existing prevalidated profile, not merely that the build succeeded. Stop if it differs or requires provisioning changes.
4. Use the generated xctestrun with test-without-building for that device, -parallel-testing-enabled NO and a fresh private result bundle. Preserve failures. Inspect the actual xcresult summary: Passed, nonzero tests, every test passed, zero failed/skipped/expected failures. Check the full log for unexpected restarts, time-limit failures and incomplete suites. Never report success from an install/build alone.
5. Record candidate commit/source hashes, exact toolchain/device model/OS/build, selected test-plan/host and sanitized results. Keep raw logs/xcresults, account metadata, profiles and device IDs private. Explicitly record fixtures/scenario IDs actually exercised; this route does not supply unavailable system-trusted HTTPS or minimum-runtime evidence.
6. After execution, stop the verification host and remove only this installed host/test artefact and its synthetic data when cleanup is selected. Never erase a device, clear shared stores, modify real app data or change trust/settings. Local derived data/results may be retained privately for diagnosis and later removed by their exact task paths.

## Included sources and exclusions

All existing Swift test/helper files are referenced directly, including PrivacyManifestTests; its Bundle.module access resolves the package resource, not a separate copied manifest. See [the inventory](../../docs/planning/TEST_INVENTORY.md) for every test declaration. The three excluded macOS-only test declarations are FixtureProcessTests.missingReadinessFailsAndStopsTheChild, FixtureProcessTests.childIgnoringTerminationIsForceStoppedWithinTheBound and NativeTLSTests.untrustedCertificateIsRejectedThroughBothPublicInputs; exact current source names are authoritative. These are compile-time platform exclusions, not skipped iOS tests. Other guarded branches preserve their documented scripted/configuration evidence instead of asserting macOS network behavior.

F2 ENV-01–07, real minimum runtimes, iPad/Watch/TV execution, trusted HTTPS/hostname mismatch, transitions, target resources, aggregate archive/privacy report and owner release decisions retain their existing task owners. No new app-host feature closes #63/#86 automatically.

## Unsigned Watch and TV preparation

Generate an ignored platform variant from the validated shared project:

```sh
python3 scripts/ci/prepare_device_host.py --platform watchOS
python3 scripts/ci/prepare_device_host.py --platform tvOS
```

The generated projects are under `.build/device-host-watchos` and `.build/device-host-tvos`. They reuse every shared regression and native source, use minimum watchOS 10 / tvOS 17, and disable signing by default. CI compiles both schemes for generic physical destinations; it does not install them or run public-service tests. The generator records its source hashes and validates the original host before deriving a variant. There is one shared source of test membership, rather than three independently maintained project files.

The Watch host uses a minimal SwiftUI lifecycle; the iOS/TV host uses UIKit. This affects the verification app only. Physical Watch execution explicitly selects the 14 public HTTPS declarations; its ordinary app context cannot be assumed to support the seven NWListener local declarations. See [NET-04 applicability](../../docs/planning/NET04_NATIVE_CONTROLS.md).

On 2026-10-31 the owner authorized registering exactly the three existing test bundle IDs and this iPad, generating three iPad-only development profiles with the existing certificate, and signing/installing/running the test packages. Apple's locked default In-App Purchase selection was explicitly approved; no purchase feature, optional capability, new certificate or distribution agreement was added. Profile identifiers, device identifiers and signing details stay private. This authorization does not cover registering or changing Watch/TV devices or profiles.

## Explicit manual transition app

[Manual transition procedure](../../docs/planning/MANUAL_TRANSITION_CHECKS.md) provides a separate unsigned generated app for iOS/iPadOS, macOS, Watch and TV. It uses the existing host ID/profile boundary and starts no request until an owner selects a check. The app records scene/path observations, four finite public calls, shutdown and a sample after original budgets. It never changes connectivity settings or declares acceptance. Required CI compiles all four variants; actual signed deployment, owner-driven transitions and report review remain explicit #63 work. No XCTest suite is replaced or filtered by this preparation.

## Shared source organization

Shared unit tests use source-group-relative paths under Tests/NetworkKitTests; native sources retain their relative subdirectories under the separate probe target. After a move/add/remove, run `python3 scripts/ci/sync_device_sources.py` and review the generated membership diff. Stable identifiers preserve unchanged references; ambiguous source groups/collisions fail. CI runs the read-only validator, rejecting omissions, flattening and duplicate references. This command changes source membership only, never signing/account settings.
