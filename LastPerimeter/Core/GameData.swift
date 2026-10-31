import Foundation

/// Everything the game knows about positions and zombies, read from
/// positions.json and zombies.json. Balance numbers live only in those files.
public struct GameCatalog {
    public var positions: [PositionType]
    public var zombies: [ZombieType]

    public init(positions: [PositionType], zombies: [ZombieType]) {
        self.positions = positions
        self.zombies = zombies
    }

    public static func decode(positions: Data, zombies: Data) throws -> GameCatalog {
        let decoder = JSONDecoder()
        return GameCatalog(
            positions: try decoder.decode(PositionFile.self, from: positions).positions,
            zombies: try decoder.decode(ZombieFile.self, from: zombies).zombies
        )
    }

    public func position(_ id: String) -> PositionType? { positions.first { $0.id == id } }
    public func zombie(_ id: String) -> ZombieType? { zombies.first { $0.id == id } }

    private struct PositionFile: Decodable { var positions: [PositionType] }
    private struct ZombieFile: Decodable { var zombies: [ZombieType] }
}

/// A kind of crewed position, like the Rifle squad, with its upgrade levels.
public struct PositionType: Codable, Identifiable, Equatable {
    public var id: String
    public var name: String
    /// One line on what it's for, like "Cheap all-rounder".
    public var role: String
    /// The plain-language field manual entry.
    public var manual: String
    public var levels: [PositionLevel]
}

public struct PositionLevel: Codable, Equatable {
    /// The sprite set to draw, from sprites.json.
    public var sprite: String
    public var title: String
    /// Supply to build this level (level 1) or to upgrade to it.
    public var cost: Int
    /// Reach in tiles.
    public var range: Double
    public var damage: Double
    /// Seconds between shots.
    public var fireInterval: Double
    /// 0 (silent) to 100 (artillery). Shown now; the Noise meter comes later.
    public var noise: Int
    /// Machine guns slow infantry: speed is multiplied by this for slowSeconds.
    public var slowFactor: Double?
    public var slowSeconds: Double?
}

/// A kind of zombie.
public struct ZombieType: Codable, Identifiable, Equatable {
    public var id: String
    public var name: String
    public var manual: String
    public var health: Double
    /// Tiles per second.
    public var speed: Double
    /// Supply for a kill.
    public var reward: Int
    /// Command Post health lost when it gets through.
    public var breachDamage: Int
    /// Drawn this much bigger than life so it reads on a phone screen.
    public var drawScale: Double
}

/// One level: its map, its path, its waves and its starting numbers.
public struct LevelSpec: Codable, Equatable {
    public var id: String
    public var name: String
    public var chapter: Int
    public var place: String
    public var briefing: String
    public var cols: Int
    public var rows: Int
    /// Real size of one tile, so sprites drawn in meters come out the right size.
    public var tileMeters: Double
    /// One string per row, top row first. Each character is one tile:
    /// . grass, R road, F forest, T tin-roof building, H flat-roof building,
    /// S build slot, C Command Post ground.
    public var tiles: [String]
    /// Tile coordinates the zombies walk through, from the map edge to the Command Post.
    /// Each point is a tile's column and row; the walk goes through tile centers.
    public var path: [Vec2]
    /// Center of the Command Post, in tiles.
    public var commandPost: Vec2
    public var startSupply: Int
    public var commandPostHealth: Int
    /// Seconds between waves before the next one comes on its own.
    public var breakSeconds: Double
    public var bonusObjective: String
    public var waves: [WaveSpec]

    public static func decode(_ data: Data) throws -> LevelSpec {
        try JSONDecoder().decode(LevelSpec.self, from: data)
    }

    public enum Tile: Character {
        case grass = ".", road = "R", forest = "F", tinRoof = "T", flatRoof = "H", slot = "S", commandPost = "C"
    }

    public func tile(col: Int, row: Int) -> Tile {
        guard row >= 0, row < tiles.count else { return .grass }
        let line = Array(tiles[row])
        guard col >= 0, col < line.count else { return .grass }
        return Tile(rawValue: line[col]) ?? .grass
    }

    /// Build slots in reading order (top row first), as tile centers.
    public var slots: [Vec2] {
        var found: [Vec2] = []
        for row in 0..<rows {
            for col in 0..<cols where tile(col: col, row: row) == .slot {
                found.append(Vec2(Double(col) + 0.5, Double(row) + 0.5))
            }
        }
        return found
    }

    /// Problems with the file, in plain words (empty when it's fine).
    public func problems(catalog: GameCatalog) -> [String] {
        var problems: [String] = []
        if tiles.count != rows { problems.append("\(id): \(tiles.count) tile rows, expected \(rows)") }
        for (i, line) in tiles.enumerated() {
            if line.count != cols { problems.append("\(id): row \(i) has \(line.count) tiles, expected \(cols)") }
            for c in line where Tile(rawValue: c) == nil { problems.append("\(id): row \(i) has an unknown tile '\(c)'") }
        }
        if path.count < 2 { problems.append("\(id): the path needs at least two points") }
        for (a, b) in zip(path, path.dropFirst()) where a.x != b.x && a.y != b.y {
            problems.append("\(id): path step \(a.x),\(a.y) to \(b.x),\(b.y) isn't straight along a row or column")
        }
        if slots.isEmpty { problems.append("\(id): no build slots") }
        if waves.isEmpty { problems.append("\(id): no waves") }
        for (n, wave) in waves.enumerated() {
            for group in wave.groups where catalog.zombie(group.zombie) == nil {
                problems.append("\(id): wave \(n + 1) uses unknown zombie \(group.zombie)")
            }
        }
        return problems
    }
}

public struct WaveSpec: Codable, Equatable {
    public var groups: [SpawnGroup]
    /// Supply paid for clearing the wave.
    public var bonus: Int
}

/// A run of one zombie type in a wave: `count` of them, `interval` seconds
/// apart, starting `delay` seconds into the wave.
public struct SpawnGroup: Codable, Equatable {
    public var zombie: String
    public var count: Int
    public var interval: Double
    public var delay: Double
}
