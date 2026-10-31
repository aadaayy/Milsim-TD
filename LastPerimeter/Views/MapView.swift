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
            .overlay {
                if session.isPaused && !session.isOver { pausedBanner }
            }
        }
        .background(Theme.mapSurround)
    }

    /// Shown over the map while the game is paused, so it can't be missed.
    /// Building and upgrading still work while paused.
    private var pausedBanner: some View {
        VStack(spacing: 4) {
            Image(systemName: "pause.fill").font(.system(size: 22, weight: .bold))
            Text("PAUSED").font(.stencil(20)).tracking(2)
            Text("Tap play to carry on").font(.system(size: 12))
        }
        .foregroundStyle(Theme.text)
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(Color.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("paused-banner")
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
