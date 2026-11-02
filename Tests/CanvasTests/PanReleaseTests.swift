import AppKit
import XCTest
@testable import Canvas

@MainActor
final class PanReleaseTests: XCTestCase {
    func testFourFingerPanChecksForSnapAtReleaseWithDirectionalSnapOff() {
        let defaults = UserDefaults.standard
        let saved = defaults.object(forKey: "autoCenterAfterFourFingerPan")
        defer {
            if let saved { defaults.set(saved, forKey: "autoCenterAfterFourFingerPan") }
            else { defaults.removeObject(forKey: "autoCenterAfterFourFingerPan") }
        }
        Settings.autoCenterAfterFourFingerPan = false
        let view = CanvasView(frame: NSRect(x: 0, y: 0, width: 1000, height: 800))
        var checks = 0
        var cameraAtRelease: Camera?
        view.onPanRelease = { _ in
            checks += 1
            cameraAtRelease = view.camera
            return true
        }
        view.trackpadPan(by: CGVector(dx: 0.1, dy: 0))
        XCTAssertEqual(checks, 0)
        view.trackpadPanEnded()
        XCTAssertEqual(checks, 1)
        XCTAssertNotNil(cameraAtRelease)
        XCTAssertNotEqual(cameraAtRelease?.origin.x, 0)
        view.onPanRelease = nil
    }

    func testFourFingerPanUsesDirectionalSnapAtReleaseWhenEnabled() {
        let defaults = UserDefaults.standard
        let saved = defaults.object(forKey: "autoCenterAfterFourFingerPan")
        defer {
            if let saved { defaults.set(saved, forKey: "autoCenterAfterFourFingerPan") }
            else { defaults.removeObject(forKey: "autoCenterAfterFourFingerPan") }
        }
        Settings.autoCenterAfterFourFingerPan = true
        let view = CanvasView(frame: NSRect(x: 0, y: 0, width: 1000, height: 800))
        var checks = 0
        view.onFourFingerPanEnd = { _, _ in checks += 1; return true }
        view.trackpadPan(by: CGVector(dx: 0.1, dy: 0))
        XCTAssertEqual(checks, 0)
        view.trackpadPanEnded()
        XCTAssertEqual(checks, 1)
    }

    func testFourFingerPanCanDeclineSnapAtRelease() {
        let defaults = UserDefaults.standard
        let saved = defaults.object(forKey: "autoCenterAfterFourFingerPan")
        defer {
            if let saved { defaults.set(saved, forKey: "autoCenterAfterFourFingerPan") }
            else { defaults.removeObject(forKey: "autoCenterAfterFourFingerPan") }
        }
        Settings.autoCenterAfterFourFingerPan = false
        let view = CanvasView(frame: NSRect(x: 0, y: 0, width: 1000, height: 800))
        var releaseChecks = 0
        var stillChecks = 0
        view.onPanRelease = { _ in releaseChecks += 1; return false }
        view.onSettle = { stillChecks += 1; return true }
        view.trackpadPan(by: CGVector(dx: 0.1, dy: 0))
        view.trackpadPanEnded()
        XCTAssertEqual(releaseChecks, 1)
        XCTAssertEqual(stillChecks, 0)
    }
}
