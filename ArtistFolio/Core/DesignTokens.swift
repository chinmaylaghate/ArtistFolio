import SwiftUI

extension Color {
    static let afPrimary = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.29, green: 0.53, blue: 0.95, alpha: 1)
            : UIColor(red: 0.25, green: 0.45, blue: 0.83, alpha: 1)
    })

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
    func primaryAction() -> some View {
        buttonStyle(.borderedProminent)
            .controlSize(.large)
    }

    func secondaryAction() -> some View {
        buttonStyle(.bordered)
            .controlSize(.large)
    }
}
