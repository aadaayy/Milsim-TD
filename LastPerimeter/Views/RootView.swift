import SwiftUI

/// The menu, or the level being played.
struct RootView: View {
    @State private var session: GameSession?
    private let content = GameContent.shared

    var body: some View {
        Group {
            if let session {
                GameScreen(session: session, onRetry: { start(session.levelIndex) }, onMenu: { self.session = nil })
                    .id(ObjectIdentifier(session))
            } else {
                MenuView(content: content, onPlay: start)
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(session != nil)
        .onAppear(perform: startFromLaunchArguments)
    }

    private func start(_ level: Int) {
        session = GameSession(content: content, levelIndex: level)
    }

    /// The automatic checks can open straight into a level ("-play", or any of
    /// the setups GameSession.applyLaunchArguments reads).
    private func startFromLaunchArguments() {
        let arguments = ProcessInfo.processInfo.arguments
        guard session == nil, arguments.contains("-uiTesting"),
              ["-play", "-demo", "-startWave", "-endScreen"].contains(where: { arguments.contains($0) }) else { return }
        let new = GameSession(content: content, levelIndex: 0)
        new.applyLaunchArguments(arguments)
        session = new
    }
}
