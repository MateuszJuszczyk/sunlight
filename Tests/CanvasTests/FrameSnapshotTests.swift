import XCTest
@testable import Canvas

/// A native frame means something on the canvas only through the camera it was read with.
final class FrameSnapshotTests: XCTestCase {
    private func info(_ id: CGWindowID, _ bounds: CGRect) -> WindowInfo {
        WindowInfo(id: id, pid: 1, layer: 0, bounds: bounds, title: nil, alpha: 1)
    }

    func testAFrameIsSeenThroughTheSnapshotsCamera() {
        let camera = Camera(origin: CGPoint(x: 1000, y: 500), zoom: 1)
        let snapshot = FrameSnapshot(list: [info(7, CGRect(x: 40, y: 60, width: 300, height: 200))], camera: camera)
        XCTAssertEqual(snapshot.worldOrigin(of: 7), CGPoint(x: 1040, y: 560))
        XCTAssertEqual(snapshot[7], CGRect(x: 40, y: 60, width: 300, height: 200))
        XCTAssertTrue(snapshot.has(7))
    }

    func testZoomedOutTheSizeIsStillTheRealSize() {
        // World units are points at 1:1: only the origin goes through the camera.
        let camera = Camera(origin: .zero, zoom: 0.5)
        let snapshot = FrameSnapshot(list: [info(7, CGRect(x: 100, y: 100, width: 300, height: 200))], camera: camera)
        XCTAssertEqual(snapshot.worldOrigin(of: 7), CGPoint(x: 200, y: 200))
    }

    func testAWindowNotOnScreenHasNoPlace() {
        let snapshot = FrameSnapshot(list: [], camera: Camera())
        XCTAssertNil(snapshot[7])
        XCTAssertNil(snapshot.worldOrigin(of: 7))
        XCTAssertFalse(snapshot.has(7))
    }

    func testAnEmptyFrameIsNowhere() {
        // The Dock mid-restart lists every window with no size; read as frames they'd all land at the camera's origin.
        let snapshot = FrameSnapshot(list: [info(7, CGRect(x: 0, y: 0, width: 0, height: 0))], camera: Camera(origin: CGPoint(x: 9, y: 9), zoom: 1))
        XCTAssertTrue(snapshot.has(7), "it is on screen")
        XCTAssertNil(snapshot.worldOrigin(of: 7), "but it has no place")
        XCTAssertFalse(FrameSnapshot.hasSize(CGRect(x: 1, y: 1, width: 0.5, height: 30)))
        XCTAssertTrue(FrameSnapshot.hasSize(CGRect(x: 1, y: 1, width: 1, height: 1)))
    }

    func testTheFrontEntryWinsADuplicate() {
        let snapshot = FrameSnapshot(list: [info(7, CGRect(x: 1, y: 1, width: 10, height: 10)), info(7, CGRect(x: 2, y: 2, width: 10, height: 10))], camera: Camera())
        XCTAssertEqual(snapshot[7]?.origin, CGPoint(x: 1, y: 1))
    }
}
