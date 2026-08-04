import Foundation

public struct OfficialAppFacts: Codable, Equatable, Sendable {
    public let path: String
    public let bundleIdentifier: String
    public let shortVersion: String
    public let buildVersion: String
    public let executableName: String
    public let assetsSHA256: String
}

public enum OfficialAppInspector {
    public static let supportedPath = "/Applications/KakaoTalk.app"
    public static let expectedBundleIdentifier = "com.kakao.KakaoTalkMac"

    public static func inspect(path: String = supportedPath) throws -> OfficialAppFacts {
        let appURL = URL(fileURLWithPath: path, isDirectory: true)
        let plistURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard FileManager.default.fileExists(atPath: plistURL.path) else {
            throw InspectionError.appNotFound(path)
        }

        let plistData = try Data(contentsOf: plistURL)
        guard let plist = try PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any],
              let bundleIdentifier = plist["CFBundleIdentifier"] as? String,
              let shortVersion = plist["CFBundleShortVersionString"] as? String,
              let buildVersion = plist["CFBundleVersion"] as? String,
              let executableName = plist["CFBundleExecutable"] as? String
        else {
            throw InspectionError.invalidInfoPlist
        }
        guard bundleIdentifier == expectedBundleIdentifier else {
            throw InspectionError.unexpectedBundleIdentifier(bundleIdentifier)
        }

        let executableURL = appURL.appendingPathComponent("Contents/MacOS/\(executableName)")
        guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            throw InspectionError.missingExecutable(executableURL.path)
        }

        let assetsURL = appURL.appendingPathComponent("Contents/Resources/Assets.car")
        guard FileManager.default.fileExists(atPath: assetsURL.path) else {
            throw InspectionError.missingAssetsCatalog(assetsURL.path)
        }

        return OfficialAppFacts(
            path: appURL.path,
            bundleIdentifier: bundleIdentifier,
            shortVersion: shortVersion,
            buildVersion: buildVersion,
            executableName: executableName,
            assetsSHA256: try SHA256.file(at: assetsURL)
        )
    }
}

public enum InspectionError: LocalizedError {
    case appNotFound(String)
    case invalidInfoPlist
    case unexpectedBundleIdentifier(String)
    case missingExecutable(String)
    case missingAssetsCatalog(String)

    public var errorDescription: String? {
        switch self {
        case .appNotFound(let path): "Official KakaoTalk was not found at \(path)"
        case .invalidInfoPlist: "KakaoTalk Info.plist is invalid"
        case .unexpectedBundleIdentifier(let value): "Unexpected bundle identifier: \(value)"
        case .missingExecutable(let path): "KakaoTalk executable is missing: \(path)"
        case .missingAssetsCatalog(let path): "KakaoTalk Assets.car is missing: \(path)"
        }
    }
}
