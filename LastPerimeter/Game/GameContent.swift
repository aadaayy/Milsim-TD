import Foundation

/// The game's data files, read once from the app bundle.
final class GameContent {
    let catalog: GameCatalog
    let levels: [LevelSpec]
    let sprites: SpriteManifest

    static let shared: GameContent = {
        do {
            return try GameContent(bundle: .main)
        } catch {
            fatalError("The game's data files couldn't be read: \(error)")
        }
    }()

    init(bundle: Bundle) throws {
        func file(_ name: String) throws -> Data {
            guard let url = bundle.url(forResource: name, withExtension: "json") else {
                throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: "\(name).json"])
            }
            return try Data(contentsOf: url)
        }
        catalog = try GameCatalog.decode(positions: file("positions"), zombies: file("zombies"))
        levels = [try LevelSpec.decode(file("level_01"))]
        sprites = try SpriteManifest.decode(file("sprites"))
    }
}
