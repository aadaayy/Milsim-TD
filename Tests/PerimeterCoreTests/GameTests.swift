import Foundation
import XCTest
@testable import PerimeterCore

final class GameTests: XCTestCase {
    /// The app's Data folder, found relative to this file.
    static let dataFolder = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("LastPerimeter/Data")

    func load() throws -> (LevelSpec, GameCatalog) {
        let catalog = try GameCatalog.decode(
            positions: Data(contentsOf: Self.dataFolder.appendingPathComponent("positions.json")),
            zombies: Data(contentsOf: Self.dataFolder.appendingPathComponent("zombies.json")))
        let level = try LevelSpec.decode(Data(contentsOf: Self.dataFolder.appendingPathComponent("level_01.json")))
        return (level, catalog)
    }

    /// Runs the game a 60th of a second at a time, sending each wave as soon as it can,
    /// until `stop` says so or the level ends. Returns every event.
    @discardableResult
    func play(_ game: GameState, maxSeconds: Double = 900, stop: (GameState) -> Bool = { _ in false }) -> [GameEvent] {
        var events: [GameEvent] = []
        var t = 0.0
        while t < maxSeconds && !game.isOver && !stop(game) {
            if case .build = game.phase { events += game.startNextWave() }
            events += game.tick(1.0 / 60)
            t += 1.0 / 60
        }
        return events
    }

    func testDataFilesAreValid() throws {
        let (level, catalog) = try load()
        XCTAssertEqual(level.problems(catalog: catalog), [])
        XCTAssertEqual(level.slots.count, 10)
        for type in catalog.positions {
            XCTAssertEqual(type.levels.count, 2, "\(type.id) should have levels 1 and 2 for now")
            for level in type.levels {
                XCTAssertGreaterThan(level.cost, 0)
                XCTAssertGreaterThan(level.range, 0)
                XCTAssertGreaterThan(level.fireInterval, 0)
            }
        }
    }

    func testEveryPathTileIsRoad() throws {
        let (level, _) = try load()
        let track = PathTrack(tiles: level.path)
        XCTAssertEqual(track.length, 25, accuracy: 0.001)
        for row in 0..<level.rows {
            for col in 0..<level.cols {
                let tile = level.tile(col: col, row: row)
                if track.covers(col: col, row: row) && row < 12 {
                    XCTAssertEqual(tile, .road, "Path crosses \(col),\(row) but the map shows \(tile)")
                }
                if tile == .road {
                    XCTAssertTrue(track.covers(col: col, row: row), "Road tile \(col),\(row) isn't on the path")
                }
            }
        }
    }

    func testFacings() {
        XCTAssertEqual(Facing(direction: Vec2(0, -1)), .n)
        XCTAssertEqual(Facing(direction: Vec2(1, 0)), .e)
        XCTAssertEqual(Facing(direction: Vec2(0, 1)), .s)
        XCTAssertEqual(Facing(direction: Vec2(-1, -1)), .nw)
        XCTAssertEqual(Facing(fourWay: Vec2(0.2, 0.9)), .s)
    }

    func testBuildUpgradeAndSell() throws {
        let (level, catalog) = try load()
        let game = GameState(level: level, catalog: catalog)
        XCTAssertEqual(game.supply, 150)
        XCTAssertFalse(game.build("rifle_squad", onSlot: 3).isEmpty)
        XCTAssertEqual(game.supply, 90)
        XCTAssertTrue(game.build("rifle_squad", onSlot: 3).isEmpty, "A slot holds one position")
        XCTAssertTrue(game.build("mg_nest", onSlot: 4).isEmpty, "Can't afford a machine gun with 90 left")
        let id = try XCTUnwrap(game.position(onSlot: 3)?.id)
        XCTAssertFalse(game.upgrade(id).isEmpty)
        XCTAssertEqual(game.supply, 20)
        XCTAssertEqual(game.position(id: id)?.level, 1)
        XCTAssertFalse(game.canUpgrade(id), "Level 2 is the top for now")
        XCTAssertEqual(game.refund(for: id), 91)
        game.sell(id)
        XCTAssertEqual(game.supply, 111)
        XCTAssertNil(game.position(onSlot: 3))
    }

    func testNoDefenseLoses() throws {
        let (level, catalog) = try load()
        let game = GameState(level: level, catalog: catalog)
        let events = play(game)
        XCTAssertEqual(game.phase, .lost)
        XCTAssertTrue(events.contains(.lost))
        XCTAssertLessThanOrEqual(game.wavesStarted, 2, "Undefended, the Command Post should fall in the first two waves")
    }

    func testTwoRiflesHoldTheFirstWave() throws {
        let (level, catalog) = try load()
        let game = GameState(level: level, catalog: catalog)
        game.build("rifle_squad", onSlot: 3)
        game.build("rifle_squad", onSlot: 4)
        let events = play(game) { game in
            if case .pause = game.phase { return true }
            return false
        }
        XCTAssertTrue(events.contains(.waveCleared(number: 1, bonus: 30)))
        XCTAssertGreaterThanOrEqual(game.commandPostHealth, 13)
        XCTAssertEqual(game.kills + (15 - game.commandPostHealth), 8, "Every Walker in wave 1 is killed or gets through")
        XCTAssertGreaterThan(game.supply, 30)
    }

    func testAShootingPositionTurnsToItsTarget() throws {
        let (level, catalog) = try load()
        let game = GameState(level: level, catalog: catalog)
        game.build("sniper_team", onSlot: 1)
        let events = play(game) { $0.kills > 0 }
        let shots = events.filter { if case .shot = $0 { return true }; return false }
        XCTAssertFalse(shots.isEmpty)
        let sniper = try XCTUnwrap(game.position(onSlot: 1))
        XCTAssertEqual(sniper.kills, 1)
    }

    func testMachineGunSlows() throws {
        let (level, catalog) = try load()
        let game = GameState(level: level, catalog: catalog)
        game.build("mg_nest", onSlot: 1)
        play(game) { game in game.zombies.contains { $0.slowTime > 0 } }
        let slowed = try XCTUnwrap(game.zombies.first { $0.slowTime > 0 })
        XCTAssertLessThan(slowed.currentSpeed, slowed.speed)
    }

    func testSameChoicesPlaySameWay() throws {
        let (level, catalog) = try load()
        func run() -> (Int, Int, Int) {
            let game = GameState(level: level, catalog: catalog, seed: 42)
            game.build("rifle_squad", onSlot: 3)
            game.build("rifle_squad", onSlot: 4)
            play(game, maxSeconds: 120)
            return (game.kills, game.supply, game.commandPostHealth)
        }
        let a = run(), b = run()
        XCTAssertEqual(a.0, b.0)
        XCTAssertEqual(a.1, b.1)
        XCTAssertEqual(a.2, b.2)
    }

    func testAGoodDefenseWins() throws {
        let (level, catalog) = try load()
        let game = GameState(level: level, catalog: catalog)
        // Build as supply allows, in this order, upgrading once everything is placed.
        let plan: [(String, Int)] = [("rifle_squad", 3), ("rifle_squad", 4), ("mg_nest", 1), ("mg_nest", 5),
                                     ("sniper_team", 7), ("rifle_squad", 6), ("mg_nest", 8), ("sniper_team", 9)]
        var t = 0.0
        while !game.isOver && t < 1200 {
            if let next = plan.first(where: { game.position(onSlot: $0.1) == nil }) {
                game.build(next.0, onSlot: next.1)
            } else if let p = game.positions.first(where: { game.canUpgrade($0.id) }) {
                game.upgrade(p.id)
            }
            if case .build = game.phase { game.startNextWave() }
            _ = game.tick(1.0 / 60)
            t += 1.0 / 60
        }
        guard case .won(let stars) = game.phase else {
            return XCTFail("A full defense should win; ended \(game.phase) on wave \(game.wavesStarted) with \(game.commandPostHealth) health")
        }
        XCTAssertGreaterThanOrEqual(stars, 1)
        XCTAssertGreaterThan(game.commandPostHealth, 0)
    }
}
