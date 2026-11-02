import SwiftUI

/// A level being played, laid out for the shape of the screen. Every layout
/// gives the map as much room as it can take, with a see-through panel
/// floating over its right-hand side to drag positions from:
/// - tall and narrow (a regular iPhone or Pro Max, upright): the map with
///   supply and the round buttons in a bar under it, within thumb reach
/// - upright but stubbier (the folded iPhone Duo): the map at full height,
///   with the panel as a side bar holding supply and the round buttons too
/// - wide (the open iPhone Duo): the map with the positions beside it, and a
///   narrow Command column on the right. Put Command away and the map turns
///   sideways to fill the screen, with a slim rail of positions and buttons
struct GameScreen: View {
    let session: GameSession
    let onRetry: () -> Void
    let onMenu: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width > geometry.size.height * 1.05
            // Regular iPhones are about twice as tall as wide; the folded Duo is stubbier.
            let sideBar = !wide && geometry.size.height < geometry.size.width * 1.85
            ZStack {
                Theme.background.ignoresSafeArea()
                if wide {
                    WideGameLayout(session: session, onMenu: onMenu)
                } else if sideBar {
                    VStack(spacing: 0) {
                        TopStrip(session: session, onMenu: onMenu)
                        MapView(session: session, panel: .folded)
                    }
                } else {
                    VStack(spacing: 0) {
                        TopStrip(session: session, onMenu: onMenu)
                        MapView(session: session, panel: .phone)
                        ControlBar(session: session)
                    }
                }
                if session.isOver {
                    EndOverlay(session: session, onRetry: onRetry, onMenu: onMenu)
                }
            }
        }
    }
}

/// The open Duo, two ways:
/// - Command shown: the map upright with the positions to drag beside it,
///   and the Command column on the right.
/// - Command put away: the map turned sideways, so it fills the screen's
///   width and comes out much bigger, with a slim rail on the right holding
///   the positions to drag, supply and the round, pause and speed buttons.
///   A tapped tile or position opens its card over the map.
struct WideGameLayout: View {
    let session: GameSession
    let onMenu: () -> Void
    /// The coordinate space the rail's positions are dragged in.
    static let space = "wide"
    @State private var railField: FieldGeometry?

    var body: some View {
        let hidden = session.commandHidden
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                TopStrip(session: session, onMenu: onMenu, showsNext: hidden)
                MapView(session: session, panel: hidden ? .cards : .open, sideways: hidden)
            }
            Rectangle().fill(Theme.edge).frame(width: 1).ignoresSafeArea()
            if hidden {
                CommandRail(session: session, field: railField)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                CommandPanel(session: session)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .coordinateSpace(.named(Self.space))
        .onPreferenceChange(RailFieldKey.self) { railField = $0 }
        .animation(.easeOut(duration: 0.2), value: hidden)
    }
}

/// The open Duo's Command column: supply, kills, the build list or a
/// position's card with room to explain itself, what's coming next, and the
/// round, pause and speed buttons. Its button puts it away to a slim rail.
/// Command Post health is in the strip over the map, so it isn't repeated here.
struct CommandPanel: View {
    let session: GameSession
    static let width: CGFloat = 320

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Text("COMMAND").font(.stencil(18)).foregroundStyle(Theme.text)
                Spacer(minLength: 4)
                Button(action: session.toggleCommand) {
                    HStack(spacing: 4) {
                        Text("HIDE").font(.stencil(12))
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(Theme.panelRaised, in: Capsule())
                    .overlay(Capsule().strokeBorder(Theme.edge.opacity(0.7), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Hide Command")
                .accessibilityIdentifier("command-hide")
            }
            HStack(spacing: 10) {
                SupplyLabel(amount: session.supply, size: 20)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Supply \(session.supply)")
                    .accessibilityIdentifier("supply")
                Spacer(minLength: 4)
                Text("\(session.kills) KILLS").font(.stencil(13)).foregroundStyle(Theme.dim)
            }
            Divider().overlay(Theme.edge)
            ScrollView {
                ContextPanel(session: session, roomy: true)
                    .padding(.horizontal, -10)
                if session.selection != .none {
                    Divider().overlay(Theme.edge).padding(.vertical, 6)
                    WaveIntel(session: session, roomy: true)
                }
            }
            .scrollIndicators(.hidden)
            ControlBar(session: session, showsSupply: false)
                .padding(.horizontal, -10)
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .frame(width: Self.width)
        .frame(maxHeight: .infinity)
        .background(Theme.panel)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("command-panel")
    }
}

/// The open Duo's Command column put away: a slim rail with the button to
/// bring it back, supply, the positions to drag onto the map, and the round,
/// pause and speed buttons at the bottom.
struct CommandRail: View {
    let session: GameSession
    /// Where the sideways map sits, as the rail sees it; nil until it's laid out.
    let field: FieldGeometry?
    static let width: CGFloat = 124

    var body: some View {
        VStack(spacing: 8) {
            Button(action: session.toggleCommand) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 12, weight: .bold))
                    Text("COMMAND").font(.stencil(12))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(IconButtonStyle(height: 40))
            .padding(.horizontal, 10)
            .accessibilityLabel("Show Command")
            .accessibilityIdentifier("command-show")
            SupplyLabel(amount: session.supply, size: 18)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Supply \(session.supply)")
                .accessibilityIdentifier("supply")
            Divider().overlay(Theme.edge)
            VStack(spacing: 6) {
                Text("DRAG TO BUILD").font(.stencil(10)).foregroundStyle(Theme.dim)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(session.catalog.positions) { type in
                    if let field {
                        TrayItem(session: session, type: type, field: field, space: WideGameLayout.space)
                    } else {
                        DefenseTile(type: type, highlighted: false)
                    }
                }
            }
            .padding(.horizontal, 10)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("tray")
            Spacer(minLength: 0)
            Divider().overlay(Theme.edge)
            ControlBar(session: session, column: true)
        }
        .padding(.top, 10)
        .frame(width: Self.width)
        .frame(maxHeight: .infinity)
        .background(Theme.panel)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("command-rail")
    }
}

/// Mission complete or Command Post overrun, with the stars and a way back in.
struct EndOverlay: View {
    let session: GameSession
    let onRetry: () -> Void
    let onMenu: () -> Void

    var body: some View {
        let won: Bool = { if case .won = session.phase { return true }; return false }()
        let stars: Int = { if case .won(let s) = session.phase { return s }; return 0 }()
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 14) {
                Text(won ? "MISSION COMPLETE" : "COMMAND POST OVERRUN")
                    .font(.stencil(28)).foregroundStyle(won ? Theme.sand : Theme.alert)
                    .multilineTextAlignment(.center)
                if won {
                    HStack(spacing: 10) {
                        ForEach(0..<3, id: \.self) { i in
                            Image(i < stars ? "badge_star" : "badge_star_empty")
                                .resizable().frame(width: 52, height: 52)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(stars) of 3 stars")
                    VStack(alignment: .leading, spacing: 4) {
                        starLine("Hold the crossroads", earned: stars >= 1)
                        starLine("Keep the Command Post healthy", earned: stars >= 2)
                        starLine(session.level.bonusObjective, earned: stars >= 3)
                    }
                } else {
                    Text("The horde broke through on wave \(session.wavesStarted). Every position you build stays a choice: try a different mix.")
                        .font(.system(size: 14)).foregroundStyle(Theme.dim).multilineTextAlignment(.center)
                }
                HStack(spacing: 24) {
                    stat("KILLS", "\(session.kills)")
                    stat("ROUNDS", "\(session.wavesStarted)/\(session.game.waveCount)")
                    stat("COMMAND POST", "\(session.commandPostHealth)/\(session.level.commandPostHealth)")
                }
                HStack(spacing: 10) {
                    Button("MENU", action: onMenu).buttonStyle(IconButtonStyle()).frame(width: 90)
                        .accessibilityIdentifier("end-menu")
                    Button(won ? "PLAY AGAIN" : "RETRY", action: onRetry).buttonStyle(PrimaryButtonStyle())
                        .accessibilityIdentifier("retry")
                }
            }
            .padding(22)
            .frame(maxWidth: 380)
            .panel(raised: true)
            .padding(20)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("end-screen")
    }

    private func starLine(_ text: String, earned: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: earned ? "checkmark.circle.fill" : "circle").foregroundStyle(earned ? Theme.good : Theme.dim)
            Text(text).font(.system(size: 13)).foregroundStyle(Theme.text)
        }
    }

    private func stat(_ name: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.readout(18)).foregroundStyle(Theme.text)
            Text(name).font(.stencil(10)).foregroundStyle(Theme.dim)
        }
    }
}
