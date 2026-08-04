import CoreUIBridge
import DualKakaoTalkCore
import XCTest

final class AssetCatalogPatcherTests: XCTestCase {
    func testRejectsNonAllowlistedSourceFingerprint() throws {
        let source = temporaryFile()
        let destination = source.deletingLastPathComponent().appendingPathComponent("copy.car")
        try Data("synthetic".utf8).write(to: source)
        let plan = AssetCatalogMutationPlan(sourceCatalog: source, destinationCatalog: destination, allowedSourceSHA256: [])
        XCTAssertThrowsError(try AssetCatalogPatcher.validate(plan: plan)) { error in
            XCTAssertEqual(error as? AssetCatalogPatcherError, .sourceNotAllowlisted)
        }
    }

    func testRejectsMutationOfSourceInPlace() throws {
        let source = temporaryFile()
        try Data("synthetic".utf8).write(to: source)
        let plan = AssetCatalogMutationPlan(sourceCatalog: source, destinationCatalog: source, allowedSourceSHA256: [try SHA256.file(at: source)])
        XCTAssertThrowsError(try AssetCatalogPatcher.validate(plan: plan)) { error in
            XCTAssertEqual(error as? AssetCatalogPatcherError, .destinationMustDiffer)
        }
    }

    func testRejectsWrongTargetCountAndDimensions() {
        let one = AssetCatalogRendition(name: "MenuIcon", scale: 1, width: 20, height: 20, hasInternalLink: false)
        XCTAssertThrowsError(try AssetCatalogPatcher.validateTargetRenditions([one]))
        let invalid = (0..<16).map { _ in AssetCatalogRendition(name: "MenuIcon", scale: 1, width: 21, height: 20, hasInternalLink: false) }
        XCTAssertThrowsError(try AssetCatalogPatcher.validateTargetRenditions(invalid))
    }

    func testRejectsUnknownNameAndInternalLink() {
        let unknown = (0..<16).map { _ in AssetCatalogRendition(name: "NotAllowed", scale: 1, width: 20, height: 20, hasInternalLink: false) }
        XCTAssertThrowsError(try AssetCatalogPatcher.validateTargetRenditions(unknown))
        let linked = (0..<16).map { _ in AssetCatalogRendition(name: "MenuIcon", scale: 1, width: 20, height: 20, hasInternalLink: true) }
        XCTAssertThrowsError(try AssetCatalogPatcher.validateTargetRenditions(linked))
    }

    func testBridgeReturnsBoundedFailureForSyntheticCatalogWhenFrameworkOrSelectorsAreUnavailable() {
        var values: NSArray?
        var error: NSError?
        let result = CoreUIBridgeCopyNamedImageRenditions(temporaryFile(), &values, &error)
        XCTAssertFalse(result)
        XCTAssertNotNil(error)
        XCTAssertTrue((1...3).contains(error?.code ?? -1))
    }

    private func temporaryFile() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("car")
    }
}
