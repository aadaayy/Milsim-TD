import SpriteKit
import SwiftUI

/// Where the map sits inside the battlefield's space, so a finger's point can
/// be turned into a tile.
struct FieldGeometry: Equatable {
    /// The map's top-left corner, in the coordinate space a drag reports in.
    var origin: CGPoint
    /// Screen points per scene point.
    var scale: CGFloat
    /// The map's own columns and rows (9 by 15 for the first map).
    var cols: Int
    var rows: Int
    /// Drawn turned a quarter to the left: the map's top on the left, its
    /// left-hand edge along the bottom.
    var sideways = false

    /// The name of the battlefield's coordinate space, shared by the map and the panel over it.
    static let space = "field"
    /// A dragged position lands on the tile just above the fingertip, so the finger doesn't hide it.
    static let lift: CGFloat = 34

    var tileSize: CGFloat { BattlefieldScene.tile * scale }
    /// Tiles across and down the screen.
    var screenCols: Int { sideways ? rows : cols }
    var screenRows: Int { sideways ? cols : rows }
    var mapSize: CGSize { CGSize(width: CGFloat(screenCols) * tileSize, height: CGFloat(screenRows) * tileSize) }

    /// The tile a dragged position would land on with the finger at `point`, or nil off the map.
    func tile(under point: CGPoint) -> TileCoord? {
        let x = (point.x - origin.x) / tileSize
        let y = (point.y - Self.lift - origin.y) / tileSize
        guard x >= 0, y >= 0, x < CGFloat(screenCols), y < CGFloat(screenRows) else { return nil }
        // Sideways, a screen column is a map row and a screen row counts the map's columns from the right.
        return sideways ? TileCoord(cols - 1 - Int(y), Int(x)) : TileCoord(Int(x), Int(y))
    }

    func center(of tile: TileCoord) -> CGPoint {
        let (x, y) = sideways ? (CGFloat(tile.row), CGFloat(cols - 1 - tile.col)) : (CGFloat(tile.col), CGFloat(tile.row))
        return CGPoint(x: origin.x + (x + 0.5) * tileSize, y: origin.y + (y + 0.5) * tileSize)
    }

    /// The same map seen from another coordinate space, whose origin is `offset` away.
    func shifted(by offset: CGPoint) -> FieldGeometry {
        var moved = self
        moved.origin = CGPoint(x: origin.x + offset.x, y: origin.y + offset.y)
        return moved
    }
}

/// The open Duo's map, as the slim rail beside it sees it, so positions can be
/// dragged from the rail onto it.
struct RailFieldKey: PreferenceKey {
    static let defaultValue: FieldGeometry? = nil
    static func reduce(value: inout FieldGeometry?, nextValue: () -> FieldGeometry?) {
        value = nextValue() ?? value
    }
}

/// The battlefield, filling all the space it's given edge to edge. The map
/// itself is fitted inside that space less `insets` (where the strips and
/// bars float over it), and past its edges the scene draws more open country,
/// so there are no empty bars. The panel floats over the map's right-hand
/// side, or sits in the room beside it when there is some. Positions are
/// dragged from the panel onto any open tile. An invisible layer names the
/// map and each built position for VoiceOver and the automatic checks (taps
/// go straight through).
struct MapView: View {
    let session: GameSession
    var panel: FieldPanel.Mode = .phone
    /// Drawn turned a quarter to the left, to fill a wide screen.
    var sideways = false
    /// Room kept clear around the map for the strips and bars over it.
    var insets = EdgeInsets()

    /// Where the scene sits: its size in scene points, where the map goes in
    /// it, and which way the map is drawn.
    private struct SceneLayout: Equatable {
        var viewport: CGSize
        var mapOffset: CGPoint
        var sideways: Bool
    }

    /// Room the panel takes at the right-hand edge, margins included, so the
    /// map can move over and leave it free when the screen has room to spare.
    private var panelRoom: CGFloat {
        switch panel {
        case .phone: return FieldPanel.phoneWidth + 12
        case .folded: return FieldPanel.foldedWidth + 12
        case .open: return FieldPanel.openWidth
        case .cards: return 0
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let full = BattlefieldScene.size(cols: session.level.cols, rows: session.level.rows, sideways: sideways)
            let playWidth = max(1, geometry.size.width - insets.leading - insets.trailing)
            let playHeight = max(1, geometry.size.height - insets.top - insets.bottom)
            let scale = min(playWidth / full.width, playHeight / full.height)
            let spare = playWidth - full.width * scale
            let left = panel == .cards ? spare / 2 : max(0, min(spare / 2, spare - panelRoom))
            let field = FieldGeometry(
                origin: CGPoint(x: insets.leading + left, y: insets.top + (playHeight - full.height * scale) / 2),
                scale: scale, cols: session.level.cols, rows: session.level.rows, sideways: sideways)
            let viewport = CGSize(width: geometry.size.width / scale, height: geometry.size.height / scale)
            let layout = SceneLayout(
                viewport: viewport,
                mapOffset: CGPoint(x: field.origin.x / scale, y: viewport.height - field.origin.y / scale - full.height),
                sideways: sideways)
            let wide = geometry.frame(in: .named(WideGameLayout.space)).origin
            // The panel reaches the play area's right-hand edge (just the map's, when it only shows cards).
            let panelRight = panel == .cards ? field.origin.x + field.mapSize.width : insets.leading + playWidth
            ZStack(alignment: .topLeading) {
                SpriteView(scene: session.scene, isPaused: session.isSettingUp, preferredFramesPerSecond: 60, options: [.ignoresSiblingOrder])
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .accessibilityHidden(true)
                Color.clear
                    .frame(width: field.mapSize.width, height: field.mapSize.height)
                    .accessibilityElement()
                    .accessibilityLabel("Battlefield")
                    .accessibilityIdentifier("battlefield")
                    .position(x: field.origin.x + field.mapSize.width / 2, y: field.origin.y + field.mapSize.height / 2)
                    .allowsHitTesting(false)
                positionMarkers(field)
                if session.isPaused && !session.isOver {
                    pausedBanner
                        .frame(width: field.mapSize.width, height: field.mapSize.height)
                        .position(x: field.origin.x + field.mapSize.width / 2, y: field.origin.y + field.mapSize.height / 2)
                }
                FieldPanel(session: session, mode: panel, field: field)
                    .frame(width: max(0, panelRight - field.origin.x), height: field.mapSize.height, alignment: .topTrailing)
                    .padding(.leading, field.origin.x)
                    .padding(.top, field.origin.y)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            .coordinateSpace(.named(FieldGeometry.space))
            .preference(key: RailFieldKey.self, value: panel == .cards ? field.shifted(by: wide) : nil)
            .onAppear { apply(layout) }
            .onChange(of: layout) { _, now in apply(now) }
        }
        .background(Theme.mapSurround)
    }

    private func apply(_ layout: SceneLayout) {
        // While a screen is still sizing up, the play area can be next to
        // nothing, which would make the scene enormous; wait for a real size.
        let full = BattlefieldScene.size(cols: session.level.cols, rows: session.level.rows, sideways: layout.sideways)
        guard layout.viewport.width <= full.width * 4, layout.viewport.height <= full.height * 4 else { return }
        session.scene.layout(viewport: layout.viewport, mapOffset: layout.mapOffset, sideways: layout.sideways)
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
