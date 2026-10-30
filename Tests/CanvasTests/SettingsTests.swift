import XCTest
@testable import Canvas

final class SettingsTests: XCTestCase {
    func testCommandLineCanDisableLayoutPersistenceWithoutChangingSavedPreferences() async {
        await MainActor.run {
            let defaults = UserDefaults.standard
            let original = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
            defer { defaults.setVolatileDomain(original, forName: UserDefaults.argumentDomain) }
            var arguments = original
            // NSArgumentDomain contains strings for flags passed to a development/test launch.
            arguments["CanvasRemember"] = "NO"
            defaults.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
            XCTAssertFalse(Settings.rememberCanvas)
            arguments["CanvasRemember"] = "YES"
            defaults.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
            XCTAssertTrue(Settings.rememberCanvas)
        }
    }

    func testSwitcherEdgeDefaultsToBottomAndRoundTrips() async {
        await MainActor.run {
            let defaults = UserDefaults.standard
            let saved = defaults.object(forKey: "SwitcherEdge")
            defer { defaults.set(saved, forKey: "SwitcherEdge") }
            defaults.removeObject(forKey: "SwitcherEdge")
            XCTAssertEqual(Settings.switcherEdge, .bottom)
            for edge in SwitcherEdge.allCases {
                Settings.switcherEdge = edge
                XCTAssertEqual(Settings.switcherEdge, edge)
            }
            defaults.set("diagonal", forKey: "SwitcherEdge")
            XCTAssertEqual(Settings.switcherEdge, .bottom)
        }
    }

    func testNavigationPreferencesDefaultAndRoundTrip() async {
        await MainActor.run {
            let defaults = UserDefaults.standard
            let keys = ["autoCenterAfterFourFingerPan", "singleClickBehavior",
                        "windowSnapStrength", "cameraPanSensitivity"]
            let saved = keys.map { defaults.object(forKey: $0) }
            defer {
                for (key, value) in zip(keys, saved) {
                    if let value { defaults.set(value, forKey: key) }
                    else { defaults.removeObject(forKey: key) }
                }
            }
            keys.forEach { defaults.removeObject(forKey: $0) }
            XCTAssertTrue(Settings.autoCenterAfterFourFingerPan)
            XCTAssertEqual(Settings.singleClickBehavior, .centerWindow)
            XCTAssertEqual(Settings.windowSnapStrength, .strong)
            XCTAssertEqual(Settings.cameraPanSensitivity, .high)
            XCTAssertEqual(Settings.cameraPanSensitivity.multiplier, 1.35)
            XCTAssertEqual(Settings.CameraPanSensitivity.normal.multiplier, 1)
            XCTAssertEqual(Settings.CameraPanSensitivity.veryHigh.multiplier, 1.6)

            Settings.autoCenterAfterFourFingerPan = false
            XCTAssertFalse(Settings.autoCenterAfterFourFingerPan)
            for behavior in Settings.SingleClickBehavior.allCases {
                Settings.singleClickBehavior = behavior
                XCTAssertEqual(defaults.string(forKey: "singleClickBehavior"), behavior.rawValue)
                XCTAssertEqual(Settings.singleClickBehavior, behavior)
            }
            for strength in Settings.WindowSnapStrength.allCases {
                Settings.windowSnapStrength = strength
                XCTAssertEqual(defaults.string(forKey: "windowSnapStrength"), strength.rawValue)
                XCTAssertEqual(Settings.windowSnapStrength, strength)
            }
            for sensitivity in Settings.CameraPanSensitivity.allCases {
                Settings.cameraPanSensitivity = sensitivity
                XCTAssertEqual(defaults.string(forKey: "cameraPanSensitivity"), sensitivity.rawValue)
                XCTAssertEqual(Settings.cameraPanSensitivity, sensitivity)
            }
            defaults.set("invalid", forKey: "singleClickBehavior")
            defaults.set("invalid", forKey: "windowSnapStrength")
            defaults.set("invalid", forKey: "cameraPanSensitivity")
            XCTAssertEqual(Settings.singleClickBehavior, .centerWindow)
            XCTAssertEqual(Settings.windowSnapStrength, .strong)
            XCTAssertEqual(Settings.cameraPanSensitivity, .high)
        }
    }
}
