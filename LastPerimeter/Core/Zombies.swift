import Foundation

/// One zombie on the road.
public struct Zombie: Identifiable, Equatable {
    public let id: Int
    public let type: String
    public var health: Double
    public let maxHealth: Double
    /// How far along the road, in tiles.
    public var distance: Double
    /// Tiles per second before slowing.
    public let speed: Double
    /// Sideways offset from the middle of the road, so a crowd doesn't walk in single file.
    public let lane: Double
    /// While above zero, speed is multiplied by `slowFactor`.
    public var slowTime: Double = 0
    public var slowFactor: Double = 1

    public var currentSpeed: Double { slowTime > 0 ? speed * slowFactor : speed }
}

extension PathTrack {
    /// Where a zombie stands on the map, lane offset included.
    public func position(of zombie: Zombie) -> Vec2 {
        point(at: zombie.distance) + direction(at: zombie.distance).perpendicular * zombie.lane
    }
}
