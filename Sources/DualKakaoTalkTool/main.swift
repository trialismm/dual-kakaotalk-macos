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
    fail("usage: dual-kakaotalk-tool <inspect|recolor|catalog-capability|catalog-list|catalog-patch|prepare-install|install|install-staged|write-dock-icon|progress-window>", code: .usage)
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

    case "prepare-install":
        guard arguments.count == 4 else {
            fail("usage: prepare-install <allowed-assets-sha256> <dock-icon.icns> <release-version>", code: .usage)
        }
        let request = try KakaoTalkWorkInstaller.prepare(.init(
            sourceApp: URL(fileURLWithPath: OfficialAppInspector.supportedPath),
            destinationApp: URL(fileURLWithPath: KakaoTalkWorkInstaller.destinationPath),
            allowedAssetsSHA256: [arguments[1]],
            dockIcon: URL(fileURLWithPath: arguments[2])
        ), version: arguments[3])
        print(request.path)

    case "install":
        guard arguments.count == 2 else {
            fail("usage: install <fixed-request.plist>", code: .usage)
        }
        print(try KakaoTalkWorkInstaller.installReleaseRequest(at: URL(fileURLWithPath: arguments[1])) ? "NOOP: existing destination matches requested build and catalog digest." : "INSTALLED: destination verified.")

    case "install-staged":
        fail("install-staged is not available in release builds; use prepare-install then install <request.plist>", code: .usage)

    case "write-dock-icon":
        guard arguments.count == 3 else {
            fail("usage: write-dock-icon <source.app> <output.icns>", code: .usage)
        }
        try writeDockIcon(sourceApp: arguments[1], output: arguments[2])

    case "progress-window":
        guard arguments.count == 3 else {
            fail("usage: progress-window <state-file> <window-title>", code: .usage)
        }
        runProgressWindow(stateFile: arguments[1], title: arguments[2])

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

private final class ProgressWindowController: NSObject, NSApplicationDelegate {
    private let stateFile: String
    private let title: String
    private let progressIndicator = NSProgressIndicator(frame: NSRect(x: 0, y: 0, width: 360, height: 20))
    private var alert: NSAlert?
    private var timer: Timer?

    init(stateFile: String, title: String) {
        self.stateFile = stateFile
        self.title = title
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = " "
        alert.alertStyle = .informational

        progressIndicator.isIndeterminate = false
        progressIndicator.minValue = 0
        progressIndicator.maxValue = 100
        progressIndicator.doubleValue = 0
        alert.accessoryView = progressIndicator

        let button = alert.addButton(withTitle: "…")
        button.isEnabled = false
        self.alert = alert

        timer = Timer(timeInterval: 0.15, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        RunLoop.main.add(timer!, forMode: .common)
        refresh()
        alert.window.level = .floating
        alert.window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        alert.window.center()
        alert.window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func refresh() {
        guard let contents = try? String(contentsOfFile: stateFile, encoding: .utf8) else { return }
        let fields = contents.split(separator: "\n", omittingEmptySubsequences: false)
        guard fields.count >= 3, let percent = Double(fields[0]) else { return }

        progressIndicator.doubleValue = min(100, max(0, percent))
        alert?.informativeText = String(fields[1])

        switch fields[2] {
        case "done":
            progressIndicator.doubleValue = 100
            finish(after: 0.5)
        case "failed":
            finish(after: 1.5)
        default:
            break
        }
    }

    private func finish(after delay: TimeInterval) {
        timer?.invalidate()
        timer = nil
        try? FileManager.default.removeItem(atPath: stateFile)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            NSApp.abortModal()
            NSApp.terminate(nil)
        }
    }
}

private func runProgressWindow(stateFile: String, title: String) -> Never {
    let app = NSApplication.shared
    app.setActivationPolicy(.regular)
    let controller = ProgressWindowController(stateFile: stateFile, title: title)
    app.delegate = controller
    app.run()
    Foundation.exit(EXIT_SUCCESS)
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
