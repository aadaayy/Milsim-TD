import SwiftUI

/// The thin strip above the map: menu, level name, wave and Command Post health.
struct TopStrip: View {
    let session: GameSession
    let onMenu: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onMenu) {
                Image(systemName: "chevron.left").font(.system(size: 15, weight: .bold))
            }
            .buttonStyle(IconButtonStyle())
            .frame(width: 40, height: 36)
            .accessibilityLabel("Menu")
            .accessibilityIdentifier("menu")

            VStack(alignment: .leading, spacing: 0) {
                Text("CH \(session.level.chapter) · \(session.level.place.uppercased())")
                    .font(.stencil(11)).foregroundStyle(Theme.dim)
                Text(session.level.name.uppercased())
                    .font(.stencil(16)).foregroundStyle(Theme.text)
            }
            Spacer(minLength: 4)
            Text("WAVE \(max(session.wavesStarted, 1))/\(session.game.waveCount)")
                .font(.stencil(15)).foregroundStyle(Theme.text)
                .accessibilityIdentifier("wave-label")
            CommandPostHealth(session: session)
        }
        .padding(.horizontal, 10)
        .frame(height: 46)
    }
}

/// The Command Post's health as a short bar and a number.
struct CommandPostHealth: View {
    let session: GameSession
    var wide = false

    var body: some View {
        let total = max(session.level.commandPostHealth, 1)
        let share = Double(session.commandPostHealth) / Double(total)
        HStack(spacing: 6) {
            Image(systemName: "building.columns.fill").font(.system(size: 12)).foregroundStyle(Theme.dim)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.black.opacity(0.45))
                Capsule().fill(share > 0.5 ? Theme.good : share > 0.25 ? Theme.sand : Theme.alert)
                    .frame(width: (wide ? 120 : 54) * share)
            }
            .frame(width: wide ? 120 : 54, height: 8)
            Text("\(session.commandPostHealth)").font(.readout(13)).foregroundStyle(Theme.text).monospacedDigit()
                .fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Command Post health \(session.commandPostHealth) of \(total)")
        .accessibilityIdentifier("cp-health")
    }
}

/// Supply, the wave button, pause and speed: everything a thumb needs, along the bottom.
struct ControlBar: View {
    let session: GameSession

    var body: some View {
        HStack(spacing: 8) {
            SupplyLabel(amount: session.supply, size: 18)
                .padding(.horizontal, 10)
                .frame(minHeight: 46)
                .panel(raised: true)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Supply \(session.supply)")
                .accessibilityIdentifier("supply")
            waveButton
            Button(action: session.togglePause) {
                Image(systemName: session.isPaused ? "play.fill" : "pause.fill")
            }
            .buttonStyle(IconButtonStyle())
            .accessibilityLabel(session.isPaused ? "Resume" : "Pause")
            .accessibilityIdentifier("pause")
            Button(action: session.cycleSpeed) {
                Text("\(session.speed)×").font(.readout(16))
            }
            .buttonStyle(IconButtonStyle())
            .accessibilityLabel("Speed \(session.speed) times")
            .accessibilityIdentifier("speed")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var waveButton: some View {
        switch session.phase {
        case .build:
            Button("START WAVE 1", action: session.startNextWave)
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("start-wave")
        case .pause:
            Button(action: session.startNextWave) {
                HStack(spacing: 6) {
                    Text("WAVE \(session.wavesStarted + 1)")
                    Text("IN \(session.breakSeconds)").font(.readout(14))
                    Image(systemName: "forward.fill").font(.system(size: 12))
                }
            }
            .buttonStyle(PrimaryButtonStyle(color: Theme.olive))
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("start-wave")
        case .won, .lost:
            Text(session.phase == .lost ? "OVERRUN" : "LINE HELD").font(.stencil(15)).foregroundStyle(Theme.text)
                .frame(maxWidth: .infinity, minHeight: 46)
                .panel()
                .accessibilityIdentifier("wave-status")
        default:
            HStack(spacing: 6) {
                Circle().fill(Theme.alert).frame(width: 8, height: 8)
                Text("WAVE \(session.wavesStarted) INBOUND").font(.stencil(15)).foregroundStyle(Theme.text)
            }
            .frame(maxWidth: .infinity, minHeight: 46)
            .panel()
            .accessibilityIdentifier("wave-status")
        }
    }
}

/// The panel under the map: the build menu, a position's card, or what's coming next.
struct ContextPanel: View {
    let session: GameSession
    /// The open Duo's side panel has room for descriptions.
    var roomy = false

    var body: some View {
        Group {
            switch session.selection {
            case .slot(let slot):
                BuildMenu(session: session, slot: slot, roomy: roomy)
            case .position(let id):
                PositionCard(session: session, id: id, roomy: roomy)
            case .none:
                WaveIntel(session: session, roomy: roomy)
            }
        }
        .padding(.horizontal, 10)
        .animation(.easeOut(duration: 0.15), value: session.selection)
    }
}

/// The three positions that can go on a pad, with their costs.
struct BuildMenu: View {
    let session: GameSession
    let slot: Int
    var roomy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("BUILD ON PAD \(slot + 1)").font(.stencil(13)).foregroundStyle(Theme.dim)
                Spacer()
                Button("Cancel") { session.selection = .none }
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.sand)
            }
            let layout = roomy ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
            layout {
                ForEach(session.catalog.positions) { type in
                    option(type)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("build-menu")
    }

    private func option(_ type: PositionType) -> some View {
        let first = type.levels[0]
        let affordable = session.supply >= first.cost
        return Button { session.build(type.id) } label: {
            if roomy {
                HStack(alignment: .top, spacing: 10) {
                    Portrait(name: first.sprite, size: 64)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(type.name.uppercased()).font(.stencil(16)).foregroundStyle(Theme.text)
                            Spacer()
                            SupplyLabel(amount: first.cost, size: 15)
                        }
                        Text(type.role).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.sand)
                        Text(type.manual).font(.system(size: 12)).foregroundStyle(Theme.dim)
                            .fixedSize(horizontal: false, vertical: true).lineLimit(3)
                        StatRow(level: first)
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .panel(raised: true)
            } else {
                VStack(spacing: 2) {
                    Portrait(name: first.sprite, size: 44)
                    Text(type.name).font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.text)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    SupplyLabel(amount: first.cost, size: 13)
                }
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .panel(raised: true)
            }
        }
        .buttonStyle(.plain)
        .opacity(affordable ? 1 : 0.45)
        .disabled(!affordable)
        .accessibilityLabel("\(type.name), \(first.cost) supply")
        .accessibilityIdentifier("build-\(type.id)")
    }
}

/// A built position: what it is, how it's doing, and what to do with it.
struct PositionCard: View {
    let session: GameSession
    let id: Int
    var roomy = false

    var body: some View {
        let _ = session.positionsVersion
        let _ = session.supply
        if let position = session.game.position(id: id), let type = session.catalog.position(position.type),
           let level = session.game.levelSpec(of: position) {
            VStack(alignment: .leading, spacing: roomy ? 10 : 6) {
                HStack(alignment: .top, spacing: 10) {
                    Portrait(name: level.sprite, size: roomy ? 72 : 52)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(type.name.uppercased()).font(.stencil(roomy ? 18 : 15)).foregroundStyle(Theme.text)
                        HStack(spacing: 4) {
                            Image("badge_level_\(position.level + 1)").resizable().frame(width: 16, height: 16)
                            Text("Level \(position.level + 1): \(level.title)")
                                .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.sand)
                        }
                        StatRow(level: level, kills: position.kills)
                    }
                    Spacer(minLength: 0)
                    if !roomy { actions(position) }
                }
                if roomy {
                    Text(type.manual).font(.system(size: 13)).foregroundStyle(Theme.dim)
                        .fixedSize(horizontal: false, vertical: true)
                }
                priorityPicker(position)
                if roomy {
                    if let next = session.game.nextLevelSpec(of: position) {
                        HStack(spacing: 8) {
                            Portrait(name: next.sprite, size: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("NEXT: \(next.title.uppercased())").font(.stencil(13)).foregroundStyle(Theme.dim)
                                StatRow(level: next)
                            }
                        }
                    }
                    actions(position)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("position-card")
        }
    }

    private func priorityPicker(_ position: Position) -> some View {
        HStack(spacing: 6) {
            Text("TARGET").font(.stencil(11)).foregroundStyle(Theme.dim)
            ForEach(TargetPriority.allCases, id: \.self) { priority in
                Button {
                    session.setPriority(priority, for: position.id)
                } label: {
                    HStack(spacing: 3) {
                        Image("badge_priority_\(priority.rawValue)").resizable().frame(width: 14, height: 14)
                        Text(priority.label).font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 7)
                    .frame(height: 26)
                    .foregroundStyle(position.priority == priority ? Theme.background : Theme.text)
                    .background(position.priority == priority ? Theme.sand : Theme.panelRaised, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("priority-\(priority.rawValue)")
            }
        }
    }

    @ViewBuilder
    private func actions(_ position: Position) -> some View {
        let next = session.game.nextLevelSpec(of: position)
        let layout = roomy ? AnyLayout(HStackLayout(spacing: 8)) : AnyLayout(VStackLayout(spacing: 6))
        layout {
            if let next {
                Button { session.upgrade(position.id) } label: {
                    HStack(spacing: 4) {
                        Image("badge_upgrade").resizable().frame(width: 16, height: 16)
                        Text("\(next.cost)").font(.readout(14))
                    }
                    .frame(maxWidth: roomy ? .infinity : nil)
                }
                .buttonStyle(PrimaryButtonStyle(height: roomy ? 46 : 36))
                .disabled(!session.game.canUpgrade(position.id))
                .opacity(session.game.canUpgrade(position.id) ? 1 : 0.45)
                .accessibilityLabel("Upgrade for \(next.cost) supply")
                .accessibilityIdentifier("upgrade")
            }
            Button { session.sell(position.id) } label: {
                HStack(spacing: 4) {
                    Image("badge_sell").resizable().frame(width: 16, height: 16)
                    Text("+\(session.game.refund(for: position.id))").font(.readout(14))
                }
                .frame(maxWidth: roomy ? .infinity : nil)
            }
            .buttonStyle(IconButtonStyle(height: roomy ? 46 : 36))
            .accessibilityLabel("Sell for \(session.game.refund(for: position.id)) supply")
            .accessibilityIdentifier("sell")
        }
    }
}

/// Range, damage per second and noise, in a row.
struct StatRow: View {
    let level: PositionLevel
    var kills: Int?

    var body: some View {
        HStack(spacing: 10) {
            stat("RNG", String(format: "%.1f", level.range))
            stat("DPS", String(format: "%.0f", level.damage / level.fireInterval))
            stat("NOISE", "\(level.noise)")
            if let kills { stat("KILLS", "\(kills)") }
        }
    }

    private func stat(_ name: String, _ value: String) -> some View {
        HStack(spacing: 3) {
            Text(name).font(.stencil(10)).foregroundStyle(Theme.dim)
            Text(value).font(.readout(12)).foregroundStyle(Theme.text)
        }
    }
}

/// What the next wave holds, with the field manual's words on each zombie when there's room.
struct WaveIntel: View {
    let session: GameSession
    var roomy = false

    var body: some View {
        let waveIndex: Int = {
            if case .wave = session.phase { return session.wavesStarted - 1 }
            return session.wavesStarted
        }()
        VStack(alignment: .leading, spacing: 6) {
            if let wave = session.level.waves[safe: waveIndex] {
                HStack {
                    Text(session.phase == .wave ? "ON THE ROAD: WAVE \(waveIndex + 1)" : "NEXT: WAVE \(waveIndex + 1)")
                        .font(.stencil(13)).foregroundStyle(Theme.dim)
                    Spacer()
                    Text("\(wave.total) hostiles").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.sand)
                }
                let layout = roomy ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
                layout {
                    ForEach(wave.counts.map { $0.zombie }, id: \.self) { zombieID in
                        let count = wave.counts.first(where: { $0.zombie == zombieID })?.count ?? 0
                        if let zombie = session.catalog.zombie(zombieID) {
                            HStack(alignment: .top, spacing: 8) {
                                Portrait(name: zombie.id, size: roomy ? 52 : 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(count) × \(zombie.name.uppercased())").font(.stencil(14)).foregroundStyle(Theme.text)
                                    if roomy {
                                        Text(zombie.manual).font(.system(size: 12)).foregroundStyle(Theme.dim)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            if session.phase == .build {
                Text("Tap a cleared pad on the map to build. Tap a position for its card.")
                    .font(.system(size: 12)).foregroundStyle(Theme.dim)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("wave-intel")
    }
}

/// A unit or zombie portrait from the art set, in a small dark frame.
struct Portrait: View {
    let name: String
    let size: CGFloat

    var body: some View {
        Image("portrait_\(name)")
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .background(Theme.background)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.edge, lineWidth: 1))
            .accessibilityHidden(true)
    }
}
