import Foundation

/// A point or direction on the map, in tiles. x grows to the right and y grows
/// down the screen (row 0 is the top row), the same way the level files count.
public struct Vec2: Codable, Equatable {
    public var x: Double
    public var y: Double

    public init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }

    public static let zero = Vec2(0, 0)

    public var length: Double { (x * x + y * y).squareRoot() }

    public var normalized: Vec2 {
        let l = length
        return l > 0 ? Vec2(x / l, y / l) : Vec2(0, -1)
    }

    /// The direction as a perpendicular, turned a quarter to the right.
    public var perpendicular: Vec2 { Vec2(-y, x) }

    public func distance(to other: Vec2) -> Double { (other - self).length }

    public static func + (a: Vec2, b: Vec2) -> Vec2 { Vec2(a.x + b.x, a.y + b.y) }
    public static func - (a: Vec2, b: Vec2) -> Vec2 { Vec2(a.x - b.x, a.y - b.y) }
    public static func * (a: Vec2, s: Double) -> Vec2 { Vec2(a.x * s, a.y * s) }

    // Level files write points as [x, y].
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        x = try container.decode(Double.self)
        y = try container.decode(Double.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(x)
        try container.encode(y)
    }
}

/// Eight compass facings, named the way the sprite sheets name them
/// ("n" is up the screen).
public enum Facing: String, CaseIterable, Codable {
    case n, ne, e, se, s, sw, w, nw

    /// The nearest of the eight facings to a direction on the map (y down).
    public init(direction: Vec2) {
        // Angle clockwise from up the screen.
        var angle = atan2(direction.x, -direction.y) * 180 / .pi
        if angle < 0 { angle += 360 }
        let index = Int((angle + 22.5) / 45) % 8
        self = Facing.allCases[index]
    }

    /// The nearest of n, e, s and w (some animations only have those four).
    public init(fourWay direction: Vec2) {
        if abs(direction.x) > abs(direction.y) {
            self = direction.x > 0 ? .e : .w
        } else {
            self = direction.y > 0 ? .s : .n
        }
    }
}

/// A small repeatable random number generator, so a level plays out the same
/// way every time the same choices are made (and tests are stable).
public struct SeededRandom {
    private var state: UInt64

    public init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }

    /// A number from 0 up to (not including) 1.
    public mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(1 << 53)
    }

    public mutating func next(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + next() * (range.upperBound - range.lowerBound)
    }
}
