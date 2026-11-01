import Foundation
import XCTest
@testable import PerimeterCore

final class GameTests: XCTestCase {
    /// The first map's ten spots beside the road (its old build pads).
    let spots = AutoPlayer.firstMapSpots

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
        let game = GameState(level: level, catalog: catalog)
        XCTAssertEqual(game.buildable.count, 79, "Every open tile off the road takes a position")
        for spot in spots { XCTAssertTrue(game.buildable.contains(spot), "Spot \(spot) is open ground") }
        XCTAssertEqual(level.waves.count, 50, "The first map runs 50 rounds")
        XCTAssertEqual(level.waves.filter { $0.boss == true }.count, 7)
        for type in catalog.positions {
            XCTAssertEqual(type.levels.count, 2, "\(type.id) should have levels 1 and 2")
            XCTAssertEqual(type.specializations?.count, 2, "\(type.id) should have a 3A and a 3B")
            for level in type.levels + (type.specializations ?? []) {
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
        XCTAssertFalse(game.build("rifle_squad", at: spots[3]).isEmpty)
        XCTAssertEqual(game.supply, 90)
        XCTAssertTrue(game.build("rifle_squad", at: spots[3]).isEmpty, "A tile holds one position")
        XCTAssertTrue(game.build("mg_nest", at: spots[4]).isEmpty, "Can't afford a machine gun with 90 left")
        let id = try XCTUnwrap(game.position(at: spots[3])?.id)
        XCTAssertFalse(game.upgrade(id).isEmpty)
        XCTAssertEqual(game.supply, 20)
        XCTAssertEqual(game.position(id: id)?.level, 1)
        let p = try XCTUnwrap(game.position(id: id))
        XCTAssertEqual(game.upgradeOptions(of: p).map(\.title), ["Spec ops", "Grenadiers"], "Level 3 is a choice")
        XCTAssertEqual(game.refund(for: id), 91)
        game.grantSupply(200)
        XCTAssertFalse(game.upgrade(id, branch: 1).isEmpty)
        XCTAssertEqual(game.supply, 50)
        let top = try XCTUnwrap(game.position(id: id))
        XCTAssertEqual(top.levelName, "3B")
        XCTAssertEqual(game.levelSpec(of: top)?.title, "Grenadiers")
        XCTAssertFalse(game.canUpgrade(id), "Level 3 is the top")
        XCTAssertEqual(game.refund(for: id), 210)
        game.sell(id)
        XCTAssertEqual(game.supply, 260)
        XCTAssertNil(game.position(at: spots[3]))
    }

    /// Any open tile takes a position, right next to another one too; the road,
    /// trees, buildings, the Command Post and the map's edge don't.
    func testBuildAnywhereOnOpenGround() throws {
        let (level, catalog) = try load()
        let game = GameState(level: level, catalog: catalog)
        game.grantSupply(1000)
        XCTAssertFalse(game.build("rifle_squad", at: TileCoord(2, 3)).isEmpty, "Open ground beside the road")
        XCTAssertFalse(game.build("mg_nest", at: TileCoord(3, 3)).isEmpty, "The tile right next to it")
        XCTAssertEqual(game.position(at: TileCoord(3, 3))?.center, Vec2(3.5, 3.5), "Positions stand in the middle of their tile")
        XCTAssertFalse(game.canBuild("rifle_squad", at: TileCoord(3, 3)), "One position per tile")
        XCTAssertFalse(game.canBuild("rifle_squad", at: TileCoord(4, 1)), "Not on the road")
        XCTAssertFalse(game.canBuild("rifle_squad", at: TileCoord(0, 0)), "Not in the trees")
        XCTAssertFalse(game.canBuild("rifle_squad", at: TileCoord(7, 3)), "Not on a building")
        XCTAssertFalse(game.canBuild("rifle_squad", at: TileCoord(4, 13)), "Not on the Command Post")
        XCTAssertFalse(game.canBuild("rifle_squad", at: TileCoord(9, 3)), "Not off the map")
        XCTAssertFalse(game.canBuild("rifle_squad", at: TileCoord(-1, 3)), "Not off the map")
        XCTAssertEqual(TileCoord(containing: Vec2(3.9, 7.2)), TileCoord(3, 7))
        XCTAssertEqual(TileCoord("6,11"), TileCoord(6, 11))
        let id = try XCTUnwrap(game.position(at: TileCoord(2, 3))?.id)
        game.sell(id)
        XCTAssertTrue(game.isFree(TileCoord(2, 3)), "Selling frees the tile")
    }

    func testArmorPierceAndSplash() throws {
        let (level, catalog) = try load()
        let game = GameState(level: level, catalog: catalog)
        let armored = Zombie(id: 1, type: "armored", health: 140, maxHealth: 140, distance: 0, speed: 1, lane: 0, reward: 1)
        let rifle = try XCTUnwrap(catalog.position("rifle_squad")?.levels[0])
        XCTAssertEqual(game.hitDamage(rifle, on: armored), rifle.damage * 0.15, accuracy: 0.001,
                       "Rifle rounds barely scratch armor")
        let sniper = try XCTUnwrap(catalog.position("sniper_team")?.levels[0])
        XCTAssertEqual(game.hitDamage(sniper, on: armored), sniper.damage, accuracy: 0.001, "A sniper pierces it")
        XCTAssertNotNil(catalog.position("rifle_squad")?.specializations?[1].splash, "Grenadiers splash")
    }

    func testNoDefenseLoses() throws {
        let (level, catalog) = try load()
        let game = GameState(level: level, catalog: catalog)
        let events = play(game)
        XCTAssertEqual(game.phase, .lost)
        XCTAssertTrue(events.contains(.lost))
        XCTAssertLessThanOrEqual(game.wavesStarted, 3, "Undefended, the Command Post should fall in the first three rounds")
    }

    func testTwoRiflesHoldTheFirstWave() throws {
        let (level, catalog) = try load()
        let game = GameState(level: level, catalog: catalog)
        game.build("rifle_squad", at: spots[3])
        game.build("rifle_squad", at: spots[4])
        let events = play(game) { game in
            if case .pause = game.phase { return true }
            return false
        }
        XCTAssertTrue(events.contains(.waveCleared(number: 1, bonus: 17)))
        XCTAssertGreaterThanOrEqual(game.commandPostHealth, 18)
        XCTAssertEqual(game.kills + (20 - game.commandPostHealth), 8, "Every Walker in round 1 is killed or gets through")
        XCTAssertGreaterThan(game.supply, 30)
    }

    func testAShootingPositionTurnsToItsTarget() throws {
        let (level, catalog) = try load()
        let game = GameState(level: level, catalog: catalog)
        game.build("sniper_team", at: spots[1])
        let events = play(game) { $0.kills > 0 }
        let shots = events.filter { if case .shot = $0 { return true }; return false }
        XCTAssertFalse(shots.isEmpty)
        let sniper = try XCTUnwrap(game.position(at: spots[1]))
        XCTAssertEqual(sniper.kills, 1)
    }

    func testMachineGunSlows() throws {
        let (level, catalog) = try load()
        let game = GameState(level: level, catalog: catalog)
        game.build("mg_nest", at: spots[1])
        play(game) { game in game.zombies.contains { $0.slowTime > 0 } }
        let slowed = try XCTUnwrap(game.zombies.first { $0.slowTime > 0 })
        XCTAssertLessThan(slowed.currentSpeed, slowed.speed)
    }

    func testSameChoicesPlaySameWay() throws {
        let (level, catalog) = try load()
        func run() -> (Int, Int, Int) {
            let game = GameState(level: level, catalog: catalog, seed: 42)
            game.build("rifle_squad", at: spots[3])
            game.build("rifle_squad", at: spots[4])
            play(game, maxSeconds: 120)
            return (game.kills, game.supply, game.commandPostHealth)
        }
        let a = run(), b = run()
        XCTAssertEqual(a.0, b.0)
        XCTAssertEqual(a.1, b.1)
        XCTAssertEqual(a.2, b.2)
    }

    /// Plays all 50 rounds with a strong build order, for real.
    func testAGoodDefenseWinsAllFiftyRounds() throws {
        let (level, catalog) = try load()
        let game = GameState(level: level, catalog: catalog)
        var player = AutoPlayer(steps: AutoPlayer.firstMap)
        let events = player.play(game)
        guard case .won(let stars) = game.phase else {
            return XCTFail("A full defense should win; ended \(game.phase) on round \(game.wavesStarted) with \(game.commandPostHealth) health")
        }
        XCTAssertTrue(player.isFinished, "Every position reaches level 3")
        XCTAssertEqual(game.wavesStarted, 50)
        XCTAssertGreaterThanOrEqual(stars, 2)
        XCTAssertTrue(events.contains { if case .killed(_, "behemoth", _, _) = $0 { return true }; return false },
                      "The Behemoth is killed")
    }

    /// The same defense without level 3 holds a long while but not to the end.
    func testWithoutLevelThreeTheLateRoundsAreLost() throws {
        let (level, catalog) = try load()
        var upgraded: Set<TileCoord> = []
        let steps = AutoPlayer.firstMap.filter { step in
            guard case .upgrade(let tile, _) = step else { return true }
            return upgraded.insert(tile).inserted
        }
        XCTAssertEqual(steps.count, 20)
        let game = GameState(level: level, catalog: catalog)
        var player = AutoPlayer(steps: steps)
        player.play(game)
        XCTAssertEqual(game.phase, .lost)
        XCTAssertGreaterThan(game.wavesStarted, 20, "Levels 1 and 2 hold the early rounds")
        XCTAssertLessThan(game.wavesStarted, 50)
    }
}
