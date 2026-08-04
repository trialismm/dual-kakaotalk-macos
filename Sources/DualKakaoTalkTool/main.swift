import DualKakaoTalkCore
import AppKit
import Foundation

private enum Exit: Int32 {
    case usage = 64
    case unavailable = 69
    case failure = 70
}

private func fail(_ message: String, code: Exit) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    Foundation.exit(code.rawValue)
}

private let arguments = Array(CommandLine.arguments.dropFirst())
guard let command = arguments.first else {
    fail("usage: dual-kakaotalk-tool <inspect|recolor|catalog-capability|catalog-list|catalog-patch|install|install-staged|set-dock-icon>", code: .usage)
}

do {
    switch command {
    case "inspect":
        guard arguments.count == 1 else { fail("inspect takes no arguments", code: .usage) }
        let facts = try OfficialAppInspector.inspect()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        print(String(decoding: try encoder.encode(facts), as: UTF8.self))

    case "recolor":
        guard arguments.count == 4,
              let variant = IconVariant(rawValue: arguments[1])
        else {
            fail("usage: recolor <dock|menu-bar> <input.png> <output.png>", code: .usage)
        }
        try ColorTransformer.recolorPNG(
            input: URL(fileURLWithPath: arguments[2]),
            output: URL(fileURLWithPath: arguments[3]),
            variant: variant
        )

    case "catalog-capability":
        guard arguments.count == 1 else { fail("catalog-capability takes no arguments", code: .usage) }
        let result: [String: Any] = [
            "canInspectWithPrivateCoreUI": true,
            "canWriteWithPrivateCoreUI": true,
            "privateCoreUIAllowed": true,
            "status": "experimental",
            "reason": "Private CoreUI is restricted to fingerprinted catalogs and allowlisted menu renditions"
        ]
        let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        print(String(decoding: data, as: UTF8.self))

    case "catalog-list":
        guard arguments.count == 2 else {
            fail("usage: catalog-list <Assets.car>", code: .usage)
        }
        let renditions = try AssetCatalogPatcher.renditions(in: URL(fileURLWithPath: arguments[1]))
            .filter { AssetCatalogPatcher.allowedNames.contains($0.name) }
            .map {
                [
                    "name": $0.name,
                    "scale": $0.scale,
                    "width": $0.width,
                    "height": $0.height,
                    "linked": $0.hasInternalLink
                ] as [String: Any]
            }
        let data = try JSONSerialization.data(withJSONObject: renditions, options: [.prettyPrinted, .sortedKeys])
        print(String(decoding: data, as: UTF8.self))

    case "catalog-patch":
        guard arguments.count == 4 else {
            fail("usage: catalog-patch <source.car> <destination.car> <allowed-sha256>", code: .usage)
        }
        try AssetCatalogPatcher.patch(
            AssetCatalogMutationPlan(
                sourceCatalog: URL(fileURLWithPath: arguments[1]),
                destinationCatalog: URL(fileURLWithPath: arguments[2]),
                allowedSourceSHA256: [arguments[3]]
            )
        )

    case "install":
        guard arguments.count == 3 else {
            fail("usage: install <allowed-assets-sha256> <dock-icon.icns>", code: .usage)
        }
        try KakaoTalkWorkInstaller.install(.init(
            sourceApp: URL(fileURLWithPath: OfficialAppInspector.supportedPath),
            destinationApp: URL(fileURLWithPath: KakaoTalkWorkInstaller.destinationPath),
            allowedAssetsSHA256: [arguments[1]],
            dockIcon: URL(fileURLWithPath: arguments[2])
        ))

    case "install-staged":
        guard arguments.count == 4 else {
            fail("usage: install-staged <destination.app> <allowed-assets-sha256> <dock-icon.icns>", code: .usage)
        }
        try KakaoTalkWorkInstaller.install(.init(
            sourceApp: URL(fileURLWithPath: OfficialAppInspector.supportedPath),
            destinationApp: URL(fileURLWithPath: arguments[1]),
            allowedAssetsSHA256: [arguments[2]],
            dockIcon: URL(fileURLWithPath: arguments[3])
        ))

    case "write-dock-icon":
        guard arguments.count == 3 else {
            fail("usage: write-dock-icon <source.app> <output.icns>", code: .usage)
        }
        try writeDockIcon(sourceApp: arguments[1], output: arguments[2])

    default:
        fail("unknown command: \(command)", code: .usage)
    }
} catch {
    fail(error.localizedDescription, code: .failure)
}

private func writeDockIcon(sourceApp: String, output: String) throws {
    let sourceIcon = NSWorkspace.shared.icon(forFile: sourceApp)
    let iconset = FileManager.default.temporaryDirectory
        .appendingPathComponent("DualKakaoTalk-\(UUID().uuidString).iconset")
    try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: iconset) }

    for size in [16, 32, 128, 256, 512] {
        for scale in [1, 2] {
            let pixels = size * scale
            guard let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                isPlanar: false, colorSpaceName: .deviceRGB,
                bytesPerRow: 0, bitsPerPixel: 0
            ) else {
                throw InstallerError.commandFailed("Unable to allocate Dock icon bitmap.")
            }
            bitmap.size = NSSize(width: size, height: size)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
            sourceIcon.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
            NSGraphicsContext.restoreGraphicsState()
            guard let recolored = bitmap.recoloring(variant: .dock),
                  let png = recolored.representation(using: .png, properties: [:]) else {
                throw InstallerError.commandFailed("Unable to encode Dock icon.")
            }
            let suffix = scale == 2 ? "@2x" : ""
            try png.write(to: iconset.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
        }
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    process.arguments = ["-c", "icns", iconset.path, "-o", output]
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw InstallerError.commandFailed("iconutil could not create the Dock icon.")
    }
}

private extension NSBitmapImageRep {
    func recoloring(variant: IconVariant) -> NSBitmapImageRep? {
        guard let copy = copy() as? NSBitmapImageRep else { return nil }
        for y in 0..<copy.pixelsHigh {
            for x in 0..<copy.pixelsWide {
                guard let color = copy.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                let input = RGBA(
                    red: UInt8(clamping: Int((color.redComponent * 255).rounded())),
                    green: UInt8(clamping: Int((color.greenComponent * 255).rounded())),
                    blue: UInt8(clamping: Int((color.blueComponent * 255).rounded())),
                    alpha: UInt8(clamping: Int((color.alphaComponent * 255).rounded()))
                )
                let output = ColorTransformer.transform(input, variant: variant)
                copy.setColor(NSColor(
                    calibratedRed: CGFloat(output.red) / 255,
                    green: CGFloat(output.green) / 255,
                    blue: CGFloat(output.blue) / 255,
                    alpha: CGFloat(output.alpha) / 255
                ), atX: x, y: y)
            }
        }
        return copy
    }
}
