import XCTest
@testable import Canvas

/// What the canvas's own frame costs on the way out to See All with many windows: the camera every
/// frame, the chrome counter-scaled for every window. Prints the numbers; asserts only a loose ceiling.
@MainActor
final class SeeAllPerfTests: XCTestCase {
    func testZoomingOutWithManyWindows() {
        for count in [20, 60, 120] {
            let view = CanvasView(frame: NSRect(x: 0, y: 0, width: 1512, height: 982))
            view.layout()
            for i in 0..<count {
                let info = WindowInfo(id: CGWindowID(1000 + i), pid: getpid(), layer: 0,
                                      bounds: CGRect(x: (i % 12) * 1300, y: (i / 12) * 900, width: 1200, height: 800),
                                      title: "Window \(i)", alpha: 1)
                view.add(WindowProxy(info: info, camera: view.camera, scale: 2))
            }
            let from = Camera(center: CGPoint(x: 756, y: 491), zoom: 1, viewSize: view.bounds.size)
            guard let to = view.overviewCamera else { return XCTFail("no overview") }
            let frames = 60
            var times: [Double] = []
            for f in 0...frames {
                let s = CGFloat(f) / CGFloat(frames)
                let zoom = from.zoom * pow(to.zoom / from.zoom, s)
                let c0 = from.center(viewSize: view.bounds.size), c1 = to.center(viewSize: view.bounds.size)
                let camera = Camera(center: CGPoint(x: c0.x + (c1.x - c0.x) * s, y: c0.y + (c1.y - c0.y) * s),
                                    zoom: zoom, viewSize: view.bounds.size)
                let began = CACurrentMediaTime()
                view.set(camera: camera)
                times.append((CACurrentMediaTime() - began) * 1000)
            }
            times.sort()
            let p50 = times[times.count / 2], p95 = times[times.count * 95 / 100], worst = times.last ?? 0
            print(String(format: "See All perf: %d windows — frame p50 %.3f ms, p95 %.3f ms, max %.3f ms", count, p50, p95, worst))
            XCTAssertLessThan(p50, 8, "\(count) windows")
        }
    }
}
