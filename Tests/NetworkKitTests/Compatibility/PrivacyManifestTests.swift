import Foundation
import Testing
@testable import NetworkKit

@Suite struct PrivacyManifestTests {
    @Test func bundledManifestMatchesReviewedSDKPractices() throws {
        let url = try #require(Bundle.module.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let data = try Data(contentsOf: url)
        let manifest = try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        #expect(Set(manifest.keys) == ["NSPrivacyTracking", "NSPrivacyTrackingDomains",
            "NSPrivacyCollectedDataTypes", "NSPrivacyAccessedAPITypes"])
        #expect((manifest["NSPrivacyTracking"] as? Bool) == false)
        for key in ["NSPrivacyTrackingDomains", "NSPrivacyCollectedDataTypes"] {
            let entries = try #require(manifest[key] as? [Any])
            #expect(entries.isEmpty)
        }
        // fstat inspects only the app-temporary download file's kind/size after preservation.
        // Apple classifies fstat as FileTimestamp even when no timestamp field is consumed.
        let apis = try #require(manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        #expect(apis.count == 1)
        let file = try #require(apis.first)
        #expect(Set(file.keys) == ["NSPrivacyAccessedAPIType", "NSPrivacyAccessedAPITypeReasons"])
        #expect(file["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryFileTimestamp")
        #expect(file["NSPrivacyAccessedAPITypeReasons"] as? [String] == ["C617.1"])

    }
}
