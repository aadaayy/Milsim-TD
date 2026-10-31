import Foundation
import Observation
import UIKit

/// What the player has picked on the map.
enum Selection: Equatable {
    case none
    /// An empty build slot, by index: the build menu shows.
    case slot(Int)
    /// A built position, by id: its card shows.
    case position(Int)
}

/// One level being played, shared by the battlefield scene and the screens
/// around it. The scene moves the game on; the screens read the numbers here,
/// which only change when the game's do (so SwiftUI isn't redrawn every frame).
@MainActor
@Observable
final class GameSession {
    let content: GameContent
    let levelIndex: Int
    let game: GameState
    @ObservationIgnored private(set) var scene: BattlefieldScene!

    // Copies of the game's numbers for the screens.
    private(set) var supply = 0
    private(set) var commandPostHealth = 0
    private(set) var wavesStarted = 0
    private(set) var phase: GamePhase = .build
    private(set) var kills = 0
    /// Seconds left in the break between waves, rounded up.
    private(set) var breakSeconds = 0
    /// Bumped whenever positions change, so cards redraw.
    private(set) var positionsVersion = 0

    /// The scene draws the ring or highlight for this each frame.
    var selection: Selection = .none
    /// 1, 2 or 3 times normal speed.
    var speed = 1
    var isPaused = false

    init(content: GameContent = .shared, levelIndex: Int = 0) {
        self.content = content
        self.levelIndex = levelIndex
        game = GameState(level: content.levels[levelIndex], catalog: content.catalog)
        scene = BattlefieldScene(session: self)
        refresh()
    }

    var level: LevelSpec { game.level }
    var catalog: GameCatalog { game.catalog }

    var isOver: Bool {
        switch phase {
        case .won, .lost: return true
        default: return false
        }
    }

    /// Game seconds per real second, 0 while paused or over.
    var timeScale: Double { isPaused || game.isOver ? 0 : Double(speed) }

    /// Copies the game's numbers, setting only the ones that changed.
    func refresh() {
        if supply != game.supply { supply = game.supply }
        if commandPostHealth != game.commandPostHealth { commandPostHealth = game.commandPostHealth }
        if wavesStarted != game.wavesStarted { wavesStarted = game.wavesStarted }
        if kills != game.kills { kills = game.kills }
        var newPhase = game.phase
        var seconds = 0
        if case .pause(let remaining) = game.phase {
            seconds = Int(remaining.rounded(.up))
            newPhase = .pause(remaining: 0)  // the countdown is in breakSeconds
        }
        if phase != newPhase { phase = newPhase }
        if breakSeconds != seconds { breakSeconds = seconds }
        if case .position(let id) = selection, game.position(id: id) == nil { selection = .none }
    }

    // MARK: Player actions

    func build(_ type: String) {
        guard case .slot(let slot) = selection else { return }
        let events = game.build(type, onSlot: slot)
        guard case .built(let id)? = events.first else { return }
        Haptics.tap()
        positionsVersion += 1
        refresh()
        scene.positionsChanged()
        selection = .position(id)
    }

    func upgrade(_ id: Int) {
        guard !game.upgrade(id).isEmpty else { return }
        Haptics.tap()
        positionsVersion += 1
        refresh()
        scene.positionsChanged()
    }

    func sell(_ id: Int) {
        guard !game.sell(id).isEmpty else { return }
        Haptics.tap()
        selection = .none
        positionsVersion += 1
        refresh()
        scene.positionsChanged()
    }

    func setPriority(_ priority: TargetPriority, for id: Int) {
        game.setPriority(priority, for: id)
        positionsVersion += 1
    }

    func startNextWave() {
        guard !game.startNextWave().isEmpty else { return }
        isPaused = false
        refresh()
    }

    func togglePause() { isPaused.toggle() }

    func cycleSpeed() { speed = speed >= 3 ? 1 : speed + 1 }

    /// Called by the scene with everything that happened this frame.
    func handle(_ events: [GameEvent]) {
        for event in events {
            switch event {
            case .breached: Haptics.thud()
            case .won: Haptics.success()
            case .lost: Haptics.failure()
            default: break
            }
        }
        refresh()
    }

    // MARK: Screenshot setups

    /// Applies the automatic checks' launch arguments: "-demo" builds a defense,
    /// "-startWave N" sends wave N, "-selectSlot N" and "-selectPosition N" pick
    /// on the map, "-speed N" and "-endScreen win|lose" jump ahead.
    func applyLaunchArguments(_ arguments: [String]) {
        func value(_ flag: String) -> String? {
            guard let i = arguments.firstIndex(of: flag), i + 1 < arguments.count else { return nil }
            return arguments[i + 1]
        }
        if arguments.contains("-demo") {
            game.grantSupply(600)
            for (type, slot) in [("rifle_squad", 3), ("rifle_squad", 4), ("mg_nest", 1), ("sniper_team", 7), ("mg_nest", 5)] {
                game.build(type, onSlot: slot)
            }
            if let p = game.position(onSlot: 3) { game.upgrade(p.id) }
            if let p = game.position(onSlot: 1) { game.upgrade(p.id) }
            game.grantSupply(-(game.supply - 145))
            positionsVersion += 1
            scene.positionsChanged()
        }
        if let wave = value("-startWave").flatMap(Int.init), wave > 0 {
            game.skipWaves(wave - 1)
            game.startNextWave()
            // Let the wave walk in a little way so the screenshot has a crowd.
            scene.fastForward(seconds: Double(value("-warmup").flatMap(Double.init) ?? 20))
        }
        if let slot = value("-selectSlot").flatMap(Int.init) { selection = .slot(slot) }
        if let slot = value("-selectPosition").flatMap(Int.init), let p = game.position(onSlot: slot) {
            selection = .position(p.id)
        }
        if let speed = value("-speed").flatMap(Int.init) { self.speed = min(max(speed, 1), 3) }
        if let end = value("-endScreen") {
            game.forceEnd(won: end == "win")
        }
        refresh()
    }
}

/// Short taps of feedback, so hits and builds can be felt.
enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func thud() { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func failure() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}
