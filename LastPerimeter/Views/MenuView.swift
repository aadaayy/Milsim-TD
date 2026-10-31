import SwiftUI

/// The first screen: the title, the chapter and its first level.
struct MenuView: View {
    let content: GameContent
    let onPlay: (Int) -> Void

    var body: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width > geometry.size.height * 1.05
            ZStack {
                Theme.background.ignoresSafeArea()
                if wide {
                    HStack(spacing: 0) {
                        title.frame(maxWidth: .infinity, maxHeight: .infinity)
                        levelPanel.frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    VStack(spacing: 18) {
                        Spacer(minLength: 10)
                        title
                        Spacer(minLength: 10)
                        levelPanel
                    }
                    .padding(.bottom, 12)
                }
            }
        }
    }

    private var title: some View {
        VStack(spacing: 10) {
            ZStack {
                Portrait(name: "command_post", size: 150)
                    .offset(x: -50, y: -10)
                Portrait(name: "walker", size: 110)
                    .offset(x: 70, y: 30)
            }
            .frame(height: 190)
            Text("LAST PERIMETER")
                .font(.stencil(44))
                .tracking(2)
                .foregroundStyle(Theme.sand)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text("Hold the line against the outbreak.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.dim)
        }
        .padding(.horizontal, 20)
    }

    private var levelPanel: some View {
        let level = content.levels[0]
        return VStack(alignment: .leading, spacing: 12) {
            Text("CHAPTER \(level.chapter) · \(level.place.uppercased())").font(.stencil(13)).foregroundStyle(Theme.dim)
            HStack(alignment: .firstTextBaseline) {
                Text("1").font(.stencil(30)).foregroundStyle(Theme.sand)
                Text(level.name.uppercased()).font(.stencil(26)).foregroundStyle(Theme.text)
                Spacer()
                Text("\(level.waves.count) WAVES").font(.stencil(13)).foregroundStyle(Theme.dim)
            }
            Text(level.briefing).font(.system(size: 14)).foregroundStyle(Theme.text.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Text("EXPECT").font(.stencil(11)).foregroundStyle(Theme.dim)
                ForEach(content.catalog.zombies) { zombie in
                    Portrait(name: zombie.id, size: 34)
                    Text(zombie.name).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.text)
                }
            }
            Button { onPlay(0) } label: {
                Text("DEPLOY").frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityIdentifier("play-level")
        }
        .padding(16)
        .panel()
        .padding(.horizontal, 16)
        .frame(maxWidth: 480)
    }
}
