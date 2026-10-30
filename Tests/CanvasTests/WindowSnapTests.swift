import XCTest
import CoreGraphics
@testable import Canvas

final class WindowSnapTests: XCTestCase {
    // A 1512×982 display with a 33 pt menu bar.
    let view = CGSize(width: 1512, height: 982)
    let visible = CGRect(x: 0, y: 33, width: 1512, height: 949)
    // A full screen window somewhere on the canvas, entered on the visible area.
    let full = WindowSnap.Window(rect: CGRect(x: 3000, y: 500, width: 1512, height: 949), spot: CGPoint(x: 0, y: 33))
    var aligned: Camera { Camera(origin: CGPoint(x: 3000, y: 467), zoom: 1) }

    func testNearlyAlignedSnapsExactly() {
        let near = Camera(origin: CGPoint(x: 3030, y: 450), zoom: 1)
        let hit = WindowSnap.target(camera: near, viewSize: view, visible: visible, windows: [full])
        XCTAssertEqual(hit?.index, 0)
        XCTAssertEqual(hit?.camera, aligned)
    }

    func testNearlyOneToOneSnaps() {
        // 96 %, centred on the window: each edge is about 30 pt in.
        let near = Camera(center: aligned.center(viewSize: view), zoom: 0.96, viewSize: view)
        XCTAssertEqual(WindowSnap.target(camera: near, viewSize: view, visible: visible, windows: [full])?.camera, aligned)
    }

    func testTooFarOrTooZoomedOutStays() {
        let off = Camera(origin: CGPoint(x: 3200, y: 467), zoom: 1)
        XCTAssertNil(WindowSnap.target(camera: off, viewSize: view, visible: visible, windows: [full]))
        let out = Camera(center: aligned.center(viewSize: view), zoom: 0.8, viewSize: view)
        XCTAssertNil(WindowSnap.target(camera: out, viewSize: view, visible: visible, windows: [full]))
    }

    func testNormalDoesNotSnapSmallWindows() {
        let small = WindowSnap.Window(rect: CGRect(x: 3000, y: 500, width: 900, height: 700), spot: CGPoint(x: 306, y: 157))
        let near = Camera(origin: CGPoint(x: 3000 - 300, y: 500 - 150), zoom: 1)
        XCTAssertNil(WindowSnap.target(camera: near, viewSize: view, visible: visible, windows: [small]))
    }

    func testClosestWins() {
        let other = WindowSnap.Window(rect: CGRect(x: 3060, y: 500, width: 1512, height: 949), spot: CGPoint(x: 0, y: 33))
        let near = Camera(origin: CGPoint(x: 3050, y: 467), zoom: 1)
        XCTAssertEqual(WindowSnap.target(camera: near, viewSize: view, visible: visible, windows: [full, other])?.index, 1)
    }

    func testStrongSnapsSmallWindowWithinReach() {
        let small = WindowSnap.Window(rect: CGRect(x: 3000, y: 500, width: 900, height: 700), spot: CGPoint(x: 306, y: 157))
        let target = Camera(origin: CGPoint(x: 2694, y: 343), zoom: 1)
        let near = Camera(origin: CGPoint(x: 2844, y: 343), zoom: 1)
        XCTAssertNil(WindowSnap.target(camera: near, viewSize: view, visible: visible, windows: [small], strength: .normal))
        XCTAssertEqual(WindowSnap.target(camera: near, viewSize: view, visible: visible, windows: [small], strength: .strong)?.camera, target)
    }

    func testStrongReachBoundaryAndDistantWindow() {
        let size = CGSize(width: 1000, height: 1000)
        let area = CGRect(origin: .zero, size: size)
        let window = WindowSnap.Window(rect: CGRect(x: 0, y: 0, width: 1000, height: 1000), spot: .zero)
        let edge = Camera(origin: CGPoint(x: 150, y: 0), zoom: 1)
        let beyond = Camera(origin: CGPoint(x: 151, y: 0), zoom: 1)
        XCTAssertNotNil(WindowSnap.target(camera: edge, viewSize: size, visible: area, windows: [window], strength: .strong))
        XCTAssertNil(WindowSnap.target(camera: beyond, viewSize: size, visible: area, windows: [window], strength: .strong))
        XCTAssertNil(WindowSnap.target(camera: edge, viewSize: size, visible: area, windows: [window], strength: .normal))
    }

    func testStrongDoesNotCaptureInvisibleWindowAndCanSnapFromOverview() {
        let hidden = WindowSnap.Window(rect: CGRect(x: 3000, y: 500, width: 20, height: 20), spot: CGPoint(x: -100, y: 100))
        let camera = Camera(origin: CGPoint(x: 3100, y: 400), zoom: 1)
        XCTAssertNil(WindowSnap.target(camera: camera, viewSize: view, visible: visible, windows: [hidden], strength: .strong))
        let out = Camera(center: aligned.center(viewSize: view), zoom: 0.5, viewSize: view)
        XCTAssertEqual(WindowSnap.target(camera: out, viewSize: view, visible: visible, windows: [full], strength: .strong)?.camera, aligned)
    }

    func testStrongRejectsWorldDistantWindowWhenZoomedOut() {
        let center = aligned.center(viewSize: view)
        let nearOnScreen = Camera(center: CGPoint(x: center.x + 300, y: center.y), zoom: 0.25, viewSize: view)
        XCTAssertNil(WindowSnap.target(camera: nearOnScreen, viewSize: view, visible: visible, windows: [full], strength: .strong))
    }

    func testEqualDistanceUsesGeometryRatherThanInputOrder() {
        let other = WindowSnap.Window(rect: CGRect(x: 3060, y: 500, width: 1512, height: 949), spot: CGPoint(x: 0, y: 33))
        let middle = Camera(origin: CGPoint(x: 3030, y: 467), zoom: 1)
        let first = WindowSnap.target(camera: middle, viewSize: view, visible: visible, windows: [full, other], strength: .strong)
        let reversed = WindowSnap.target(camera: middle, viewSize: view, visible: visible, windows: [other, full], strength: .strong)
        XCTAssertEqual(first?.camera, aligned)
        XCTAssertEqual(reversed?.camera, aligned)
    }

    func testNudgeSpringIsQuickWithLittleOvershoot() {
        let s = Spring(x0: -1, v0: 0, response: WindowSnap.response, damping: WindowSnap.damping)
        var peak: CGFloat = -1
        for i in 0...200 { peak = max(peak, s.evaluate(at: CGFloat(i) * 0.005).x) }
        XCTAssertLessThan(peak, 0.02)                         // under 2 % past the window
        XCTAssertLessThan(abs(s.evaluate(at: 0.3).x), 0.01)   // there within 0.3 s
    }
}
