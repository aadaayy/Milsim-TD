#if DEBUG
import SwiftUI

/// The game drawn at the size of the open iPhone Duo's screen, shrunk to fit
/// whatever simulator runs it. The automatic checks can't unfold the Duo
/// simulator, so they screenshot this to show the open layout.
///
/// The size, about 951 by 669 points, comes from a screenshot taken on an
/// open Duo. Shown only when the app is launched with -openDuoPreview.
struct OpenDuoPreview: View {
    static let openScreen = CGSize(width: 951, height: 669)

    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width / Self.openScreen.width, geometry.size.height / Self.openScreen.height)
            RootView()
                .padding(.top, 24)
                .frame(width: Self.openScreen.width, height: Self.openScreen.height)
                .background(Theme.background)
                .environment(\.horizontalSizeClass, .regular)
                .environment(\.verticalSizeClass, .regular)
                .scaleEffect(scale)
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(Color.black)
        .ignoresSafeArea()
    }
}
#endif
