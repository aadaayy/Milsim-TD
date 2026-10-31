import SpriteKit
import SwiftUI

/// The battlefield, fitted inside whatever space it's given. On top sits an
/// invisible layer that names each build pad and position for VoiceOver and
/// for the automatic checks (taps go straight through to the map).
struct MapView: View {
    let session: GameSession

    var body: some View {
        GeometryReader { geometry in
            let scene = session.scene!
            let scale = min(geometry.size.width / scene.size.width, geometry.size.height / scene.size.height)
            let origin = CGPoint(x: (geometry.size.width - scene.size.width * scale) / 2,
                                 y: (geometry.size.height - scene.size.height * scale) / 2)
            ZStack(alignment: .topLeading) {
                SpriteView(scene: scene, preferredFramesPerSecond: 60, options: [.ignoresSiblingOrder])
                    .frame(width: scene.size.width * scale, height: scene.size.height * scale)
                    .offset(x: origin.x, y: origin.y)
                    .accessibilityIdentifier("battlefield")
                slotMarkers(scale: scale, origin: origin)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
        }
        .background(Theme.mapSurround)
    }

    private func slotMarkers(scale: CGFloat, origin: CGPoint) -> some View {
        // Reading positionsVersion redraws the markers when positions change.
        let _ = session.positionsVersion
        let tile = BattlefieldScene.tile * scale
        return ForEach(Array(session.game.slots.enumerated()), id: \.offset) { index, slot in
            let built = session.game.position(onSlot: index)
            Color.clear
                .frame(width: tile * 0.9, height: tile * 0.9)
                .contentShape(Rectangle())
                .accessibilityElement()
                .accessibilityLabel(built.map { session.catalog.position($0.type)?.name ?? "Position" } ?? "Build pad \(index + 1)")
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier(built == nil ? "slot-\(index)" : "position-\(index)")
                .position(x: origin.x + CGFloat(slot.x) * tile, y: origin.y + CGFloat(slot.y) * tile)
                .allowsHitTesting(false)
        }
    }
}
