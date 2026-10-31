import Foundation

/// Which zombie a position shoots first. The player changes it on the position's card.
public enum TargetPriority: String, CaseIterable, Codable {
    /// Furthest along the road, closest to the Command Post.
    case first
    /// Most health left.
    case strongest
    /// Nearest to the position.
    case closest

    public var label: String {
        switch self {
        case .first: return "First"
        case .strongest: return "Strongest"
        case .closest: return "Closest"
        }
    }
}

/// A crewed position on a build slot.
public struct Position: Identifiable, Equatable {
    public let id: Int
    public let slot: Int
    public let type: String
    /// 0 for level 1, 1 for level 2.
    public var level: Int
    public let center: Vec2
    public var cooldown: Double = 0
    /// Where the weapon points, on the map.
    public var aim: Vec2 = Vec2(0, -1)
    public var targetID: Int?
    public var priority: TargetPriority = .first
    public var kills = 0
    /// Supply spent on it so far, for the refund when it's sold.
    public var spent: Int
}

enum Targeting {
    /// The zombie this position should shoot, or nil when none is in range.
    static func pick(for position: Position, range: Double, zombies: [Zombie], track: PathTrack) -> Zombie? {
        var best: Zombie?
        var bestScore = -Double.infinity
        for zombie in zombies where zombie.health > 0 {
            let gap = track.position(of: zombie).distance(to: position.center)
            guard gap <= range else { continue }
            let score: Double
            switch position.priority {
            case .first: score = zombie.distance
            case .strongest: score = zombie.health * 1000 + zombie.distance
            case .closest: score = -gap
            }
            if score > bestScore {
                bestScore = score
                best = zombie
            }
        }
        return best
    }
}
