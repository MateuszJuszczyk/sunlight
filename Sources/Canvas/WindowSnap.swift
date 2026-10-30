import CoreGraphics

/// A camera nearly aligned with a window can nudge the remaining distance to its 1:1 placement.
/// Normal keeps the original screen-sized-only behavior; strong also accepts smaller windows and
/// increases the reach. Candidate arithmetic is independent of the controller and view.
enum WindowSnap {
    /// A window at least this share of the visible area, each way, counts as screen-sized.
    static let fill: CGFloat = 0.9
    /// How far each edge may be from its destination, as a share of the view's dimensions.
    static let normalReach: CGFloat = 0.05
    static let strongReach: CGFloat = 0.15
    /// Never less than this, in screen points, however small the screen.
    static let minReach: CGFloat = 32
    /// The nudge's spring: quicker and stiffer than a flight's (0.45 s, 0.72), overshooting by about 1 %.
    static let response: CGFloat = 0.24
    static let damping: CGFloat = 0.82

    enum Strength {
        case normal, strong
    }

    /// A window that could be snapped to: its rect in the world, and where its top-left corner sits on
    /// screen (view coordinates, top-left origin) once it's entered at 1:1.
    struct Window {
        let rect: CGRect
        let spot: CGPoint
    }

    static func isScreenSized(_ size: CGSize, visible: CGSize) -> Bool {
        size.width >= visible.width * fill && size.height >= visible.height * fill
    }

    /// The closest eligible window and its 1:1 camera. Equal distances are resolved by world geometry,
    /// rather than the order in which windows happened to be listed.
    static func target(camera: Camera, viewSize: CGSize, visible: CGRect, windows: [Window],
                       strength: Strength = .normal) -> (index: Int, camera: Camera)? {
        let reach = strength == .strong ? strongReach : normalReach
        let rx = max(minReach, viewSize.width * reach), ry = max(minReach, viewSize.height * reach)
        var best: (index: Int, camera: Camera, off: CGFloat, rect: CGRect, spot: CGPoint)?
        for (i, w) in windows.enumerated() {
            guard w.rect.width > 0, w.rect.height > 0,
                  strength == .strong || isScreenSized(w.rect.size, visible: visible.size) else { continue }
            let now = camera.toScreen(w.rect)
            let intersection = now.intersection(visible)
            guard !intersection.isNull, intersection.width > 0, intersection.height > 0 else { continue }
            let destination = Camera(origin: CGPoint(x: w.rect.minX - w.spot.x, y: w.rect.minY - w.spot.y), zoom: 1)
            let off: CGFloat
            if strength == .normal {
                let then = CGRect(origin: w.spot, size: w.rect.size)
                let dx = max(abs(now.minX - then.minX), abs(now.maxX - then.maxX))
                let dy = max(abs(now.minY - then.minY), abs(now.maxY - then.maxY))
                guard dx <= rx, dy <= ry else { continue }
                off = dx / rx + dy / ry
            } else {
                let currentCenter = camera.toWorld(CGPoint(x: viewSize.width / 2, y: viewSize.height / 2))
                let destinationCenter = destination.toWorld(CGPoint(x: viewSize.width / 2, y: viewSize.height / 2))
                let dx = abs(currentCenter.x - destinationCenter.x) * camera.zoom
                let dy = abs(currentCenter.y - destinationCenter.y) * camera.zoom
                let visibleFraction = intersection.width * intersection.height / (now.width * now.height)
                // Bound travel in world points as well as screen points, so a zoomed-out overview
                // cannot pull in a window that is visually nearby but far away on the canvas.
                let scale = min(camera.zoom, 1)
                guard scale > 0, dx <= rx * scale, dy <= ry * scale, visibleFraction >= 0.25 else { continue }
                let windowCenterX = abs(now.midX - visible.midX) / max(visible.width, 1)
                let windowCenterY = abs(now.midY - visible.midY) / max(visible.height, 1)
                off = dx / rx + dy / ry + windowCenterX + windowCenterY + (1 - visibleFraction)
            }
            if let best {
                let rect = w.rect, previous = best.rect
                let geometry = (rect.minX, rect.minY, rect.width, rect.height, w.spot.x, w.spot.y)
                let prior = (previous.minX, previous.minY, previous.width, previous.height, best.spot.x, best.spot.y)
                guard off < best.off || (off == best.off && geometry < prior) else { continue }
            }
            best = (i, Camera(origin: CGPoint(x: w.rect.minX - w.spot.x, y: w.rect.minY - w.spot.y), zoom: 1), off, w.rect, w.spot)
        }
        return best.map { ($0.index, $0.camera) }
    }
}
