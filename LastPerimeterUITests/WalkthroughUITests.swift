import XCTest

/// Plays through the first level the way a player would and saves a screenshot
/// at each step. The automatic checks run this on iPhone Pro Max, a regular
/// iPhone and the iPhone Duo, and name each picture after the phone and step.
final class WalkthroughUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
    }

    private func launch(_ arguments: [String] = [], landscape: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"] + arguments
        XCUIDevice.shared.orientation = landscape ? .landscapeLeft : .portrait
        app.launch()
        return app
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Menu, build a rifle squad, start the first wave and watch it come in.
    func testPlayFirstWave() {
        let app = launch()
        XCTAssertTrue(element(app, "play-level").waitForExistence(timeout: 20), "The menu shows the first level")
        capture(app, "1-menu")

        element(app, "play-level").tap()
        let pad = element(app, "slot-3")
        XCTAssertTrue(pad.waitForExistence(timeout: 10), "The battlefield shows its build pads")
        XCTAssertTrue(element(app, "start-wave").exists, "The first wave waits for the player")
        if UIDeviceName.current.contains("Duo") {
            XCTAssertTrue(element(app, "side-bar").exists, "The folded Duo puts the controls in a side bar beside the map")
        }
        capture(app, "2-battlefield")

        pad.tap()
        let rifle = element(app, "build-rifle_squad")
        XCTAssertTrue(rifle.waitForExistence(timeout: 5), "Tapping a pad opens the build menu")
        capture(app, "3-build-menu")

        rifle.tap()
        XCTAssertTrue(element(app, "position-card").waitForExistence(timeout: 5), "The new position shows its card")
        XCTAssertTrue(element(app, "position-3").exists, "The rifle squad stands on the pad")
        capture(app, "4-position-card")

        element(app, "start-wave").tap()
        element(app, "speed").tap()
        sleep(9)
        capture(app, "5-first-wave")
    }

    /// A built-up defence in the middle of wave four, with a rifle squad picked.
    func testBattle() {
        let app = launch(["-demo", "-startWave", "4", "-warmup", "22", "-selectPosition", "4"])
        XCTAssertTrue(element(app, "position-card").waitForExistence(timeout: 20), "The picked position shows its card")
        sleep(2)
        capture(app, "6-battle")

        element(app, "upgrade").tap()
        sleep(1)
        capture(app, "7-upgraded")
    }

    /// The screens at the end of a level.
    func testEndScreens() {
        let app = launch(["-demo", "-endScreen", "win"])
        XCTAssertTrue(element(app, "end-screen").waitForExistence(timeout: 20), "The level ends with a result")
        sleep(1)
        capture(app, "8-victory")
    }

    /// The open iPhone Duo's screen, drawn at its size on the Pro Max (the
    /// simulator can't unfold the Duo).
    func testOpenDuoLayouts() throws {
        let name = UIDeviceName.current
        try XCTSkipUnless(name.contains("Pro Max"), "The open Duo pictures are taken once, on the Pro Max")

        var app = launch(["-openDuoPreview"], landscape: true)
        XCTAssertTrue(element(app, "play-level").waitForExistence(timeout: 20))
        capture(app, "9-open-duo-menu")
        app.terminate()

        app = launch(["-openDuoPreview", "-demo", "-startWave", "3", "-warmup", "20", "-selectPosition", "3"], landscape: true)
        XCTAssertTrue(element(app, "command-panel").waitForExistence(timeout: 20), "The open Duo puts the commands beside the map")
        sleep(2)
        capture(app, "10-open-duo-battle")
        app.terminate()

        app = launch(["-openDuoPreview", "-play", "-selectSlot", "0"], landscape: true)
        XCTAssertTrue(element(app, "build-menu").waitForExistence(timeout: 20))
        capture(app, "11-open-duo-build")
    }
}

private enum UIDeviceName {
    /// The simulator's name, such as "iPhone 17 Pro Max".
    static var current: String {
        ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? ""
    }
}
