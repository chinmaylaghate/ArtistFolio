import SwiftUI

extension Color {
    // Ultramarine: the dark variant is lighter and pairs with black text to keep contrast.
    static let afPrimary = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x8B / 255, green: 0x7F / 255, blue: 1, alpha: 1)
            : UIColor(red: 0x3B / 255, green: 0x2B / 255, blue: 0xF0 / 255, alpha: 1)
    })
    static let afOnPrimary = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? .black : .white })

    init(hex: String) {
        let digits = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: digits).scanHexInt64(&value)
        self.init(.sRGB,
                  red: Double(value >> 16 & 0xFF) / 255,
                  green: Double(value >> 8 & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255)
    }
}

struct AFSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

struct AFRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 20
}

extension View {
    @ViewBuilder
    func afGlass<S: Shape>(in shape: S, tint: Color? = nil, interactive: Bool = false) -> some View {
        if #available(iOS 26, *) {
            glassEffect(Glass.regular.tint(tint).interactive(interactive), in: shape)
        } else {
            background(tint ?? Color.clear, in: shape)
                .background(.regularMaterial, in: shape)
        }
    }

    @ViewBuilder
    func afGlassGroup(spacing: CGFloat = AFSpacing.xs) -> some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: spacing) { self }
        } else {
            self
        }
    }

    @ViewBuilder
    func afGlassButton() -> some View {
        if #available(iOS 26, *) {
            buttonStyle(.glass)
        } else {
            buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    func afGlassProminentButton() -> some View {
        if #available(iOS 26, *) {
            buttonStyle(.glassProminent)
                .foregroundStyle(Color.afOnPrimary)
        } else {
            buttonStyle(.borderedProminent)
                .foregroundStyle(Color.afOnPrimary)
        }
    }

    @ViewBuilder
    func afBottomBar<Bar: View>(@ViewBuilder content: () -> Bar) -> some View {
        if #available(iOS 26, *) {
            safeAreaBar(edge: .bottom, content: content)
        } else {
            safeAreaInset(edge: .bottom) { content().background(.bar) }
        }
    }

    func primaryAction() -> some View {
        afGlassProminentButton().controlSize(.large)
    }

    func secondaryAction() -> some View {
        afGlassButton().controlSize(.large)
    }
}
