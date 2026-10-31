import Foundation

/// The shared road every zombie follows, measured along its length. Zombies
/// only store how far along they are, so hundreds move cheaply.
public struct PathTrack {
    public let points: [Vec2]
    private let cumulative: [Double]
    public let length: Double

    /// `tiles` are tile columns and rows; the road runs through tile centers.
    public init(tiles: [Vec2]) {
        points = tiles.map { Vec2($0.x + 0.5, $0.y + 0.5) }
        var sums: [Double] = [0]
        for (a, b) in zip(points, points.dropFirst()) {
            sums.append(sums[sums.count - 1] + a.distance(to: b))
        }
        cumulative = sums
        length = sums.last ?? 0
    }

    private func segment(at distance: Double) -> Int {
        var i = 0
        while i < cumulative.count - 2 && cumulative[i + 1] < distance { i += 1 }
        return i
    }

    public func point(at distance: Double) -> Vec2 {
        guard points.count > 1 else { return points.first ?? .zero }
        let d = min(max(distance, 0), length)
        let i = segment(at: d)
        let span = cumulative[i + 1] - cumulative[i]
        let t = span > 0 ? (d - cumulative[i]) / span : 0
        return points[i] + (points[i + 1] - points[i]) * t
    }

    public func direction(at distance: Double) -> Vec2 {
        guard points.count > 1 else { return Vec2(0, 1) }
        let i = segment(at: min(max(distance, 0), length))
        return (points[i + 1] - points[i]).normalized
    }

    /// Whether a tile center lies on the road.
    public func covers(col: Int, row: Int) -> Bool {
        let c = Vec2(Double(col) + 0.5, Double(row) + 0.5)
        for (a, b) in zip(points, points.dropFirst()) {
            let minX = min(a.x, b.x), maxX = max(a.x, b.x), minY = min(a.y, b.y), maxY = max(a.y, b.y)
            if c.x >= minX - 0.01 && c.x <= maxX + 0.01 && c.y >= minY - 0.01 && c.y <= maxY + 0.01 { return true }
        }
        return false
    }
}
