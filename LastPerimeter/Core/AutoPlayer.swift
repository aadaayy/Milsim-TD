import Foundation

/// Plays a level by a fixed build order, taking each step as soon as supply
/// allows. The automatic checks use it to play all the rounds for real, and
/// the screenshot setups use it to reach a late round with a true defense.
public struct AutoPlayer {
    public enum Step: Equatable {
        case build(String, at: TileCoord, priority: TargetPriority = .first)
        /// `branch` picks 3A (0) or 3B (1) when the upgrade is to level 3.
        case upgrade(at: TileCoord, branch: Int = 0)
    }

    public let steps: [Step]
    /// Steps taken so far.
    public private(set) var taken = 0

    public init(steps: [Step]) {
        self.steps = steps
    }

    public var isFinished: Bool { taken >= steps.count }

    /// Takes as many steps, in order, as supply allows right now.
    public mutating func act(on game: GameState) {
        while let step = steps[safe: taken] {
            switch step {
            case .build(let type, let tile, let priority):
                guard !game.build(type, at: tile).isEmpty, let p = game.position(at: tile) else { return }
                game.setPriority(priority, for: p.id)
            case .upgrade(let tile, let branch):
                guard let p = game.position(at: tile), !game.upgrade(p.id, branch: branch).isEmpty else { return }
            }
            taken += 1
        }
    }

    /// Plays until the level ends, `stop` says so or `maxSeconds` of game time
    /// pass, a 60th of a second at a time, sending the first round at once.
    @discardableResult
    public mutating func play(_ game: GameState, maxSeconds: Double = 5000,
                              stop: (GameState) -> Bool = { _ in false }) -> [GameEvent] {
        var events: [GameEvent] = []
        var t = 0.0
        while t < maxSeconds && !game.isOver && !stop(game) {
            act(on: game)
            if case .build = game.phase { events += game.startNextWave() }
            events += game.tick(1.0 / 60)
            t += 1.0 / 60
        }
        return events
    }

    /// Ten spots on the first map beside the bends in the road, top row first.
    /// They were its fixed build pads before every open tile could take a
    /// position; the strong build order and the screenshot setups still use them.
    public static let firstMapSpots: [TileCoord] = [
        TileCoord(6, 1), TileCoord(3, 3), TileCoord(0, 4), TileCoord(6, 5), TileCoord(3, 7),
        TileCoord(8, 8), TileCoord(2, 9), TileCoord(6, 10), TileCoord(2, 11), TileCoord(6, 11),
    ]

    private static func spot(_ n: Int) -> TileCoord { firstMapSpots[n] }
    private static func place(_ type: String, _ n: Int, priority: TargetPriority = .first) -> Step {
        .build(type, at: spot(n), priority: priority)
    }
    private static func raise(_ n: Int, branch: Int = 0) -> Step { .upgrade(at: spot(n), branch: branch) }

    /// A strong defense for the first map: rifles and a machine gun early,
    /// snipers for the armor, then every position to level 3. The sniper on
    /// spot 3 aims at the strongest zombie, so it works on the bosses.
    public static let firstMap: [Step] = [
        place("rifle_squad", 1), place("rifle_squad", 7), place("mg_nest", 4),
        raise(1), place("sniper_team", 3, priority: .strongest), raise(4),
        raise(7), place("mg_nest", 9), place("sniper_team", 6), raise(3),
        raise(9), raise(6),
        place("rifle_squad", 2), place("mg_nest", 5), raise(4, branch: 1),
        raise(3, branch: 0), raise(2), raise(5), raise(1, branch: 0),
        raise(6, branch: 1), raise(9, branch: 0), raise(7, branch: 1),
        place("sniper_team", 0), raise(0), place("rifle_squad", 8), raise(8),
        raise(2, branch: 1), raise(5, branch: 1), raise(0, branch: 1),
        raise(8, branch: 0),
    ]
}
