import SwiftUI
import UIKit

/// Colors and type: muted military tones, with the zombies' sickly green
/// kept for the zombies themselves.
enum Theme {
    static let background = Color(red: 0.10, green: 0.11, blue: 0.08)
    static let panel = Color(red: 0.15, green: 0.17, blue: 0.12)
    static let panelRaised = Color(red: 0.20, green: 0.22, blue: 0.16)
    static let edge = Color(red: 0.34, green: 0.37, blue: 0.25)
    static let sand = Color(red: 0.86, green: 0.78, blue: 0.58)
    static let olive = Color(red: 0.45, green: 0.52, blue: 0.27)
    static let text = Color(red: 0.94, green: 0.91, blue: 0.83)
    static let dim = Color(red: 0.66, green: 0.65, blue: 0.56)
    static let alert = Color(red: 0.84, green: 0.36, blue: 0.25)
    static let good = Color(red: 0.56, green: 0.74, blue: 0.36)

    /// Around the map where the screen is wider than the map: dark scrub.
    static let mapSurround = Color(red: 0.13, green: 0.15, blue: 0.10)
    static let mapEdgeUI = UIColor(red: 0.08, green: 0.09, blue: 0.06, alpha: 1)
    static let sandUI = UIColor(red: 0.86, green: 0.78, blue: 0.58, alpha: 1)
    static let healthUI = UIColor(red: 0.86, green: 0.30, blue: 0.22, alpha: 1)
}

extension Font {
    /// Heavy condensed capitals, like stenciled crates.
    static func stencil(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy).width(.condensed)
    }

    static func readout(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .monospaced)
    }
}

/// A dark panel with a thin olive edge.
struct PanelBackground: ViewModifier {
    var raised = false
    func body(content: Content) -> some View {
        content
            .background(raised ? Theme.panelRaised : Theme.panel, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.edge.opacity(0.7), lineWidth: 1))
    }
}

extension View {
    func panel(raised: Bool = false) -> some View { modifier(PanelBackground(raised: raised)) }
}

/// The sand-colored main action button.
struct PrimaryButtonStyle: ButtonStyle {
    var color = Theme.sand
    var height: CGFloat = 46
    /// Side padding; smaller for buttons that carry a few words.
    var inset: CGFloat = 16
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.stencil(17))
            .tracking(1)
            .foregroundStyle(Theme.background)
            .padding(.horizontal, inset)
            .frame(minHeight: height)
            .background(color.opacity(configuration.isPressed ? 0.75 : 1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// A darker square button for pause, speed and menus.
struct IconButtonStyle: ButtonStyle {
    var height: CGFloat = 46
    /// Lit sand-coloured while its setting is on (paused, or sped up).
    var lit = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.stencil(16))
            .foregroundStyle(lit ? Theme.background : Theme.text)
            .frame(minWidth: height, minHeight: height)
            .background((lit ? Theme.sand : Theme.panelRaised).opacity(configuration.isPressed ? 0.6 : 1),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.edge.opacity(0.7), lineWidth: 1))
    }
}

/// A small supply amount with its icon.
struct SupplyLabel: View {
    let amount: Int
    var size: CGFloat = 16
    var body: some View {
        HStack(spacing: 4) {
            Image("badge_supply").resizable().scaledToFit().frame(width: size + 4, height: size + 4)
            Text("\(amount)").font(.readout(size)).foregroundStyle(Theme.sand).monospacedDigit()
                .fixedSize()
        }
    }
}
