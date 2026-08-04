import Foundation

public struct InstallRequest: Sendable {
    public let sourceApp: URL
    public let destinationApp: URL
    public let allowedAssetsSHA256: Set<String>
    public let dockIcon: URL?

    public init(sourceApp: URL, destinationApp: URL, allowedAssetsSHA256: Set<String>, dockIcon: URL? = nil) {
        self.sourceApp = sourceApp
        self.destinationApp = destinationApp
        self.allowedAssetsSHA256 = allowedAssetsSHA256
        self.dockIcon = dockIcon
    }
}

public enum InstallerError: LocalizedError {
    case identicalPaths
    case unsupportedSourcePath(String)
    case missingResource(String)
    case commandFailed(String)

    public var errorDescription: String? {
        switch self {
        case .identicalPaths: "Source and destination paths must differ."
        case .unsupportedSourcePath(let path): "Install the official KakaoTalk app at /Applications/KakaoTalk.app (received: \(path))."
        case .missingResource(let path): "Required app resource is missing: \(path)"
        case .commandFailed(let message): message
        }
    }
}

public protocol InstallCommandRunning {
    func run(_ executable: String, _ arguments: [String]) throws
}

public struct ProcessInstallCommandRunner: InstallCommandRunning {
    public init() {}

    public func run(_ executable: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let detail = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            throw InstallerError.commandFailed(detail.isEmpty ? "Command failed: \(executable)" : detail)
        }
    }
}

public enum KakaoTalkWorkInstaller {
    public static let destinationPath = "/Applications/KakaoTalkWork.app"
    public static let bundleIdentifier = "com.kakao.KakaoTalkWorkMac"
    public static let executableName = "KakaoTalkWork"

    public static func install(
        _ request: InstallRequest,
        fileManager: FileManager = .default,
        runner: InstallCommandRunning = ProcessInstallCommandRunner()
    ) throws {
        let source = request.sourceApp.standardizedFileURL
        let destination = request.destinationApp.standardizedFileURL
        guard source != destination else { throw InstallerError.identicalPaths }
        guard source.path == OfficialAppInspector.supportedPath else {
            throw InstallerError.unsupportedSourcePath(source.path)
        }
        let facts = try OfficialAppInspector.inspect(path: source.path)
        let parent = destination.deletingLastPathComponent()
        let nonce = UUID().uuidString
        let staged = parent.appendingPathComponent(".KakaoTalkWork.stage-\(nonce).app")
        let backup = parent.appendingPathComponent(".KakaoTalkWork.backup-\(nonce).app")
        var movedExisting = false

        defer {
            try? fileManager.removeItem(at: staged)
            if fileManager.fileExists(atPath: backup.path), !movedExisting {
                try? fileManager.removeItem(at: backup)
            }
        }

        do {
            try fileManager.copyItem(at: source, to: staged)
            let contents = staged.appendingPathComponent("Contents")
            let plistURL = contents.appendingPathComponent("Info.plist")
            let macOS = contents.appendingPathComponent("MacOS")
            let oldExecutable = macOS.appendingPathComponent(facts.executableName)
            let newExecutable = macOS.appendingPathComponent(executableName)
            guard fileManager.fileExists(atPath: oldExecutable.path) else {
                throw InstallerError.missingResource(oldExecutable.path)
            }
            if oldExecutable != newExecutable {
                try fileManager.moveItem(at: oldExecutable, to: newExecutable)
            }
            try updatePlist(at: plistURL)
            if let dockIcon = request.dockIcon {
                guard fileManager.fileExists(atPath: dockIcon.path) else {
                    throw InstallerError.missingResource(dockIcon.path)
                }
                let installedIcon = contents.appendingPathComponent("Resources/KakaoTalkWork.icns")
                try fileManager.copyItem(at: dockIcon, to: installedIcon)
                try setIconFile("KakaoTalkWork.icns", inPlistAt: plistURL)
            }

            let assets = contents.appendingPathComponent("Resources/Assets.car")
            let patchedAssets = contents.appendingPathComponent("Resources/.Assets.green.car")
            guard fileManager.fileExists(atPath: assets.path) else {
                throw InstallerError.missingResource(assets.path)
            }
            try AssetCatalogPatcher.patch(.init(
                sourceCatalog: assets,
                destinationCatalog: patchedAssets,
                allowedSourceSHA256: request.allowedAssetsSHA256
            ))
            _ = try fileManager.replaceItemAt(assets, withItemAt: patchedAssets)

            try runner.run("/usr/bin/codesign", ["--force", "--deep", "--sign", "-", staged.path])
            try runner.run("/usr/bin/codesign", ["--verify", "--deep", "--strict", staged.path])

            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.moveItem(at: destination, to: backup)
                movedExisting = true
            }
            do {
                try fileManager.moveItem(at: staged, to: destination)
                if movedExisting {
                    try fileManager.removeItem(at: backup)
                    movedExisting = false
                }
            } catch {
                if movedExisting {
                    try? fileManager.moveItem(at: backup, to: destination)
                    movedExisting = false
                }
                throw error
            }
        } catch {
            if movedExisting, !fileManager.fileExists(atPath: destination.path) {
                try? fileManager.moveItem(at: backup, to: destination)
                movedExisting = false
            }
            throw error
        }
    }

    private static func updatePlist(at url: URL) throws {
        let data = try Data(contentsOf: url)
        guard var plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            throw InspectionError.invalidInfoPlist
        }
        plist["CFBundleExecutable"] = executableName
        plist["CFBundleIdentifier"] = bundleIdentifier
        plist["CFBundleName"] = executableName
        plist["CFBundleDisplayName"] = executableName
        let output = try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0)
        try output.write(to: url, options: .atomic)
    }

    private static func setIconFile(_ name: String, inPlistAt url: URL) throws {
        let data = try Data(contentsOf: url)
        guard var plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            throw InspectionError.invalidInfoPlist
        }
        plist["CFBundleIconFile"] = name
        let output = try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0)
        try output.write(to: url, options: .atomic)
    }
}
