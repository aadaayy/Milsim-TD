import SwiftUI

/// The see-through panel floating over the right-hand side of the map, so the
/// whole battlefield stays in view behind it.
///
/// It holds the three positions to drag onto the map. Tap a free tile and it
/// turns into that tile's build list; tap a built position and it shows that
/// position's card. The chevron folds it away to a small tab.
///
/// - phone (regular iPhone and Pro Max): positions and what's coming next;
///   supply and the round buttons stay in the bar under the map.
/// - folded Duo: a side bar, with supply at the top and the round, pause and
///   speed buttons at the bottom, where the thumb rests.
/// - open Duo: just the positions to drag, with cards and what's coming next
///   in the Command column; when that's put away, this panel shows them as
///   it does on a phone.
struct FieldPanel: View {
    enum Mode { case phone, folded, open }

    let session: GameSession
    let mode: Mode
    let field: FieldGeometry

    private enum Content: Equatable {
        case tray
        case buildHere
        case card(Int)
    }

    /// On the open Duo the Command column shows cards, the build list and
    /// what's coming next; when it's put away, this panel shows them instead.
    private var commandBeside: Bool { mode == .open && !session.commandHidden }

    private var content: Content {
        guard !commandBeside else { return .tray }
        switch session.selection {
        case .none: return .tray
        case .tile: return .buildHere
        case .position(let id): return .card(id)
        }
    }

    /// Room the open Duo's panel takes beside the map, margins included.
    static let openWidth: CGFloat = 106

    private var width: CGFloat {
        if case .card = content { return 166 }
        return mode == .folded ? 124 : 94
    }

    private static let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)

    var body: some View {
        Group {
            if session.panelCollapsed {
                collapsed
            } else {
                expanded
            }
        }
        .padding(6)
        .animation(.easeOut(duration: 0.18), value: session.panelCollapsed)
        .animation(.easeOut(duration: 0.15), value: content)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(mode == .folded ? "side-bar" : "field-panel")
    }

    // MARK: Open

    private var expanded: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                header
                switch content {
                case .tray:
                    tray
                    if !commandBeside {
                        Divider().overlay(Theme.edge)
                        fitting { MiniWaveIntel(session: session) }
                    }
                case .buildHere:
                    buildHere
                case .card(let id):
                    fitting {
                        PositionCard(session: session, id: id, column: true)
                    }
                }
            }
            .padding(8)
            if mode == .folded {
                Spacer(minLength: 0)
                Divider().overlay(Theme.edge)
                ControlBar(session: session, column: true)
            }
        }
        .frame(width: width, alignment: .leading)
        .frame(maxHeight: mode == .folded ? .infinity : nil, alignment: .top)
        .background(Theme.panel.opacity(0.62), in: Self.shape)
        .overlay(Self.shape.strokeBorder(Theme.edge.opacity(0.6), lineWidth: 1))
    }

    /// Shows its content as it is when it fits, and in a scroll view when it doesn't.
    private func fitting<Inner: View>(@ViewBuilder _ inner: () -> Inner) -> some View {
        let built = inner()
        return ViewThatFits(in: .vertical) {
            built
            ScrollView { built }.scrollIndicators(.hidden)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 4) {
            if mode == .folded {
                SupplyLabel(amount: session.supply, size: 17)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Supply \(session.supply)")
                    .accessibilityIdentifier("supply")
            } else {
                Text(content == .tray ? "DRAG TO BUILD" : content == .buildHere ? "BUILD HERE" : "POSITION")
                    .font(.stencil(11)).foregroundStyle(Theme.dim)
                    .lineLimit(2).minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
            Button {
                session.panelCollapsed = true
            } label: {
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .frame(width: 26, height: 26)
                    .background(Theme.panelRaised.opacity(0.8), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Hide the panel")
            .accessibilityIdentifier("panel-collapse")
        }
    }

    /// The three positions, ready to drag onto the map.
    private var tray: some View {
        VStack(spacing: 6) {
            if mode == .folded {
                Text("DRAG TO BUILD").font(.stencil(10)).foregroundStyle(Theme.dim)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            ForEach(session.catalog.positions) { type in
                TrayItem(session: session, type: type, field: field)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tray")
    }

    /// A free tile was tapped: the three positions, each a tap to build there.
    private var buildHere: some View {
        VStack(spacing: 6) {
            ForEach(session.catalog.positions) { type in
                let first = type.levels[0]
                let affordable = session.supply >= first.cost
                Button { session.build(type.id) } label: {
                    DefenseTile(type: type, highlighted: false)
                }
                .buttonStyle(.plain)
                .opacity(affordable ? 1 : 0.45)
                .disabled(!affordable)
                .accessibilityLabel("Build \(type.name) here, \(first.cost) supply")
                .accessibilityIdentifier("build-\(type.id)")
            }
            Button("Cancel") { session.selection = .none }
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.sand)
                .frame(maxWidth: .infinity, minHeight: 30)
                .accessibilityIdentifier("build-cancel")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("build-menu")
    }

    // MARK: Folded away

    private var collapsed: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Button {
                session.panelCollapsed = false
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: "chevron.left").font(.system(size: 12, weight: .bold))
                    Image(systemName: "hammer.fill").font(.system(size: 13))
                }
                .foregroundStyle(Theme.text)
                .frame(width: 34, height: 58)
                .background(Theme.panel.opacity(0.62), in: Self.shape)
                .overlay(Self.shape.strokeBorder(Theme.edge.opacity(0.6), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Show the panel")
            .accessibilityIdentifier("panel-expand")
            if mode == .folded {
                // The round, pause and speed buttons stay within reach.
                Spacer(minLength: 0)
                VStack(spacing: 0) {
                    SupplyLabel(amount: session.supply, size: 15)
                        .padding(.top, 8)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Supply \(session.supply)")
                        .accessibilityIdentifier("supply")
                    ControlBar(session: session, column: true)
                }
                .frame(width: 124)
                .background(Theme.panel.opacity(0.62), in: Self.shape)
                .overlay(Self.shape.strokeBorder(Theme.edge.opacity(0.6), lineWidth: 1))
            }
        }
        .frame(maxHeight: mode == .folded ? .infinity : nil, alignment: .top)
    }
}

/// One position in the panel: its picture, name and price.
struct DefenseTile: View {
    let type: PositionType
    var highlighted: Bool

    var body: some View {
        let first = type.levels[0]
        VStack(spacing: 2) {
            Portrait(name: first.sprite, size: 40)
            Text(type.name.uppercased()).font(.stencil(11)).foregroundStyle(Theme.text)
                .multilineTextAlignment(.center)
                .lineLimit(2).minimumScaleFactor(0.75)
                .frame(minHeight: 26)
            SupplyLabel(amount: first.cost, size: 12)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 3)
        .frame(maxWidth: .infinity)
        .background(Theme.panelRaised.opacity(highlighted ? 0.95 : 0.7), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(highlighted ? Theme.sand : Theme.edge.opacity(0.7), lineWidth: highlighted ? 2 : 1))
    }
}

/// A position in the panel that can be dragged onto the map. While it's
/// dragged, the map shows the tile it would land on (green, or red where it
/// can't go); letting go there builds it.
struct TrayItem: View {
    let session: GameSession
    let type: PositionType
    let field: FieldGeometry
    @GestureState private var dragging = false

    var body: some View {
        let first = type.levels[0]
        let affordable = session.supply >= first.cost
        DefenseTile(type: type, highlighted: dragging)
            .opacity(affordable ? 1 : 0.45)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 6, coordinateSpace: .named(FieldGeometry.space))
                    .updating($dragging) { _, state, _ in state = true }
                    .onChanged { session.drag(type.id, over: field.tile(under: $0.location)) }
                    .onEnded { session.drop(type.id, on: field.tile(under: $0.location)) }
            )
            .onChange(of: dragging) { _, now in
                // A drag the system cut short never ends with a drop: clear its preview.
                if !now, session.placement?.type == type.id { session.placement = nil }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(type.name), \(first.cost) supply. Drag onto an open tile to build.")
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("tray-\(type.id)")
    }
}

/// What the next round holds, small enough for the panel: each kind's picture and count.
struct MiniWaveIntel: View {
    let session: GameSession

    var body: some View {
        let onNow: Bool = { if case .wave = session.phase { return true }; return false }()
        let index = onNow ? session.wavesStarted - 1 : session.wavesStarted
        VStack(alignment: .leading, spacing: 5) {
            if let wave = session.level.waves[safe: index] {
                Text(onNow ? "ON THE ROAD" : "NEXT").font(.stencil(10)).foregroundStyle(Theme.dim)
                HStack(spacing: 4) {
                    Text("ROUND \(index + 1)").font(.stencil(12)).foregroundStyle(Theme.text)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    if wave.boss == true {
                        Text("BOSS").font(.stencil(9)).foregroundStyle(Theme.background)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(Theme.alert, in: Capsule())
                            .accessibilityIdentifier("boss-tag")
                    }
                }
                ForEach(wave.counts.map { $0.zombie }, id: \.self) { zombieID in
                    let count = wave.counts.first(where: { $0.zombie == zombieID })?.count ?? 0
                    if let zombie = session.catalog.zombie(zombieID) {
                        HStack(spacing: 6) {
                            Portrait(name: zombie.id, size: 28)
                            Text("×\(count)").font(.stencil(13))
                                .foregroundStyle(zombie.boss == true ? Theme.alert : Theme.text)
                                .lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(count) \(zombie.name)")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("wave-intel")
    }
}
