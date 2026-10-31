import Foundation

/// Something that happened during a tick, for the screen to draw or play.
public enum GameEvent: Equatable {
    case shot(position: Int, zombie: Int, from: Vec2, to: Vec2)
    case killed(zombie: Int, type: String, at: Vec2, heading: Vec2)
    case breached(zombie: Int)
    case waveStarted(number: Int)
    case waveCleared(number: Int, bonus: Int)
    case won(stars: Int)
    case lost
    case built(position: Int)
    case upgraded(position: Int)
    case sold(position: Int, refund: Int)
}

public enum GamePhase: Equatable {
    /// Before the first wave: the game waits while the player builds.
    case build
    case wave
    /// Between waves; the next one starts by itself when the countdown ends.
    case pause(remaining: Double)
    case won(stars: Int)
    case lost
}

/// One level being played. Plain Swift with no drawing, so the rules can be
/// tested anywhere; the SpriteKit scene draws whatever this holds.
public final class GameState {
    public let level: LevelSpec
    public let catalog: GameCatalog
    public let track: PathTrack
    public let slots: [Vec2]

    public private(set) var phase: GamePhase = .build
    public private(set) var supply: Int
    public private(set) var commandPostHealth: Int
    /// Waves started so far (the wave on now is number `wavesStarted`).
    public private(set) var wavesStarted = 0
    public private(set) var zombies: [Zombie] = []
    public private(set) var positions: [Position] = []
    public private(set) var kills = 0
    /// Total time the level has run, in game seconds.
    public private(set) var time: Double = 0

    private var schedule: WaveSchedule?
    private var nextID = 1
    private var random: SeededRandom

    /// Share of what a position cost that comes back when it's sold.
    public static let refundShare = 0.7

    public init(level: LevelSpec, catalog: GameCatalog, seed: UInt64 = 1) {
        self.level = level
        self.catalog = catalog
        track = PathTrack(tiles: level.path)
        slots = level.slots
        supply = level.startSupply
        commandPostHealth = level.commandPostHealth
        random = SeededRandom(seed: seed)
    }

    public var waveCount: Int { level.waves.count }
    public var isOver: Bool {
        switch phase {
        case .won, .lost: return true
        default: return false
        }
    }

    /// The wave that comes next, if any.
    public var nextWave: WaveSpec? { wavesStarted < level.waves.count ? level.waves[wavesStarted] : nil }

    /// Zombies still to come in the wave on now.
    public var zombiesLeftToSpawn: Int { schedule?.remaining ?? 0 }

    // MARK: Building

    public func position(onSlot slot: Int) -> Position? { positions.first { $0.slot == slot } }
    public func position(id: Int) -> Position? { positions.first { $0.id == id } }

    public func levelSpec(of position: Position) -> PositionLevel? {
        catalog.position(position.type)?.levels[safe: position.level]
    }

    public func nextLevelSpec(of position: Position) -> PositionLevel? {
        catalog.position(position.type)?.levels[safe: position.level + 1]
    }

    public func canBuild(_ type: String, onSlot slot: Int) -> Bool {
        guard !isOver, slots.indices.contains(slot), position(onSlot: slot) == nil,
              let cost = catalog.position(type)?.levels.first?.cost else { return false }
        return supply >= cost
    }

    @discardableResult
    public func build(_ type: String, onSlot slot: Int) -> [GameEvent] {
        guard canBuild(type, onSlot: slot), let cost = catalog.position(type)?.levels.first?.cost else { return [] }
        supply -= cost
        let position = Position(id: takeID(), slot: slot, type: type, level: 0, center: slots[slot], spent: cost)
        positions.append(position)
        return [.built(position: position.id)]
    }

    public func canUpgrade(_ id: Int) -> Bool {
        guard !isOver, let p = position(id: id), let next = nextLevelSpec(of: p) else { return false }
        return supply >= next.cost
    }

    @discardableResult
    public func upgrade(_ id: Int) -> [GameEvent] {
        guard canUpgrade(id), let index = positions.firstIndex(where: { $0.id == id }),
              let next = nextLevelSpec(of: positions[index]) else { return [] }
        supply -= next.cost
        positions[index].level += 1
        positions[index].spent += next.cost
        return [.upgraded(position: id)]
    }

    public func refund(for id: Int) -> Int {
        guard let p = position(id: id) else { return 0 }
        return Int((Double(p.spent) * Self.refundShare).rounded(.down))
    }

    @discardableResult
    public func sell(_ id: Int) -> [GameEvent] {
        guard !isOver, let index = positions.firstIndex(where: { $0.id == id }) else { return [] }
        let refund = self.refund(for: id)
        supply += refund
        positions.remove(at: index)
        return [.sold(position: id, refund: refund)]
    }

    public func setPriority(_ priority: TargetPriority, for id: Int) {
        guard let index = positions.firstIndex(where: { $0.id == id }) else { return }
        positions[index].priority = priority
        positions[index].targetID = nil
    }

    // MARK: Waves

    /// Whether the player can send the next wave now (to start the level, or to cut a break short).
    public var canStartNextWave: Bool {
        guard nextWave != nil else { return false }
        switch phase {
        case .build, .pause: return true
        default: return false
        }
    }

    @discardableResult
    public func startNextWave() -> [GameEvent] {
        guard canStartNextWave, let wave = nextWave else { return [] }
        schedule = WaveSchedule(wave: wave)
        wavesStarted += 1
        phase = .wave
        return [.waveStarted(number: wavesStarted)]
    }

    // MARK: Time

    /// Moves the game on by `dt` seconds of game time. Call with small steps (a 60th of a second).
    public func tick(_ dt: Double) -> [GameEvent] {
        var events: [GameEvent] = []
        switch phase {
        case .won, .lost, .build:
            return events
        case .pause(let remaining):
            time += dt
            moveZombies(dt, events: &events)
            fire(dt, events: &events)
            let left = remaining - dt
            if left <= 0 {
                phase = .pause(remaining: 0)
                events += startNextWave()
            } else {
                phase = .pause(remaining: left)
            }
            return events
        case .wave:
            time += dt
        }

        if var current = schedule {
            for type in current.advance(dt) { spawn(type) }
            schedule = current
        }
        moveZombies(dt, events: &events)
        if case .lost = phase { return events }
        fire(dt, events: &events)

        if schedule?.isFinished == true && zombies.isEmpty {
            schedule = nil
            let bonus = level.waves[wavesStarted - 1].bonus
            supply += bonus
            events.append(.waveCleared(number: wavesStarted, bonus: bonus))
            if wavesStarted >= level.waves.count {
                let stars = starsEarned
                phase = .won(stars: stars)
                events.append(.won(stars: stars))
            } else {
                phase = .pause(remaining: level.breakSeconds)
            }
        }
        return events
    }

    /// Stars for a win: one for winning, one for keeping the Command Post at three
    /// quarters health or better, one for the bonus objective (no damage at all).
    public var starsEarned: Int {
        var stars = 1
        if Double(commandPostHealth) >= Double(level.commandPostHealth) * 0.75 { stars += 1 }
        if commandPostHealth == level.commandPostHealth { stars += 1 }
        return stars
    }

    private func spawn(_ type: String) {
        guard let spec = catalog.zombie(type) else { return }
        let zombie = Zombie(id: takeID(), type: type, health: spec.health, maxHealth: spec.health,
                            distance: 0, speed: spec.speed * random.next(in: 0.92...1.08),
                            lane: random.next(in: -0.22...0.22))
        zombies.append(zombie)
    }

    private func moveZombies(_ dt: Double, events: inout [GameEvent]) {
        var breached: [Int] = []
        for i in zombies.indices {
            zombies[i].distance += zombies[i].currentSpeed * dt
            if zombies[i].slowTime > 0 { zombies[i].slowTime -= dt }
            if zombies[i].distance >= track.length { breached.append(i) }
        }
        for i in breached.reversed() {
            let zombie = zombies.remove(at: i)
            commandPostHealth = max(0, commandPostHealth - (catalog.zombie(zombie.type)?.breachDamage ?? 1))
            events.append(.breached(zombie: zombie.id))
        }
        if commandPostHealth <= 0, phase != .lost {
            phase = .lost
            schedule = nil
            events.append(.lost)
        }
    }

    private func fire(_ dt: Double, events: inout [GameEvent]) {
        for p in positions.indices {
            positions[p].cooldown -= dt
            guard let spec = levelSpec(of: positions[p]) else { continue }
            guard let target = Targeting.pick(for: positions[p], range: spec.range, zombies: zombies, track: track) else {
                positions[p].targetID = nil
                continue
            }
            let at = track.position(of: target)
            positions[p].targetID = target.id
            positions[p].aim = (at - positions[p].center).normalized
            guard positions[p].cooldown <= 0 else { continue }
            positions[p].cooldown = spec.fireInterval
            events.append(.shot(position: positions[p].id, zombie: target.id, from: positions[p].center, to: at))
            guard let z = zombies.firstIndex(where: { $0.id == target.id }) else { continue }
            zombies[z].health -= spec.damage
            if let factor = spec.slowFactor, let seconds = spec.slowSeconds {
                zombies[z].slowFactor = factor
                zombies[z].slowTime = seconds
            }
            if zombies[z].health <= 0 {
                let dead = zombies.remove(at: z)
                positions[p].kills += 1
                kills += 1
                supply += catalog.zombie(dead.type)?.reward ?? 0
                events.append(.killed(zombie: dead.id, type: dead.type, at: at, heading: track.direction(at: dead.distance)))
            }
        }
    }

    // MARK: Screenshot setups
    // The automatic checks use these to reach a busy moment of the level quickly.

    public func grantSupply(_ amount: Int) {
        supply += amount
    }

    /// Treats the first `count` waves as already played, so the next one sent is wave `count + 1`.
    public func skipWaves(_ count: Int) {
        guard case .build = phase else { return }
        wavesStarted = max(0, min(count, level.waves.count - 1))
    }

    public func forceEnd(won: Bool) {
        schedule = nil
        phase = won ? .won(stars: starsEarned) : .lost
    }

    private func takeID() -> Int {
        defer { nextID += 1 }
        return nextID
    }
}

extension Array {
    public subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
