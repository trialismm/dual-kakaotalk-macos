import DualKakaoTalkCore
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
    fail("usage: dual-kakaotalk-tool <inspect|recolor|catalog-capability>", code: .usage)
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
            "canInspectWithPublicAPI": false,
            "canWriteWithPublicAPI": false,
            "privateCoreUIAllowed": false,
            "status": "blocked",
            "reason": "macOS exposes no public API for editing compiled Assets.car catalogs"
        ]
        let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        print(String(decoding: data, as: UTF8.self))
        Foundation.exit(Exit.unavailable.rawValue)

    default:
        fail("unknown command: \(command)", code: .usage)
    }
} catch {
    fail(error.localizedDescription, code: .failure)
}
