import AppKit
import Carbon.HIToolbox
import XCTest
@testable import Canvas

final class ShortcutsTests: XCTestCase {
    override func setUp() async throws {
        await MainActor.run { Bindings.resetAll() }
    }

    override func tearDown() async throws {
        await MainActor.run { Bindings.resetAll() }
    }

    private func key(_ code: Int, _ character: String,
                     _ modifiers: UInt32 = UInt32(controlKey | optionKey)) -> Shortcut {
        Shortcut(keyCode: UInt32(code), modifiers: modifiers, key: character)
    }

    // MARK: Defaults

    func testTheDefaultsAreTheKeysSunlightAlwaysHad() async {
        await MainActor.run {
            XCTAssertEqual(Bindings.shortcut(for: .leftHalf)?.label, "⌃⌥←")
            XCTAssertEqual(Bindings.shortcut(for: .topLeft)?.label, "⌃⌥U")
            XCTAssertEqual(Bindings.shortcut(for: .full)?.label, "⌃⌥⏎")
            XCTAssertEqual(Bindings.shortcut(for: .tidy)?.label, "⌃⌥A")
            XCTAssertEqual(Bindings.shortcut(for: .nextDisplay)?.label, "⌃⌥⇧→")
            XCTAssertEqual(Bindings.shortcut(for: .showDesktop)?.label, "F11")
            XCTAssertNil(Bindings.shortcut(for: .centerTwoThirds))
            XCTAssertNil(Bindings.shortcut(for: .seeAll))
            XCTAssertNil(Bindings.shortcut(for: .panCanvas))
        }
    }

    func testTheSummariesReadTheSameAsBeforeUntilAKeyChanges() async {
        await MainActor.run {
            XCTAssertEqual(TileMenu.tileKeysSummary, "⌃⌥ ← → ↑ ↓ · U I J K · D F G · E T · ⏎ C")
            XCTAssertEqual(TileMenu.arrangeKeysSummary, "⌃⌥ 2 · 3 · 4")
            XCTAssertEqual(TileMenu.tidyKeysSummary, "⌃⌥A")
        }
    }

    // MARK: Changing a key

    func testAKeyCanBeChangedAndCleared() async {
        await MainActor.run {
            let custom = key(kVK_ANSI_L, "l")
            Bindings.setShortcut(custom, for: .leftHalf)
            XCTAssertEqual(Bindings.shortcut(for: .leftHalf), custom)
            XCTAssertEqual(TileMenu.tileKeysSummary, "⌃⌥L · ⌃⌥→ · ⌃⌥↑ · ⌃⌥↓ · ⌃⌥U · ⌃⌥I · ⌃⌥J · ⌃⌥K · ⌃⌥D · ⌃⌥F · ⌃⌥G · ⌃⌥E · ⌃⌥T · ⌃⌥⏎ · ⌃⌥C")

            // Back to the default: no override is left behind.
            Bindings.setShortcut(custom, for: .leftHalf)
            Bindings.setShortcut(key(kVK_LeftArrow, String(Character(UnicodeScalar(UInt16(NSLeftArrowFunctionKey))!))),
                                 for: .leftHalf)
            XCTAssertEqual(TileMenu.tileKeysSummary, "⌃⌥ ← → ↑ ↓ · U I J K · D F G · E T · ⏎ C")

            // Removed entirely: the menu shows no key and nothing claims it.
            Bindings.setShortcut(nil, for: .tidy)
            XCTAssertNil(Bindings.shortcut(for: .tidy))
            XCTAssertEqual(TileMenu.tidyKeysSummary, "")
        }
    }

    func testAKeyAnotherCommandHoldsIsAConflict() async {
        await MainActor.run {
            let custom = key(kVK_ANSI_L, "l")
            Bindings.setShortcut(custom, for: .rightHalf)
            XCTAssertEqual(Bindings.conflict(for: custom, excluding: .leftHalf), .rightHalf)
            XCTAssertNil(Bindings.conflict(for: custom, excluding: .rightHalf))
        }
    }

    func testAShortcutNeedsAControlOptionOrCommandKey() async {
        await MainActor.run {
            let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [.shift],
                                         timestamp: 0, windowNumber: 0, context: nil,
                                         characters: "L", charactersIgnoringModifiers: "L",
                                         isARepeat: false, keyCode: UInt16(kVK_ANSI_L))!
            XCTAssertNil(Shortcut(event: event))
            let withOption = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [.option],
                                              timestamp: 0, windowNumber: 0, context: nil,
                                              characters: "l", charactersIgnoringModifiers: "l",
                                              isARepeat: false, keyCode: UInt16(kVK_ANSI_L))!
            XCTAssertEqual(Shortcut(event: withOption)?.label, "⌥L")
        }
    }

    // MARK: Gestures

    func testTheGesturesDefaultToTapSeeAllSpreadDesktopAndDragPan() async {
        await MainActor.run {
            XCTAssertEqual(Bindings.command(for: .fourFingerTap), .seeAll)
            XCTAssertEqual(Bindings.command(for: .spread), .showDesktop)
            XCTAssertEqual(Bindings.command(for: .fourFingerDrag), .panCanvas)
            XCTAssertNil(Bindings.command(for: .swipeUp))
            XCTAssertNil(Bindings.command(for: .swipeDown))
            XCTAssertNil(Bindings.command(for: .swipeLeft))
            XCTAssertNil(Bindings.command(for: .swipeRight))

            let config = Bindings.trackpadConfig()
            XCTAssertTrue(config.tap)
            XCTAssertTrue(config.spread)
            XCTAssertEqual(config.drag, .pan)
            XCTAssertTrue(config.flicks.isEmpty)
        }
    }

    func testAGestureCanBeGivenACommandAndPutBack() async {
        await MainActor.run {
            Bindings.setGesture(.tidy, for: .swipeUp)
            XCTAssertEqual(Bindings.command(for: .swipeUp), .tidy)
            XCTAssertEqual(Bindings.gesture(doing: .tidy), .swipeUp)
            XCTAssertEqual(Bindings.trackpadConfig().flicks, [.swipeUp])

            Bindings.setGesture(nil, for: .fourFingerTap)
            XCTAssertNil(Bindings.command(for: .fourFingerTap))
            XCTAssertFalse(Bindings.trackpadConfig().tap)

            Bindings.setGesture(.tidy, for: .fourFingerDrag)
            XCTAssertEqual(Bindings.trackpadConfig().drag, .fire)
            Bindings.setGesture(nil, for: .fourFingerDrag)
            XCTAssertEqual(Bindings.trackpadConfig().drag, .off)

            Bindings.resetGestures()
            XCTAssertEqual(Bindings.command(for: .fourFingerTap), .seeAll)
            XCTAssertNil(Bindings.command(for: .swipeUp))
        }
    }

    // MARK: Migration

    func testTheOldSwipeUpChoiceBecomesTheGestureBindings() async {
        await MainActor.run {
            Bindings.resetAll()
            UserDefaults.standard.set("swipeUp", forKey: "CanvasSeeAllGesture")
            Bindings.migrateIfNeeded()

            XCTAssertNil(Bindings.command(for: .fourFingerTap))
            XCTAssertEqual(Bindings.command(for: .swipeUp), .seeAll)
            XCTAssertEqual(Settings.seeAllGesture, .swipeUp)
            XCTAssertNil(UserDefaults.standard.string(forKey: "CanvasSeeAllGesture"))
        }
    }
}
