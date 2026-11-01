import Foundation
import Observation
import UIKit

/// What the player has picked on the map.
enum Selection: Equatable {
    case none
    /// An empty tile of open ground: the build menu for it shows.
    case tile(TileCoord)
    /// A built position, by id: its card shows.
    case position(Int)
}

/// A position being dragged onto the map: which kind, the tile it would go
/// on (nil while the finger is off the map) and whether it can go there.
struct Placement: Equatable {
    var type: String
    var tile: TileCoord?
    var valid: Bool
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
    /// While a position is dragged from the panel, the scene shows where it would land.
    var placement: Placement?
    /// The see-through panel over the map, folded away to show the whole map.
    var panelCollapsed = false
    /// 1, 2 or 3 times normal speed.
    var speed = 1
    var isPaused = false
    /// While a screenshot setup plays ahead, the scene doesn't move the game itself.
    private var isSettingUp = false

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
    var timeScale: Double { isPaused || isSettingUp || game.isOver ? 0 : Double(speed) }

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

    /// Builds on the tile picked on the map.
    func build(_ type: String) {
        guard case .tile(let tile) = selection else { return }
        build(type, at: tile)
    }

    @discardableResult
    func build(_ type: String, at tile: TileCoord) -> Bool {
        let events = game.build(type, at: tile)
        guard case .built(let id)? = events.first else { return false }
        Haptics.tap()
        positionsVersion += 1
        refresh()
        scene.positionsChanged()
        selection = .position(id)
        return true
    }

    // MARK: Drag and drop

    /// The finger, dragging a position, is over `tile` (nil when off the map).
    func drag(_ type: String, over tile: TileCoord?) {
        let valid = tile.map { game.canBuild(type, at: $0) } ?? false
        let next = Placement(type: type, tile: tile, valid: valid)
        guard next != placement else { return }
        if next.tile != nil && next.tile != placement?.tile { Haptics.tick() }
        if selection != .none { selection = .none }
        placement = next
    }

    /// The finger let go: build there if it can go there.
    func drop(_ type: String, on tile: TileCoord?) {
        placement = nil
        guard let tile, build(type, at: tile) else {
            if tile != nil { Haptics.failure() }
            return
        }
    }

    /// `branch` picks 3A (0) or 3B (1) when the upgrade is to level 3.
    func upgrade(_ id: Int, branch: Int = 0) {
        guard !game.upgrade(id, branch: branch).isEmpty else { return }
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
    /// "-startWave N" sends round N, "-playTo N" plays the strong build order for
    /// real until round N starts, "-selectTile C,R" and "-selectPosition C,R" pick
    /// on the map, "-dragPreview TYPE C,R" freezes a drag over a tile, "-speed N",
    /// "-paused" and "-endScreen win|lose" jump ahead.
    /// The long setups play the level ahead in short bursts, so the app stays
    /// responsive (and the automatic checks can see it launch) while they run.
    func applyLaunchArguments(_ arguments: [String]) async {
        func value(_ flag: String) -> String? {
            guard let i = arguments.firstIndex(of: flag), i + 1 < arguments.count else { return nil }
            return arguments[i + 1]
        }
        if arguments.contains("-demo") {
            game.grantSupply(600)
            let spots = AutoPlayer.firstMapSpots
            for (type, spot) in [("rifle_squad", 3), ("rifle_squad", 4), ("mg_nest", 1), ("sniper_team", 7), ("mg_nest", 5)] {
                game.build(type, at: spots[spot])
            }
            if let p = game.position(at: spots[3]) { game.upgrade(p.id) }
            if let p = game.position(at: spots[1]) { game.upgrade(p.id) }
            game.grantSupply(-(game.supply - 245))
            positionsVersion += 1
            scene.positionsChanged()
        }
        if let wave = value("-startWave").flatMap(Int.init), wave > 0 {
            game.skipWaves(wave - 1)
            game.startNextWave()
            // Let the wave walk in a little way so the screenshot has a crowd.
            scene.fastForward(seconds: Double(value("-warmup").flatMap(Double.init) ?? 20))
        }
        if let round = value("-playTo").flatMap(Int.init), round > 0 {
            var player = AutoPlayer(steps: AutoPlayer.firstMap)
            await playAhead(&player) { $0.wavesStarted >= round }
            scene.fastForward(seconds: Double(value("-warmup").flatMap(Double.init) ?? 15))
            positionsVersion += 1
            scene.positionsChanged()
        }
        if let tile = value("-selectTile").flatMap(TileCoord.init) { selection = .tile(tile) }
        if let tile = value("-selectPosition").flatMap(TileCoord.init), let p = game.position(at: tile) {
            selection = .position(p.id)
        }
        if let type = value("-dragPreview"), let i = arguments.firstIndex(of: "-dragPreview"),
           let tile = arguments[safe: i + 2].flatMap(TileCoord.init) {
            drag(type, over: tile)
        }
        if let speed = value("-speed").flatMap(Int.init) { self.speed = min(max(speed, 1), 3) }
        if arguments.contains("-paused") { isPaused = true }
        if let end = value("-endScreen") {
            // Play all the rounds out for real (no drawing) with the strong build
            // order, so the end screen's numbers are true; force the asked-for
            // ending only if it differs.
            var player = AutoPlayer(steps: AutoPlayer.firstMap)
            await playAhead(&player) { _ in false }
            positionsVersion += 1
            scene.positionsChanged()
            let won: Bool = { if case .won = game.phase { return true }; return false }()
            if !game.isOver || won != (end == "win") { game.forceEnd(won: end == "win") }
        }
        refresh()
    }

    /// Plays the strong build order until `stop` says so or the level ends.
    private func playAhead(_ player: inout AutoPlayer, until stop: (GameState) -> Bool) async {
        isSettingUp = true
        defer { isSettingUp = false }
        while !game.isOver && !stop(game) {
            player.play(game, maxSeconds: 15, stop: stop)
            refresh()
            try? await Task.sleep(nanoseconds: 2_000_000)
        }
    }
}

/// Short taps of feedback, so hits and builds can be felt.
enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    /// A light click as a dragged position moves onto the next tile.
    static func tick() { UISelectionFeedbackGenerator().selectionChanged() }
    static func thud() { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func failure() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}
