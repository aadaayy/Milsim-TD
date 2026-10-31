import Foundation

/// Plays a level by a fixed build order, taking each step as soon as supply
/// allows. The automatic checks use it to play all the rounds for real, and
/// the screenshot setups use it to reach a late round with a true defense.
public struct AutoPlayer {
    public enum Step: Equatable {
        case build(String, slot: Int, priority: TargetPriority = .first)
        /// `branch` picks 3A (0) or 3B (1) when the upgrade is to level 3.
        case upgrade(slot: Int, branch: Int = 0)
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
            case .build(let type, let slot, let priority):
                guard !game.build(type, onSlot: slot).isEmpty, let p = game.position(onSlot: slot) else { return }
                game.setPriority(priority, for: p.id)
            case .upgrade(let slot, let branch):
                guard let p = game.position(onSlot: slot), !game.upgrade(p.id, branch: branch).isEmpty else { return }
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

    /// A strong defense for the first map: rifles and a machine gun early,
    /// snipers for the armor, then every position to level 3. The sniper on
    /// pad 3 aims at the strongest zombie, so it works on the bosses.
    public static let firstMap: [Step] = [
        .build("rifle_squad", slot: 1), .build("rifle_squad", slot: 7), .build("mg_nest", slot: 4),
        .upgrade(slot: 1), .build("sniper_team", slot: 3, priority: .strongest), .upgrade(slot: 4),
        .upgrade(slot: 7), .build("mg_nest", slot: 9), .build("sniper_team", slot: 6), .upgrade(slot: 3),
        .upgrade(slot: 9), .upgrade(slot: 6),
        .build("rifle_squad", slot: 2), .build("mg_nest", slot: 5), .upgrade(slot: 4, branch: 1),
        .upgrade(slot: 3, branch: 0), .upgrade(slot: 2), .upgrade(slot: 5), .upgrade(slot: 1, branch: 0),
        .upgrade(slot: 6, branch: 1), .upgrade(slot: 9, branch: 0), .upgrade(slot: 7, branch: 1),
        .build("sniper_team", slot: 0), .upgrade(slot: 0), .build("rifle_squad", slot: 8), .upgrade(slot: 8),
        .upgrade(slot: 2, branch: 1), .upgrade(slot: 5, branch: 1), .upgrade(slot: 0, branch: 1),
        .upgrade(slot: 8, branch: 0),
    ]
}
