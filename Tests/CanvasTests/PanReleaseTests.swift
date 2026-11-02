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

    func testPanBufferedWhileReturningToCanvasKeepsGlidingAfterReleaseInGap() throws {
        try XCTSkipIf(NSWorkspace.shared.accessibilityDisplayShouldReduceMotion, "Coasting is disabled by Reduce Motion")
        let defaults = UserDefaults.standard
        let keys = ["autoCenterAfterFourFingerPan", "CanvasPanInertia", "TrackpadCameraSensitivity"]
        let saved = keys.map { defaults.object(forKey: $0) }
        defer {
            for (key, value) in zip(keys, saved) {
                if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
            }
        }
        Settings.autoCenterAfterFourFingerPan = false
        Settings.panInertia = true
        Settings.trackpadCameraSensitivity = 1
        var buffered = PendingTrackpadPan(viewWidth: 1000, sensitivity: 1, at: 1)
        buffered.add(CGVector(dx: -0.2, dy: 0), at: 1.05)
        buffered.add(CGVector(dx: -0.2, dy: 0), at: 1.1)
        buffered.end(at: 1.11)
        let view = CanvasView(frame: NSRect(x: 0, y: 0, width: 1000, height: 1000))
        let visible = CGRect(x: 0, y: 0, width: 1000, height: 1000)
        let previous = WindowSnap.Window(rect: visible, spot: .zero)
        view.onPanRelease = { start in
            WindowSnap.target(camera: view.camera, viewSize: visible.size, visible: visible,
                              windows: [previous], sensitivity: 4, requireCenterInside: true,
                              panStart: start) != nil
        }
        view.trackpadPan(by: buffered.travel, preservingVelocity: buffered.velocity)
        view.trackpadPanEnded(releaseVelocity: buffered.releaseVelocity)
        XCTAssertNotNil(view.coast, "A miss at release must keep the buffered gesture's inertia")
        XCTAssertLessThan(view.coast?.velocity.dx ?? 0, -120)
        view.onPanRelease = nil
    }
}
