import Foundation

/// What the canvas does with the pointer, trackpad and keys, and Sunlight's own keys: the reference
/// Settings › Shortcuts used to be before it became editable, and Instructions › Keyboard Shortcuts.
/// On the main actor, like `TileMenu`, whose key summaries it reads.
@MainActor
enum ShortcutReference {
    struct Row: Equatable {
        let title: String
        let keys: String
    }

    /// The canvas, in the order you'd learn it. Gestures and keys are read from `Bindings`, so a
    /// rebound one shows here too.
    static var canvasRows: [Row] {
        let seeAll = gestureLine(for: .seeAll) ?? "—"
        let desktop = [Bindings.shortcut(for: .showDesktop)?.label, gestureLine(for: .showDesktop)]
            .compactMap { $0 }.joined(separator: " · ")
        return [
            Row(title: "Zoom", keys: "pinch · ⌥ or ⌘ scroll"),
            Row(title: "Pan", keys: "two-finger scroll · \(gestureLine(for: .panCanvas) ?? "four-finger drag")"),
            Row(title: "Move a window", keys: "drag"),
            Row(title: "Flip a window's pole", keys: (Bindings.shortcut(for: .flipPolarity)?.label ?? "—") + " · its ⊕/⊖ button"),
            Row(title: "Single-click a window", keys: Settings.singleClickBehavior.title),
            Row(title: "Double-click a window", keys: Settings.doubleClickBehavior.title),
            Row(title: "Enter a window", keys: "pinch in · " + (Bindings.shortcut(for: .enterWindow)?.label ?? "—")),
            Row(title: "Use a window at 1:1", keys: "click"),
            Row(title: "See everything", keys: seeAll),
            Row(title: "Canvas ↔ last window", keys: "Mission Control key · " + seeAll),
            Row(title: "Show Desktop", keys: desktop.isEmpty ? "—" : desktop),
            Row(title: "Switch apps", keys: "⌘Tab · then ⌘← ⌘→"),
            Row(title: "Switch the app's windows", keys: "⌘Tab, then ⌘` · ⌘↑ ⌘↓"),
        ]
    }

    /// Sunlight's own commands, leaving out the experimental ones that are off (`Settings.arranging`,
    /// `Settings.stripModeEnabled`).
    static var commandRows: [Row] { commandRows(arranging: Settings.arranging, strip: Settings.stripModeEnabled) }

    static func commandRows(arranging: Bool, strip: Bool) -> [Row] {
        var rows = [
            Row(title: "Save Layout…", keys: "⌘S"),
            Row(title: "Restore a layout", keys: "⌘1 – ⌘9"),
        ]
        if arranging {
            rows += [
                Row(title: "Tidy", keys: TileMenu.tidyKeysSummary),
                Row(title: "Arrange the screen in columns", keys: TileMenu.arrangeKeysSummary),
            ]
        }
        rows.append(Row(title: "Move & Resize a window", keys: TileMenu.tileKeysSummary))
        if strip {
            let key = Bindings.shortcut(for: .toggleStrip)?.label ?? "—"
            rows.append(Row(title: "Strip mode on or off", keys: key + " · then the arrows step"))
        }
        let desktop = [Bindings.shortcut(for: .showDesktop)?.label, gestureLine(for: .showDesktop)]
            .compactMap { $0 }.joined(separator: " · ")
        rows += [
            Row(title: "Show Desktop", keys: desktop.isEmpty ? "—" : desktop),
            Row(title: "Settings…", keys: "⌘,"),
        ]
        return rows
    }

    /// The gesture that does a command now, in the words the Trackpad pane uses.
    private static func gestureLine(for command: Command) -> String? {
        Bindings.gesture(doing: command)?.how.lowercased()
    }
}
