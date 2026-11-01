import SpriteKit
import SwiftUI

/// Where the map sits inside the battlefield's space, so a finger's point can
/// be turned into a tile.
struct FieldGeometry {
    /// The map's top-left corner, in the "field" coordinate space.
    var origin: CGPoint
    /// Screen points per scene point.
    var scale: CGFloat
    var cols: Int
    var rows: Int

    /// The name of the battlefield's coordinate space, shared by the map and the panel over it.
    static let space = "field"
    /// A dragged position lands on the tile just above the fingertip, so the finger doesn't hide it.
    static let lift: CGFloat = 34

    var tileSize: CGFloat { BattlefieldScene.tile * scale }
    var mapSize: CGSize { CGSize(width: CGFloat(cols) * tileSize, height: CGFloat(rows) * tileSize) }

    /// The tile a dragged position would land on with the finger at `point`, or nil off the map.
    func tile(under point: CGPoint) -> TileCoord? {
        let x = (point.x - origin.x) / tileSize
        let y = (point.y - Self.lift - origin.y) / tileSize
        guard x >= 0, y >= 0, x < CGFloat(cols), y < CGFloat(rows) else { return nil }
        return TileCoord(Int(x), Int(y))
    }

    func center(of tile: TileCoord) -> CGPoint {
        CGPoint(x: origin.x + (CGFloat(tile.col) + 0.5) * tileSize, y: origin.y + (CGFloat(tile.row) + 0.5) * tileSize)
    }
}

/// The battlefield, fitted inside whatever space it's given, with the
/// see-through panel floating over its right-hand side. Positions are dragged
/// from the panel onto any open tile. An invisible layer names each built
/// position for VoiceOver and the automatic checks (taps go straight through).
struct MapView: View {
    let session: GameSession
    var panel: FieldPanel.Mode = .phone

    var body: some View {
        GeometryReader { geometry in
            let scene = session.scene!
            let scale = min(geometry.size.width / scene.size.width, geometry.size.height / scene.size.height)
            let spare = geometry.size.width - scene.size.width * scale
            // The open Duo's half is wider than the map: the map moves over so
            // the panel can sit in the room beside it instead of on top of it.
            let left = panel == .open ? max(0, min(spare / 2, spare - FieldPanel.openWidth)) : spare / 2
            let field = FieldGeometry(
                origin: CGPoint(x: left, y: (geometry.size.height - scene.size.height * scale) / 2),
                scale: scale, cols: session.level.cols, rows: session.level.rows)
            ZStack(alignment: .topLeading) {
                SpriteView(scene: scene, preferredFramesPerSecond: 60, options: [.ignoresSiblingOrder])
                    .frame(width: field.mapSize.width, height: field.mapSize.height)
                    .offset(x: field.origin.x, y: field.origin.y)
                    .accessibilityIdentifier("battlefield")
                positionMarkers(field)
                if session.isPaused && !session.isOver {
                    pausedBanner
                        .frame(width: field.mapSize.width, height: field.mapSize.height)
                        .offset(x: field.origin.x, y: field.origin.y)
                }
                // The panel keeps to the map's own right-hand edge (on the open
                // Duo, to the half's edge, beside the map).
                FieldPanel(session: session, mode: panel, field: field)
                    .frame(width: panel == .open ? geometry.size.width : field.mapSize.width,
                           height: field.mapSize.height, alignment: .topTrailing)
                    .padding(.leading, panel == .open ? 0 : field.origin.x)
                    .padding(.top, field.origin.y)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            .coordinateSpace(.named(FieldGeometry.space))
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

    private func positionMarkers(_ field: FieldGeometry) -> some View {
        // Reading positionsVersion redraws the markers when positions change.
        let _ = session.positionsVersion
        return ForEach(session.game.positions) { position in
            Color.clear
                .frame(width: field.tileSize * 0.9, height: field.tileSize * 0.9)
                .accessibilityElement()
                .accessibilityLabel(session.catalog.position(position.type)?.name ?? "Position")
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("position-\(position.tile.col)-\(position.tile.row)")
                .position(field.center(of: position.tile))
                .allowsHitTesting(false)
        }
    }
}
