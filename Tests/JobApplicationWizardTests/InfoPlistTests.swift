import XCTest

final class InfoPlistTests: XCTestCase {

    func testCalendarsFullAccessUsageDescriptionPresent() throws {
        let bundle = Bundle.main
        // In test context, load Info.plist from the source tree relative to the test bundle.
        // The test bundle's resource path resolves the project Info.plist via the build system.
        let value = bundle.object(forInfoDictionaryKey: "NSCalendarsFullAccessUsageDescription") as? String
        // If running via swift test (no app bundle), fall back to loading the file directly.
        let resolved: String?
        if let v = value {
            resolved = v
        } else {
            // Locate Info.plist relative to the source root, two levels up from the test executable.
            let sourceRoot = URL(fileURLWithPath: #file)
                .deletingLastPathComponent()  // InfoPlistTests.swift -> JobApplicationWizardTests/
                .deletingLastPathComponent()  // JobApplicationWizardTests/ -> Tests/
                .deletingLastPathComponent()  // Tests/ -> project root
            let plistURL = sourceRoot.appendingPathComponent("Info.plist")
            let data = try Data(contentsOf: plistURL)
            let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
            resolved = plist?["NSCalendarsFullAccessUsageDescription"] as? String
        }
        XCTAssertEqual(
            resolved,
            "Job Application Wizard reads your calendar to let you tag existing events as interview rounds."
        )
    }
}
