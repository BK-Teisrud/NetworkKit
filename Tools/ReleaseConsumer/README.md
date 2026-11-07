# Unsigned release consumer rehearsal

This minimal iOS app links the public NetworkKit product into its application target. It starts no network requests and contains no credentials, optional capabilities or publication automation. It is verification tooling, not an additional library product or sample application promised for distribution.

The project uses the repository package, Swift 6 and current iOS 18 minimum. Signing is disabled by default. The bundle identifier is unregistered; checking in this project does not authorize registration, installation, signing or distribution.

```sh
xcodebuild -project Tools/ReleaseConsumer/NetworkKitReleaseConsumer.xcodeproj \
  -scheme NetworkKitReleaseConsumer -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath /private/tmp/NetworkKitReleaseConsumer.xcarchive \
  CODE_SIGNING_ALLOWED=NO archive
```

For reproducible evidence, build from a clean source snapshot and record its commit and tooling hashes. Inspect the archive's SDK resource bundle and privacy manifest, and verify that the archived binary and dSYM UUIDs match. A stripped binary need not expose SDK symbols through `nm`; inspect the matching dSYM instead.

Generate the aggregate privacy report through Xcode Organizer. A successful file export alone is insufficient: render and review the actual PDF. The real 2026-10-31 export was blank, consistent with its verified empty collected-data declarations. A separate unsigned, nonshipping positive control added a synthetic Crash Data declaration only to a disposable copy of the SDK manifest. Xcode’s rendered report attributed that declaration to the SDK resource bundle, confirming aggregation at this placement. That historical preparation used empty reason arrays. The current SDK manifest declares FileTimestamp/C617.1 for fstat; tracking remains disabled and collected-data/domain arrays remain empty. A current consumer archive must be verified separately. Aggregate parsing is not complete binary API analysis or App Store acceptance. See [archive preparation evidence](../../docs/planning/evidence/F2_CONSUMER_ARCHIVE_PREPARATION_2026-10-31.json).

Formal #64 acceptance retains its #63/#86 dependencies. This preparation does not authorize a tag, release, App Store upload or owner risk acceptance.

## Formal rehearsal follow-up

[The #64 rehearsal](../../docs/planning/RELEASE_REHEARSAL_2026-10-31.md) builds the accepted revision from a clean detached checkout, verifies the fresh unsigned archive and matching binary/dSYM/manifest, and rechecks the accepted report/positive control only after executable/manifest/consumer inputs are proven identical. It also verifies a separate public remote-revision consumer. The earlier preparation is not presented as a newly generated report or distribution. Evidence PR/main acceptance remains required before #64/#27/F2 closure; #132/#29 publication gates remain.
