import Foundation

/// sprites.json, written by Tools/make_sprites.py: each sprite's real size in
/// meters and which frames and facings it has. Image names in the asset catalog
/// are "<atlas>_<facing>_<frame>" for positions and structures,
/// "<atlas>_<anim>_<frame>_<facing>" for zombies and "<effect>_<frame>" for effects.
struct SpriteManifest: Decodable {
    var positions: [String: TurretSprite]
    var zombies: [String: ZombieSprite]
    var structures: [String: TurretSprite]
    var effects: [String: EffectSprite]

    /// A base image with a turning top layer drawn over it (crew and weapon).
    struct TurretSprite: Decodable {
        var atlas: String
        var label: String
        var frames: [String]
        var dirs: [String]
        var baseM: [Double]
        var cellM: [Double]
        /// Where the turret sits on the base, in meters; +y is up the screen.
        var offsetM: [Double]
    }

    struct ZombieSprite: Decodable {
        var atlas: String
        var label: String
        var cellM: [Double]
        var anims: [String: Anim]

        struct Anim: Decodable {
            var frames: Int
            var fps: Double
            var dirs: [String]
        }
    }

    struct EffectSprite: Decodable {
        var frames: Int
        var fps: Double
        var loop: Bool
        var cellM: [Double]
    }

    static func decode(_ data: Data) throws -> SpriteManifest {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(SpriteManifest.self, from: data)
    }
}
