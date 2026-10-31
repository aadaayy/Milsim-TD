import SwiftUI

/// A level being played, laid out for the shape of the screen:
/// - tall and narrow (a regular iPhone or Pro Max, upright): the map with
///   the controls under it, all within thumb reach
/// - upright but stubbier (the folded iPhone Duo): the map on the left and
///   a side bar of controls on the right, using the width beside the map
/// - wide (the open iPhone Duo): the map on one half and the full command
///   panel, with room to explain everything, on the other
struct GameScreen: View {
    let session: GameSession
    let onRetry: () -> Void
    let onMenu: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width > geometry.size.height * 1.05
            let sideBar = !wide && geometry.size.height < geometry.size.width * 1.75
            ZStack {
                Theme.background.ignoresSafeArea()
                if wide {
                    WideGameLayout(map: mapPane, panel: CommandPanel(session: session))
                } else if sideBar {
                    HStack(spacing: 0) {
                        mapPane
                        Rectangle().fill(Theme.edge).frame(width: 1).ignoresSafeArea()
                        SideBar(session: session)
                            .frame(width: min(240, geometry.size.width * 0.36))
                    }
                } else {
                    VStack(spacing: 0) {
                        TopStrip(session: session, onMenu: onMenu)
                        MapView(session: session)
                        ContextPanel(session: session)
                            .frame(height: 118, alignment: .top)
                            .padding(.top, 6)
                        ControlBar(session: session)
                    }
                }
                if session.isOver {
                    EndOverlay(session: session, onRetry: onRetry, onMenu: onMenu)
                }
            }
        }
    }

    private var mapPane: some View {
        VStack(spacing: 0) {
            TopStrip(session: session, onMenu: onMenu)
            MapView(session: session)
        }
    }
}

/// The open Duo's second half: the numbers, the build menu or a position's
/// card with room to explain itself, what's coming next, and the controls.
struct CommandPanel: View {
    let session: GameSession

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("COMMAND").font(.stencil(22)).foregroundStyle(Theme.text)
                Spacer()
                Text("\(session.kills) KILLS").font(.stencil(14)).foregroundStyle(Theme.dim)
            }
            HStack(spacing: 14) {
                SupplyLabel(amount: session.supply, size: 22)
                CommandPostHealth(session: session, wide: true)
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
            ControlBar(session: session)
                .padding(.horizontal, -10)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .background(Theme.panel)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("command-panel")
    }
}

/// The folded Duo's right-hand column: the numbers at the top, the build
/// menu or a position's card in the middle, and the wave, pause and speed
/// buttons at the bottom where the thumb rests.
struct SideBar: View {
    let session: GameSession

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("COMMAND").font(.stencil(18)).foregroundStyle(Theme.text)
                Spacer()
                Text("\(session.kills) KILLS").font(.stencil(12)).foregroundStyle(Theme.dim)
            }
            .padding(.horizontal, 10)
            Divider().overlay(Theme.edge)
            ScrollView {
                ContextPanel(session: session, column: true)
                    .padding(.top, 2)
            }
            .scrollIndicators(.hidden)
            Divider().overlay(Theme.edge)
            ControlBar(session: session, column: true)
        }
        .padding(.top, 12)
        .background(Theme.panel)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("side-bar")
    }
}

/// Two halves side by side.
///
/// On iPhone Duo, `ArrangementView` keeps both halves clear of the fold when
/// the phone is partly folded. Older SDKs, which can't build `ArrangementView`,
/// get a plain side-by-side layout; the automatic checks set NO_DUO_SDK when
/// their Xcode is older than 27.1.
struct WideGameLayout<Map: View, Panel: View>: View {
    let map: Map
    let panel: Panel

    var body: some View {
        #if NO_DUO_SDK
        sideBySide
        #else
        if #available(iOS 27.1, *) {
            ArrangementView {
                map
            } secondary: {
                panel
            }
            .arrangementViewStyle(.split)
        } else {
            sideBySide
        }
        #endif
    }

    private var sideBySide: some View {
        HStack(spacing: 0) {
            map
            Rectangle().fill(Theme.edge).frame(width: 1).ignoresSafeArea()
            panel
        }
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
                    stat("WAVES", "\(session.wavesStarted)/\(session.game.waveCount)")
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
