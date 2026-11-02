import SwiftUI

/// The thin strip above the map: menu, level name, round and Command Post health.
struct TopStrip: View {
    let session: GameSession
    let onMenu: () -> Void
    /// What the next round holds, in a short row (the open Duo with Command put away).
    var showsNext = false

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
            if showsNext {
                Spacer(minLength: 4)
                NextRoundStrip(session: session)
            }
            Spacer(minLength: 4)
            Text("ROUND \(max(session.wavesStarted, 1))/\(session.game.waveCount)")
                .font(.stencil(15)).foregroundStyle(Theme.text)
                .lineLimit(1).minimumScaleFactor(0.7)
                .accessibilityIdentifier("wave-label")
            CommandPostHealth(session: session)
        }
        .padding(.horizontal, 10)
        .frame(height: 46)
    }
}

/// The next round in one short row: each kind of zombie's picture and count.
struct NextRoundStrip: View {
    let session: GameSession

    var body: some View {
        let onNow: Bool = { if case .wave = session.phase { return true }; return false }()
        let index = onNow ? session.wavesStarted - 1 : session.wavesStarted
        if let wave = session.level.waves[safe: index] {
            HStack(spacing: 8) {
                Text(onNow ? "ON THE ROAD" : "NEXT").font(.stencil(11)).foregroundStyle(Theme.dim)
                if wave.boss == true {
                    Text("BOSS").font(.stencil(10)).foregroundStyle(Theme.background)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Theme.alert, in: Capsule())
                }
                ForEach(wave.counts.prefix(4).map { $0.zombie }, id: \.self) { zombieID in
                    let count = wave.counts.first(where: { $0.zombie == zombieID })?.count ?? 0
                    if let zombie = session.catalog.zombie(zombieID) {
                        HStack(spacing: 3) {
                            Portrait(name: zombie.id, size: 26)
                            Text("×\(count)").font(.stencil(13))
                                .foregroundStyle(zombie.boss == true ? Theme.alert : Theme.text)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(count) \(zombie.name)")
                    }
                }
                if wave.counts.count > 4 {
                    Text("+\(wave.counts.count - 4)").font(.stencil(12)).foregroundStyle(Theme.dim)
                }
            }
            .lineLimit(1)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("next-round")
        }
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

/// Supply, the round button, pause and speed: everything a thumb needs, along the bottom.
struct ControlBar: View {
    let session: GameSession
    /// The folded Duo's side bar: the round button on its own row, pause and
    /// speed under it. The side bar shows supply at its top instead.
    var column = false
    /// False where supply is already shown nearby (the open Duo's Command column).
    var showsSupply = true

    var body: some View {
        if column {
            VStack(spacing: 8) {
                waveButton
                HStack(spacing: 8) {
                    pauseAndSpeed
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        } else {
            HStack(spacing: 8) {
                if showsSupply { supply }
                waveButton
                pauseAndSpeed
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
    }

    private var supply: some View {
        SupplyLabel(amount: session.supply, size: 18)
            .padding(.horizontal, 10)
            .frame(minHeight: 46)
            .panel(raised: true)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Supply \(session.supply)")
            .accessibilityIdentifier("supply")
    }

    @ViewBuilder
    private var pauseAndSpeed: some View {
        Button(action: session.togglePause) {
            Image(systemName: session.isPaused ? "play.fill" : "pause.fill")
                .frame(maxWidth: column ? .infinity : nil)
        }
        .buttonStyle(IconButtonStyle(lit: session.isPaused))
        .accessibilityLabel(session.isPaused ? "Resume" : "Pause")
        .accessibilityIdentifier("pause")
        Button(action: session.cycleSpeed) {
            Text("\(session.speed)×").font(.readout(16))
                .frame(maxWidth: column ? .infinity : nil)
        }
        .buttonStyle(IconButtonStyle(lit: session.speed > 1))
        .accessibilityLabel("Speed \(session.speed) times")
        .accessibilityIdentifier("speed")
    }

    private var waveButton: some View {
        waveButtonContent
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }

    @ViewBuilder
    private var waveButtonContent: some View {
        switch session.phase {
        case .build:
            Button(action: session.startNextWave) {
                if column {
                    // The side bar is narrow: two short lines instead of one cut-off one.
                    VStack(spacing: 1) {
                        Text("START")
                        Text("ROUND 1")
                    }
                    .padding(.vertical, 4)
                } else {
                    Text("START ROUND 1")
                }
            }
                .buttonStyle(PrimaryButtonStyle(inset: column ? 8 : 16))
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("start-wave")
        case .pause:
            Button(action: session.startNextWave) {
                let boss = session.game.nextWave?.boss == true
                if column {
                    // The side bar is narrow: the round on one line, the countdown under it.
                    VStack(spacing: 1) {
                        Text(boss ? "BOSS \(session.wavesStarted + 1)" : "ROUND \(session.wavesStarted + 1)")
                        HStack(spacing: 4) {
                            Text("IN \(session.breakSeconds)").font(.readout(12))
                            Image(systemName: "forward.fill").font(.system(size: 10))
                        }
                    }
                    .padding(.vertical, 4)
                } else {
                    HStack(spacing: 6) {
                        Text("ROUND \(session.wavesStarted + 1)")
                        if boss { Text("BOSS") }
                        Text("IN \(session.breakSeconds)").font(.readout(14))
                        Image(systemName: "forward.fill").font(.system(size: 12))
                    }
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
                Text(session.game.level.waves[safe: session.wavesStarted - 1]?.boss == true
                     ? "BOSS ROUND \(session.wavesStarted)" : "ROUND \(session.wavesStarted) INBOUND")
                    .font(.stencil(15)).foregroundStyle(Theme.text)
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
    /// The folded Duo's narrow side bar: things stack instead of sitting side by side.
    var column = false
    /// False when the next round is shown elsewhere (under the folded Duo's map).
    var showsIntel = true

    var body: some View {
        Group {
            switch session.selection {
            case .tile:
                BuildMenu(session: session, roomy: roomy, column: column)
            case .position(let id):
                PositionCard(session: session, id: id, roomy: roomy, column: column)
            case .none:
                if showsIntel {
                    WaveIntel(session: session, roomy: roomy, column: column)
                } else {
                    Text("Drag a position onto any open tile, or tap a tile to build there. Tap a position to see its card.")
                        .font(.system(size: 13)).foregroundStyle(Theme.dim)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.horizontal, 10)
        .animation(.easeOut(duration: 0.15), value: session.selection)
    }
}

/// The three positions that can go on the picked tile, with their costs.
struct BuildMenu: View {
    let session: GameSession
    var roomy = false
    var column = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(column ? "BUILD HERE" : "BUILD ON THIS TILE").font(.stencil(13)).foregroundStyle(Theme.dim)
                Spacer()
                Button("Cancel") { session.selection = .none }
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.sand)
            }
            let layout = roomy || column ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
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
            } else if column {
                HStack(spacing: 8) {
                    Portrait(name: first.sprite, size: 42)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(type.name.uppercased()).font(.stencil(14)).foregroundStyle(Theme.text)
                            .lineLimit(2).minimumScaleFactor(0.7)
                        Text(type.role).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.sand)
                            .lineLimit(1).minimumScaleFactor(0.8)
                        SupplyLabel(amount: first.cost, size: 13)
                    }
                    Spacer(minLength: 0)
                }
                .padding(6)
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
    var column = false

    var body: some View {
        let _ = session.positionsVersion
        let _ = session.supply
        if let position = session.game.position(id: id), let type = session.catalog.position(position.type),
           let level = session.game.levelSpec(of: position) {
            VStack(alignment: .leading, spacing: roomy ? 10 : 6) {
                if column {
                    columnHeader(type: type, position: position, level: level)
                } else {
                    HStack(alignment: .top, spacing: 10) {
                        Portrait(name: level.sprite, size: roomy ? 60 : 52)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(type.name.uppercased()).font(.stencil(roomy ? 18 : 15)).foregroundStyle(Theme.text)
                            HStack(spacing: 4) {
                                Image("badge_level_\(position.levelName.lowercased())").resizable().frame(width: 16, height: 16)
                                Text("Level \(position.levelName): \(level.title)")
                                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.sand)
                            }
                            StatRow(level: level, kills: position.kills, stacked: roomy)
                        }
                        Spacer(minLength: 0)
                        if !roomy { actions(position) }
                    }
                }
                if column { StatRow(level: level, kills: position.kills, stacked: true) }
                if roomy {
                    Text(type.manual).font(.system(size: 13)).foregroundStyle(Theme.dim)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if column || roomy { columnPriorityPicker(position) } else { priorityPicker(position) }
                if session.game.upgradeOptions(of: position).count > 1 { levelThreeChoice(position) }
                if column { actions(position) }
                if roomy {
                    if let next = singleUpgrade(position) {
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

    /// The portrait and name side by side, the level under them, for the narrow side bar.
    private func columnHeader(type: PositionType, position: Position, level: PositionLevel) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Portrait(name: level.sprite, size: 44)
                Text(type.name.uppercased()).font(.stencil(15)).foregroundStyle(Theme.text)
                    .lineLimit(2).minimumScaleFactor(0.7)
            }
            HStack(spacing: 4) {
                Image("badge_level_\(position.levelName.lowercased())").resizable().frame(width: 16, height: 16)
                Text("Level \(position.levelName): \(level.title)")
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.sand)
                    .lineLimit(2).minimumScaleFactor(0.8)
            }
        }
    }

    /// The three targeting choices as small tiles, for the narrow side bar.
    private func columnPriorityPicker(_ position: Position) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("TARGET").font(.stencil(11)).foregroundStyle(Theme.dim)
            HStack(spacing: 4) {
                ForEach(TargetPriority.allCases, id: \.self) { priority in
                    let chosen = position.priority == priority
                    Button {
                        session.setPriority(priority, for: position.id)
                    } label: {
                        VStack(spacing: 2) {
                            Image("badge_priority_\(priority.rawValue)").resizable().frame(width: 16, height: 16)
                            Text(priority.label).font(.system(size: 10, weight: .semibold))
                                .lineLimit(1).minimumScaleFactor(0.6)
                        }
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .foregroundStyle(chosen ? Theme.background : Theme.text)
                        .background(chosen ? Theme.sand : Theme.panelRaised, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("priority-\(priority.rawValue)")
                }
            }
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

    /// The next level when there's just one; nil at the top or when level 3 is a choice.
    private func singleUpgrade(_ position: Position) -> PositionLevel? {
        let options = session.game.upgradeOptions(of: position)
        return options.count == 1 ? options[0] : nil
    }

    /// Level 3 comes in two versions: a button for each, with what it's good
    /// at when there's room. Picking one is for good, like an upgrade.
    private func levelThreeChoice(_ position: Position) -> some View {
        let options = session.game.upgradeOptions(of: position)
        let layout = column ? AnyLayout(VStackLayout(spacing: 6)) : AnyLayout(HStackLayout(spacing: 6))
        return VStack(alignment: .leading, spacing: 4) {
            if roomy || column {
                Text("LEVEL 3: PICK ONE").font(.stencil(11)).foregroundStyle(Theme.dim)
            }
            layout {
                ForEach(Array(options.enumerated()), id: \.offset) { branch, option in
                    choiceButton(position, branch: branch, option: option)
                }
            }
        }
    }

    private func choiceButton(_ position: Position, branch: Int, option: PositionLevel) -> some View {
        let name = branch == 0 ? "3A" : "3B"
        let affordable = session.game.canUpgrade(position.id, branch: branch)
        return Button { session.upgrade(position.id, branch: branch) } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Image("badge_level_\(name.lowercased())").resizable().frame(width: 16, height: 16)
                    Text(option.title.uppercased()).font(.stencil(13))
                        .lineLimit(1).minimumScaleFactor(0.6)
                    if !column && !roomy {
                        Spacer(minLength: 2)
                        cost(option)
                    }
                }
                // In the side bar and the Command column the price gets its own line, so the name fits.
                if column || roomy { cost(option) }
                if roomy || column, let about = option.about {
                    Text(about).font(.system(size: 11)).tracking(0)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, roomy || column ? 6 : 0)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(PrimaryButtonStyle(color: branch == 0 ? Theme.sand : Theme.olive, height: roomy || column ? 46 : 34, inset: 8))
        .disabled(!affordable)
        .opacity(affordable ? 1 : 0.45)
        .accessibilityLabel("Level 3\(branch == 0 ? "A" : "B"), \(option.title), for \(option.cost) supply")
        .accessibilityIdentifier("upgrade-\(name.lowercased())")
    }

    private func cost(_ option: PositionLevel) -> some View {
        HStack(spacing: 4) {
            Image("badge_upgrade").resizable().frame(width: 14, height: 14)
            Text("\(option.cost)").font(.readout(13))
        }
    }

    @ViewBuilder
    private func actions(_ position: Position) -> some View {
        let next = singleUpgrade(position)
        let wide = roomy || column
        // The side bar is too narrow for two buttons side by side, so they stack at full width.
        let layout = roomy ? AnyLayout(HStackLayout(spacing: 8)) : AnyLayout(VStackLayout(spacing: column ? 8 : 6))
        layout {
            if let next {
                Button { session.upgrade(position.id) } label: {
                    HStack(spacing: 4) {
                        Image("badge_upgrade").resizable().frame(width: 16, height: 16)
                        Text("\(next.cost)").font(.readout(14))
                    }
                    .frame(maxWidth: wide ? .infinity : nil)
                }
                .buttonStyle(PrimaryButtonStyle(height: wide ? 46 : 36))
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
                .frame(maxWidth: wide ? .infinity : nil)
            }
            .buttonStyle(IconButtonStyle(height: wide ? 46 : 36))
            .accessibilityLabel("Sell for \(session.game.refund(for: position.id)) supply")
            .accessibilityIdentifier("sell")
        }
    }
}

/// Range, damage per second and noise, in a row.
struct StatRow: View {
    let level: PositionLevel
    var kills: Int?
    /// Two short rows instead of one long one.
    var stacked = false

    var body: some View {
        if stacked {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    stat("RNG", String(format: "%.1f", level.range))
                    stat("DPS", String(format: "%.0f", level.damage / level.fireInterval))
                }
                HStack(spacing: 8) {
                    stat("NOISE", "\(level.noise)")
                    if let kills { stat("KILLS", "\(kills)") }
                }
            }
        } else {
            HStack(spacing: 10) {
                stat("RNG", String(format: "%.1f", level.range))
                stat("DPS", String(format: "%.0f", level.damage / level.fireInterval))
                stat("NOISE", "\(level.noise)")
                if let kills { stat("KILLS", "\(kills)") }
            }
        }
    }

    private func stat(_ name: String, _ value: String) -> some View {
        HStack(spacing: 3) {
            Text(name).font(.stencil(10)).foregroundStyle(Theme.dim)
            Text(value).font(.readout(12)).foregroundStyle(Theme.text)
        }
    }
}

/// What the next round holds, with the field manual's words on each zombie when there's room.
struct WaveIntel: View {
    let session: GameSession
    var roomy = false
    var column = false

    var body: some View {
        let waveIndex: Int = {
            if case .wave = session.phase { return session.wavesStarted - 1 }
            return session.wavesStarted
        }()
        VStack(alignment: .leading, spacing: 6) {
            if let wave = session.level.waves[safe: waveIndex] {
                let header = column ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2)) : AnyLayout(HStackLayout())
                header {
                    HStack(spacing: 6) {
                        Text(session.phase == .wave ? "ON THE ROAD: ROUND \(waveIndex + 1)" : "NEXT: ROUND \(waveIndex + 1)")
                            .font(.stencil(13)).foregroundStyle(Theme.dim)
                            .lineLimit(1).minimumScaleFactor(0.7)
                        if wave.boss == true {
                            Text("BOSS").font(.stencil(11)).foregroundStyle(Theme.background)
                                .padding(.horizontal, 6).padding(.vertical, 1)
                                .background(Theme.alert, in: Capsule())
                                .accessibilityIdentifier("boss-tag")
                        }
                    }
                    if !column { Spacer() }
                    Text("\(wave.total) hostiles").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.sand)
                }
                if roomy || column {
                    VStack(alignment: .leading, spacing: 8) { zombieRows(wave) }
                } else {
                    // Late rounds hold up to eight kinds, so the short strip scrolls sideways.
                    ScrollView(.horizontal) {
                        HStack(spacing: 10) { zombieRows(wave) }
                    }
                    .scrollIndicators(.hidden)
                }
            }
            if session.phase == .build {
                Text("Drag a position onto any open tile, or tap a tile to build there. Tap a position for its card.")
                    .font(.system(size: 12)).foregroundStyle(Theme.dim)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("wave-intel")
    }

    @ViewBuilder
    private func zombieRows(_ wave: WaveSpec) -> some View {
        ForEach(wave.counts.map { $0.zombie }, id: \.self) { zombieID in
            let count = wave.counts.first(where: { $0.zombie == zombieID })?.count ?? 0
            if let zombie = session.catalog.zombie(zombieID) {
                HStack(alignment: column || !roomy ? .center : .top, spacing: roomy || column ? 8 : 4) {
                    Portrait(name: zombie.id, size: roomy ? 52 : column ? 34 : 36)
                    VStack(alignment: .leading, spacing: 2) {
                        // The short strip gives the count only; the name is on the portrait's card.
                        Text(roomy || column ? "\(count) × \(zombie.name.uppercased())" : "×\(count)")
                            .font(.stencil(14)).foregroundStyle(zombie.boss == true ? Theme.alert : Theme.text)
                            .lineLimit(2).minimumScaleFactor(0.8)
                        if roomy {
                            Text(zombie.manual).font(.system(size: 12)).foregroundStyle(Theme.dim)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(count) \(zombie.name)")
            }
        }
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
