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

    /// The middle of a map tile, where a tap lands on it.
    private func tile(_ app: XCUIApplication, _ col: Int, _ row: Int) -> XCUICoordinate {
        let map = element(app, "battlefield").frame
        let size = CGSize(width: map.width / 9, height: map.height / 15)
        return app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: map.minX + (CGFloat(col) + 0.5) * size.width,
                                 dy: map.minY + (CGFloat(row) + 0.5) * size.height))
    }

    /// The middle of a map tile when the open Duo draws the map sideways (Command
    /// put away): the map's top on the left, its left-hand edge along the bottom.
    private func sidewaysTile(_ app: XCUIApplication, _ col: Int, _ row: Int) -> XCUICoordinate {
        let map = element(app, "battlefield").frame
        let size = CGSize(width: map.width / 15, height: map.height / 9)
        return app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: map.minX + (CGFloat(row) + 0.5) * size.width,
                                 dy: map.minY + (CGFloat(8 - col) + 0.5) * size.height))
    }

    /// Drags a position from the panel onto a tile. A dragged position lands
    /// on the tile just above the fingertip, so the finger stops a little lower.
    private func drag(_ app: XCUIApplication, _ type: String, toCol col: Int, row: Int) {
        let from = element(app, "tray-\(type)").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let to = tile(app, col, row).withOffset(CGVector(dx: 0, dy: 34))
        from.press(forDuration: 0.2, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.3)
    }

    /// Menu, drag a rifle squad onto the map, tap a tile to build another, fold
    /// the panel away and back, then start the first round and watch it at 2x.
    func testPlayFirstRound() {
        let app = launch()
        XCTAssertTrue(element(app, "play-level").waitForExistence(timeout: 20), "The menu shows the first level")
        capture(app, "1-menu")

        element(app, "play-level").tap()
        XCTAssertTrue(element(app, "tray-rifle_squad").waitForExistence(timeout: 10), "The panel offers positions to drag")
        XCTAssertTrue(element(app, "battlefield").exists, "The battlefield shows")
        XCTAssertTrue(element(app, "start-wave").exists, "The first round waits for the player")
        XCTAssertTrue(element(app, "pause").exists, "There's a pause button")
        XCTAssertTrue(element(app, "speed").exists, "There's a speed button")
        if UIDeviceName.current.contains("Duo") {
            XCTAssertTrue(element(app, "side-bar").exists, "The folded Duo keeps its side bar, now over the map")
        }
        capture(app, "2-battlefield")

        drag(app, "rifle_squad", toCol: 3, row: 3)
        XCTAssertTrue(element(app, "position-3-3").waitForExistence(timeout: 5), "Dropping a position on an open tile builds it there")
        XCTAssertTrue(element(app, "position-card").waitForExistence(timeout: 5), "The new position shows its card")
        capture(app, "3-dragged-onto-tile")

        tile(app, 2, 9).tap()
        let rifle = element(app, "build-rifle_squad")
        XCTAssertTrue(rifle.waitForExistence(timeout: 5), "Tapping a free tile offers what can go on it")
        capture(app, "4-tap-a-tile")
        rifle.tap()
        XCTAssertTrue(element(app, "position-2-9").waitForExistence(timeout: 5), "Tapping a position in the list builds it on the tile")

        element(app, "panel-collapse").tap()
        XCTAssertTrue(element(app, "panel-expand").waitForExistence(timeout: 5), "The panel folds away to a tab")
        XCTAssertTrue(element(app, "start-wave").exists, "The round button stays within reach")
        capture(app, "5-panel-folded-away")
        element(app, "panel-expand").tap()
        XCTAssertTrue(element(app, "panel-collapse").waitForExistence(timeout: 5), "...and comes back")

        element(app, "start-wave").tap()
        element(app, "speed").tap()
        XCTAssertEqual(element(app, "speed").label, "Speed 2 times", "One tap on speed plays at 2x")
        sleep(5)
        capture(app, "6-first-round-2x")
    }

    /// The map while a position is dragged over it: green with its reach on open
    /// ground, red on the road.
    func testDragPreview() {
        var app = launch(["-play", "-dragPreview", "sniper_team", "5,4"])
        XCTAssertTrue(element(app, "tray").waitForExistence(timeout: 20))
        sleep(1)
        capture(app, "7-drag-open-tile")
        app.terminate()

        app = launch(["-play", "-dragPreview", "mg_nest", "3,2"])
        XCTAssertTrue(element(app, "tray").waitForExistence(timeout: 20))
        sleep(1)
        capture(app, "8-drag-on-the-road")
    }

    /// A level 2 rifle squad offers its two level 3 versions; pick one.
    func testLevelThreeChoice() {
        let app = launch(["-demo", "-startWave", "4", "-warmup", "22", "-selectPosition", "6,5"])
        let choice = element(app, "upgrade-3a")
        XCTAssertTrue(choice.waitForExistence(timeout: 20), "A level 2 position offers level 3A")
        XCTAssertTrue(element(app, "upgrade-3b").exists, "...and level 3B")
        sleep(1)
        capture(app, "9-level-3-choice")

        element(app, "upgrade-3b").tap()
        sleep(1)
        XCTAssertFalse(element(app, "upgrade-3a").exists, "Once picked, the choice is made")
        capture(app, "10-level-3-picked")
    }

    /// Round 25 played for real: the Behemoth's first appearance, then paused at 2x.
    func testBossRoundAndPause() {
        let app = launch(["-playTo", "25", "-warmup", "24", "-speed", "2", "-selectPosition", "6,5"])
        XCTAssertTrue(element(app, "position-card").waitForExistence(timeout: 240), "Round 25 is reached with a defense up")
        XCTAssertTrue(element(app, "wave-label").label.contains("25"), "The strip shows round 25")
        sleep(2)
        capture(app, "11-boss-round")

        element(app, "pause").tap()
        XCTAssertTrue(element(app, "paused-banner").waitForExistence(timeout: 5), "Pausing says so over the map")
        capture(app, "12-paused")
        element(app, "pause").tap()
        XCTAssertFalse(element(app, "paused-banner").exists, "Play carries on")
    }

    /// All 50 rounds played for real, then the end screen.
    func testEndScreens() {
        let app = launch(["-endScreen", "win"])
        XCTAssertTrue(element(app, "end-screen").waitForExistence(timeout: 420), "The level ends with a result")
        sleep(1)
        capture(app, "13-victory")
    }

    /// The open iPhone Duo's screen, drawn at its size on the Pro Max (the
    /// simulator can't unfold the Duo).
    func testOpenDuoLayouts() throws {
        let name = UIDeviceName.current
        try XCTSkipUnless(name.contains("Pro Max"), "The open Duo pictures are taken once, on the Pro Max")

        var app = launch(["-openDuoPreview"], landscape: true)
        XCTAssertTrue(element(app, "play-level").waitForExistence(timeout: 20))
        capture(app, "14-open-duo-menu")
        app.terminate()

        // Command shown (the first time), then put away to the rail and brought back.
        app = launch(["-openDuoPreview", "-play"], landscape: true)
        XCTAssertTrue(element(app, "command-panel").waitForExistence(timeout: 20), "The open Duo puts Command beside the map")
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "supply").count, 1, "Supply shows once")
        capture(app, "15-open-duo-command-shown")
        element(app, "command-hide").tap()
        XCTAssertTrue(element(app, "command-rail").waitForExistence(timeout: 5), "Command folds away to a slim rail")
        XCTAssertFalse(element(app, "command-panel").exists, "...and the Command column is gone")
        for id in ["start-wave", "pause", "speed", "supply", "cp-health", "tray-rifle_squad"] {
            XCTAssertTrue(element(app, id).exists, "\(id) stays in reach with Command put away")
        }
        let map = element(app, "battlefield").frame
        XCTAssertGreaterThan(map.width, map.height, "With Command put away the map turns sideways to fill the screen")
        sleep(1)
        capture(app, "16-open-duo-command-hidden")
        // Drag a rifle squad from the rail onto the sideways map. The tile it
        // lands on is a little above the finger, so the finger stops lower.
        let from = element(app, "tray-rifle_squad").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let to = sidewaysTile(app, 3, 3).withOffset(CGVector(dx: 0, dy: map.height / 9 * 0.6))
        from.press(forDuration: 0.2, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.3)
        XCTAssertTrue(element(app, "position-3-3").waitForExistence(timeout: 5), "Dragging from the rail builds on the sideways map")
        XCTAssertTrue(element(app, "position-card").waitForExistence(timeout: 5), "The new position's card opens over the map")
        sleep(1)
        capture(app, "17-open-duo-hidden-dragged")
        element(app, "command-show").tap()
        XCTAssertTrue(element(app, "command-panel").waitForExistence(timeout: 5), "...and comes back")
        app.terminate()

        app = launch(["-openDuoPreview", "-demo", "-startWave", "3", "-warmup", "20", "-selectPosition", "6,5"], landscape: true)
        XCTAssertTrue(element(app, "command-panel").waitForExistence(timeout: 20), "The open Duo puts Command beside the map")
        XCTAssertTrue(element(app, "upgrade-3a").waitForExistence(timeout: 10), "The level 3 choice shows with room to explain")
        sleep(2)
        capture(app, "18-open-duo-battle")
        app.terminate()

        // With Command put away, a position's card shows in the panel beside the map.
        app = launch(["-openDuoPreview", "-hideCommand", "-demo", "-startWave", "3", "-warmup", "20", "-selectPosition", "6,5"], landscape: true)
        XCTAssertTrue(element(app, "command-rail").waitForExistence(timeout: 20), "Command starts put away when asked")
        XCTAssertTrue(element(app, "position-card").waitForExistence(timeout: 10), "The card shows beside the map instead")
        XCTAssertTrue(element(app, "start-wave").exists || element(app, "wave-status").exists, "The round button stays in the rail")
        sleep(2)
        capture(app, "19-open-duo-battle-command-hidden")
        app.terminate()

        app = launch(["-openDuoPreview", "-play", "-selectTile", "2,5"], landscape: true)
        XCTAssertTrue(element(app, "build-menu").waitForExistence(timeout: 20))
        XCTAssertTrue(element(app, "tray-rifle_squad").exists, "The positions to drag sit beside the map")
        capture(app, "20-open-duo-build")
    }
}

private enum UIDeviceName {
    /// The simulator's name, such as "iPhone 17 Pro Max".
    static var current: String {
        ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? ""
    }
}
