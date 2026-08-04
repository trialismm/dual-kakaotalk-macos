import Foundation
import XCTest
@testable import DualKakaoTalkCore

final class InstallerTests: XCTestCase {
    func testPrivilegedRequestEncodesOnlyFixedGrammarKeys() throws {
        let request = makeRequest()
        let data = try PropertyListEncoder().encode(request)
        let object = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        let dictionary = try XCTUnwrap(object as? [String: Any])

        XCTAssertEqual(
            Set(dictionary.keys),
            Set([
                "schema",
                "version",
                "nonce",
                "sourcePath",
                "destinationPath",
                "stagedPath",
                "sourceCatalogSHA256",
                "destinationCatalogSHA256",
            ])
        )
    }

    func testPrivilegedRequestRetainsFixedIdentityAndDigestValues() throws {
        let request = makeRequest()
        let decoded = try PropertyListDecoder().decode(
            PrivilegedInstallRequest.self,
            from: PropertyListEncoder().encode(request)
        )

        XCTAssertEqual(decoded.schema, 1)
        XCTAssertEqual(decoded.sourcePath, OfficialAppInspector.supportedPath)
        XCTAssertEqual(decoded.destinationPath, KakaoTalkWorkInstaller.destinationPath)
        XCTAssertEqual(decoded.stagedPath, "/tmp/DualKakaoTalk-501-fixture/KakaoTalkWork.app")
        XCTAssertEqual(decoded.nonce, "9A53B2F0-5F47-4F64-9F5C-49F46A468E97")
        XCTAssertEqual(decoded.sourceCatalogSHA256, String(repeating: "a", count: 64))
        XCTAssertEqual(decoded.destinationCatalogSHA256, String(repeating: "b", count: 64))
    }

    func testPrivilegedRequestRejectsMissingRequiredField() throws {
        var object = try encodedDictionary(makeRequest())
        object.removeValue(forKey: "destinationCatalogSHA256")
        let data = try PropertyListSerialization.data(fromPropertyList: object, format: .binary, options: 0)

        XCTAssertThrowsError(try PropertyListDecoder().decode(PrivilegedInstallRequest.self, from: data))
    }

    func testPrivilegedRequestDecoderDoesNotMakeExtraKeysPartOfTheRequest() throws {
        var object = try encodedDictionary(makeRequest())
        object["unexpectedAuthority"] = "/Applications/Other.app"
        let data = try PropertyListSerialization.data(fromPropertyList: object, format: .binary, options: 0)
        let decoded = try PropertyListDecoder().decode(PrivilegedInstallRequest.self, from: data)

        XCTAssertEqual(decoded.sourcePath, OfficialAppInspector.supportedPath)
        XCTAssertEqual(decoded.destinationPath, KakaoTalkWorkInstaller.destinationPath)
        XCTAssertEqual(decoded.stagedPath, "/tmp/DualKakaoTalk-501-fixture/KakaoTalkWork.app")
    }

    func testPreparedRecoveryRemovesOnlyStagingAndJournal() throws {
        XCTAssertEqual(
            try recoveryOperations(phase: "prepared", destinationExists: true, backupExists: false, stagedExists: true),
            [.removeStaged, .removeJournal]
        )
    }

    func testPreparedPhaseRecoversCrashAfterBackupRename() throws {
        XCTAssertEqual(
            try recoveryOperations(phase: "prepared", destinationExists: false, backupExists: true, stagedExists: true),
            [.restoreBackup, .removeStaged, .removeJournal]
        )
    }

    func testBackupPhaseAlwaysRestoresPredecessor() throws {
        XCTAssertEqual(
            try recoveryOperations(phase: "predecessor-backed-up", destinationExists: false, backupExists: true, stagedExists: true),
            [.restoreBackup, .removeStaged, .removeJournal]
        )
        XCTAssertEqual(
            try recoveryOperations(phase: "predecessor-backed-up", destinationExists: true, backupExists: false, stagedExists: false),
            [.removeDestination, .removeJournal]
        )
    }

    func testInstalledPhaseRollsBackFreshAndUpdateInstalls() throws {
        XCTAssertEqual(
            try recoveryOperations(phase: "installed", destinationExists: true, backupExists: true, stagedExists: false),
            [.removeDestination, .restoreBackup, .removeJournal]
        )
        XCTAssertEqual(
            try recoveryOperations(phase: "installed", destinationExists: true, backupExists: false, stagedExists: false),
            [.removeDestination, .removeJournal]
        )
    }

    func testVerifiedPhaseCommitsOrRestoresMissingDestination() throws {
        XCTAssertEqual(
            try recoveryOperations(phase: "verified", destinationExists: true, backupExists: true, stagedExists: false),
            [.removeBackup, .removeJournal]
        )
        XCTAssertEqual(
            try recoveryOperations(phase: "verified", destinationExists: false, backupExists: true, stagedExists: false),
            [.restoreBackup, .removeJournal]
        )
        XCTAssertThrowsError(
            try recoveryOperations(phase: "verified", destinationExists: false, backupExists: false, stagedExists: false)
        )
    }

    func testUnknownRecoveryPhaseFailsClosed() {
        XCTAssertThrowsError(
            try recoveryOperations(phase: "future", destinationExists: true, backupExists: true, stagedExists: true)
        )
    }
    private func makeRequest() -> PrivilegedInstallRequest {
        PrivilegedInstallRequest(
            version: "1.2.3",
            nonce: "9A53B2F0-5F47-4F64-9F5C-49F46A468E97",
            sourcePath: OfficialAppInspector.supportedPath,
            destinationPath: KakaoTalkWorkInstaller.destinationPath,
            stagedPath: "/tmp/DualKakaoTalk-501-fixture/KakaoTalkWork.app",
            sourceCatalogSHA256: String(repeating: "a", count: 64),
            destinationCatalogSHA256: String(repeating: "b", count: 64)
        )
    }

    private func encodedDictionary(_ request: PrivilegedInstallRequest) throws -> [String: Any] {
        let data = try PropertyListEncoder().encode(request)
        let object = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        return try XCTUnwrap(object as? [String: Any])
    }
}
