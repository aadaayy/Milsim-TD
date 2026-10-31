import SwiftUI
import UIKit

@main
struct LastPerimeterApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-openDuoPreview") {
                OpenDuoPreview()
            } else {
                RootView()
            }
            #else
            RootView()
            #endif
        }
    }
}

/// Portrait only on ordinary iPhones, as the design asks (one-handed play).
/// The open iPhone Duo's screen is nearly square, so there the game turns
/// with the phone and picks its layout from the shape it's given.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        if ProcessInfo.processInfo.arguments.contains("-openDuoPreview") { return .landscape }
        if let bounds = window?.windowScene?.screen.bounds {
            let long = max(bounds.width, bounds.height), short = max(min(bounds.width, bounds.height), 1)
            if long / short < 1.7 { return .all }
        }
        return .portrait
    }
}
