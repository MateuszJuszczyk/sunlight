import XCTest
@testable import Canvas

final class MinimapVisibilityTests: XCTestCase {
    func testShownOnlyOnTheCanvas() {
        XCTAssertTrue(MinimapPanel.belongs(setting: true, inCanvas: true, showingDesktop: false, paused: false))
        // In a window at 1:1, on the way into one, or another app in front.
        XCTAssertFalse(MinimapPanel.belongs(setting: true, inCanvas: false, showingDesktop: false, paused: false))
        XCTAssertFalse(MinimapPanel.belongs(setting: true, inCanvas: true, showingDesktop: true, paused: false))
        XCTAssertFalse(MinimapPanel.belongs(setting: true, inCanvas: true, showingDesktop: false, paused: true))
        XCTAssertFalse(MinimapPanel.belongs(setting: false, inCanvas: true, showingDesktop: false, paused: false))
    }
}
