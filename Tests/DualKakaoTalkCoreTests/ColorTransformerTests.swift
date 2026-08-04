import XCTest
@testable import DualKakaoTalkCore

final class ColorTransformerTests: XCTestCase {
    func testDockYellowBecomesMutedGreen() {
        let input = RGBA(red: 255, green: 224, blue: 0, alpha: 207)
        let output = ColorTransformer.transform(input, variant: .dock)
        XCTAssertEqual(output, RGBA(red: 0x62, green: 0x8C, blue: 0x73, alpha: 207))
    }

    func testDockBrownIsPreserved() {
        let input = RGBA(red: 65, green: 34, blue: 34, alpha: 255)
        XCTAssertEqual(ColorTransformer.transform(input, variant: .dock), input)
    }

    func testTransparentPixelsArePreserved() {
        let input = RGBA(red: 255, green: 255, blue: 0, alpha: 0)
        XCTAssertEqual(ColorTransformer.transform(input, variant: .menuBar), input)
    }

    func testMenuGlyphBecomesMutedGreen() {
        let input = RGBA(red: 20, green: 20, blue: 20, alpha: 192)
        let output = ColorTransformer.transform(input, variant: .menuBar)
        XCTAssertEqual(output, RGBA(red: 0x5B, green: 0x8A, blue: 0x72, alpha: 192))
    }

    func testMenuNotificationRedIsPreserved() {
        let input = RGBA(red: 220, green: 45, blue: 45, alpha: 255)
        XCTAssertEqual(ColorTransformer.transform(input, variant: .menuBar), input)
    }
}
