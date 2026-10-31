import CoreGraphics
import QuartzCore

/// The window server's frames at one moment, with the camera they were read against.
///
/// A native frame means nothing on the canvas on its own: it has to be seen through the camera the
/// canvas had when the window was placed there. Reading the frames and remembering the camera in two
/// places let them drift apart (a window read back against a camera already zooming out landed where
/// it never was). A snapshot carries both, so a frame is only ever turned into a canvas place through
/// the camera it was read with. It's the one shape native frames come in on the live canvas: the
/// listing, the seam and the return all read one.
struct FrameSnapshot {
    /// Every window on screen, by id, in global top-left points as the window server lists it.
    let frames: [CGWindowID: CGRect]
    /// The camera at the moment of reading, as seen from global coordinates (`Camera.global`).
    let camera: Camera
    let time: CFTimeInterval

    init(frames: [CGWindowID: CGRect], camera: Camera, time: CFTimeInterval = CACurrentMediaTime()) {
        self.frames = frames
        self.camera = camera
        self.time = time
    }

    init(list: [WindowInfo], camera: Camera, time: CFTimeInterval = CACurrentMediaTime()) {
        // The listing is front to back; a window appears once, but the front entry wins should it not.
        self.init(frames: Dictionary(list.map { ($0.id, $0.bounds) }, uniquingKeysWith: { front, _ in front }),
                  camera: camera, time: time)
    }

    /// The window's native frame, if it's on screen.
    subscript(id: CGWindowID) -> CGRect? { frames[id] }

    /// Whether the window is on screen, as far as this reading goes.
    func has(_ id: CGWindowID) -> Bool { frames[id] != nil }

    /// Where the window's top-left is on the canvas by this reading: its native origin through the
    /// snapshot's camera. World units are points at 1:1, so a size needs no camera. Nil for a window
    /// that isn't on screen, or is listed with no size (the Dock mid-restart, a window mid-teardown
    /// — read as a frame it would land every window at the same point, the camera's origin).
    func worldOrigin(of id: CGWindowID) -> CGPoint? {
        guard let frame = frames[id], FrameSnapshot.hasSize(frame) else { return nil }
        return camera.toWorld(frame.origin)
    }

    /// A frame the window server means: one with a size. An empty one is nowhere.
    static func hasSize(_ frame: CGRect) -> Bool {
        frame.width >= 1 && frame.height >= 1
    }
}
