import Foundation

/// Turns a wave's spawn groups into a timed list of zombies to release.
struct WaveSchedule {
    struct Spawn: Equatable {
        var time: Double
        var zombie: String
        var healthScale: Double = 1
        var rewardScale: Double = 1
    }

    private(set) var pending: [Spawn]
    private(set) var clock: Double = 0

    init(wave: WaveSpec) {
        var spawns: [Spawn] = []
        for group in wave.groups {
            for i in 0..<max(group.count, 0) {
                spawns.append(Spawn(time: group.delay + Double(i) * group.interval, zombie: group.zombie,
                                    healthScale: group.healthScale ?? 1, rewardScale: group.rewardScale ?? 1))
            }
        }
        // Stable order for spawns at the same moment.
        pending = spawns.enumerated().sorted { a, b in
            a.element.time == b.element.time ? a.offset < b.offset : a.element.time < b.element.time
        }.map(\.element)
    }

    var isFinished: Bool { pending.isEmpty }
    var remaining: Int { pending.count }

    /// Moves the clock on and returns the zombies due by now.
    mutating func advance(_ dt: Double) -> [Spawn] {
        clock += dt
        var due: [Spawn] = []
        while let next = pending.first, next.time <= clock {
            due.append(next)
            pending.removeFirst()
        }
        return due
    }
}

extension WaveSpec {
    /// How many of each zombie type the wave holds, in the order they first appear.
    public var counts: [(zombie: String, count: Int)] {
        var order: [String] = []
        var totals: [String: Int] = [:]
        for group in groups {
            if totals[group.zombie] == nil { order.append(group.zombie) }
            totals[group.zombie, default: 0] += group.count
        }
        return order.map { ($0, totals[$0] ?? 0) }
    }

    public var total: Int { groups.reduce(0) { $0 + $1.count } }
}
