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

    /// Menu, build a rifle squad, start the first round and watch it come in at 2x.
    func testPlayFirstRound() {
        let app = launch()
        XCTAssertTrue(element(app, "play-level").waitForExistence(timeout: 20), "The menu shows the first level")
        capture(app, "1-menu")

        element(app, "play-level").tap()
        let pad = element(app, "slot-3")
        XCTAssertTrue(pad.waitForExistence(timeout: 10), "The battlefield shows its build pads")
        XCTAssertTrue(element(app, "start-wave").exists, "The first round waits for the player")
        XCTAssertTrue(element(app, "pause").exists, "There's a pause button")
        XCTAssertTrue(element(app, "speed").exists, "There's a speed button")
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
        XCTAssertEqual(element(app, "speed").label, "Speed 2 times", "One tap on speed plays at 2x")
        sleep(5)
        capture(app, "5-first-round-2x")
    }

    /// A level 2 rifle squad offers its two level 3 versions; pick one.
    func testLevelThreeChoice() {
        let app = launch(["-demo", "-startWave", "4", "-warmup", "22", "-selectPosition", "3"])
        let choice = element(app, "upgrade-3a")
        XCTAssertTrue(choice.waitForExistence(timeout: 20), "A level 2 position offers level 3A")
        XCTAssertTrue(element(app, "upgrade-3b").exists, "...and level 3B")
        sleep(1)
        capture(app, "6-level-3-choice")

        element(app, "upgrade-3b").tap()
        sleep(1)
        XCTAssertFalse(element(app, "upgrade-3a").exists, "Once picked, the choice is made")
        capture(app, "7-level-3-picked")
    }

    /// Round 25 played for real: the Behemoth's first appearance, then paused at 2x.
    func testBossRoundAndPause() {
        let app = launch(["-playTo", "25", "-warmup", "24", "-speed", "2", "-selectPosition", "3"])
        XCTAssertTrue(element(app, "position-card").waitForExistence(timeout: 240), "Round 25 is reached with a defense up")
        XCTAssertTrue(element(app, "wave-label").label.contains("25"), "The strip shows round 25")
        sleep(2)
        capture(app, "8-boss-round")

        element(app, "pause").tap()
        XCTAssertTrue(element(app, "paused-banner").waitForExistence(timeout: 5), "Pausing says so over the map")
        capture(app, "9-paused")
        element(app, "pause").tap()
        XCTAssertFalse(element(app, "paused-banner").exists, "Play carries on")
    }

    /// All 50 rounds played for real, then the end screen.
    func testEndScreens() {
        let app = launch(["-endScreen", "win"])
        XCTAssertTrue(element(app, "end-screen").waitForExistence(timeout: 420), "The level ends with a result")
        sleep(1)
        capture(app, "10-victory")
    }

    /// The open iPhone Duo's screen, drawn at its size on the Pro Max (the
    /// simulator can't unfold the Duo).
    func testOpenDuoLayouts() throws {
        let name = UIDeviceName.current
        try XCTSkipUnless(name.contains("Pro Max"), "The open Duo pictures are taken once, on the Pro Max")

        var app = launch(["-openDuoPreview"], landscape: true)
        XCTAssertTrue(element(app, "play-level").waitForExistence(timeout: 20))
        capture(app, "11-open-duo-menu")
        app.terminate()

        app = launch(["-openDuoPreview", "-demo", "-startWave", "3", "-warmup", "20", "-selectPosition", "3"], landscape: true)
        XCTAssertTrue(element(app, "command-panel").waitForExistence(timeout: 20), "The open Duo puts the commands beside the map")
        XCTAssertTrue(element(app, "upgrade-3a").waitForExistence(timeout: 10), "The level 3 choice shows with room to explain")
        sleep(2)
        capture(app, "12-open-duo-battle")
        app.terminate()

        app = launch(["-openDuoPreview", "-play", "-selectSlot", "0"], landscape: true)
        XCTAssertTrue(element(app, "build-menu").waitForExistence(timeout: 20))
        capture(app, "13-open-duo-build")
    }
}

private enum UIDeviceName {
    /// The simulator's name, such as "iPhone 17 Pro Max".
    static var current: String {
        ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? ""
    }
}
