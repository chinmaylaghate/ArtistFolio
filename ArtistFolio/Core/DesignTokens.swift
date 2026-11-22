// MARK: - ArtistFolio Design Tokens
// Exact values from Figma: oJ7E0vjToDdYgO74yU1vJi
import SwiftUI

// MARK: - Color Palette

extension Color {
    // Primary Brand — Figma: #3F73D3
    static let afPrimary       = Color(hex: "#3F73D3")
    static let afPrimaryLight  = Color(hex: "#3F73D3").opacity(0.08)

    // Backgrounds — Figma: white surfaces
    static let afBackground    = Color(hex: "#FFFFFF")
    static let afSurface       = Color(hex: "#FFFFFF")
    static let afSurface2      = Color(hex: "#F7F7F7")

    // Text — Figma: #313540 primary, #7C849B secondary
    static let afTextPrimary   = Color(hex: "#313540")
    static let afTextSecondary = Color(hex: "#7C849B")
    static let afTextTertiary  = Color(hex: "#A0A8BD")

    // Semantic — Figma exact
    static let afSuccess       = Color(hex: "#34C759")
    static let afError         = Color(hex: "#FF383C")
    static let afWarning       = Color(hex: "#FF8D28")
    static let afOrange        = Color(hex: "#FF8D28")
    static let afInfo          = Color(hex: "#3F73D3")

    // Tinted semantic backgrounds
    static let afSuccessBg     = Color(hex: "#34C759").opacity(0.08)
    static let afErrorBg       = Color(hex: "#FF383C").opacity(0.08)
    static let afOrangeBg      = Color(hex: "#FF8D28").opacity(0.08)
    static let afPrimaryBg     = Color(hex: "#3F73D3").opacity(0.08)

    // Borders — Figma: rgba(49,53,64,0.1)
    static let afBorder        = Color(hex: "#313540").opacity(0.10)
    static let afBorderLight   = Color(hex: "#313540").opacity(0.06)
    static let afDivider       = Color(hex: "#313540").opacity(0.10)

    // Legacy aliases
    static let afAccent         = Color.afPrimary
    static let afAvatarBg       = Color.afPrimary
    static let afAvatarBorder   = Color.afPrimary
    static let afArtistBadge    = Color.afPrimary
    static let afCollectorBadge = Color.afSuccess
    static let afActiveBadge    = Color.afSuccess

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}

// MARK: - Typography

struct AFFont {
    static let displayLarge  = Font.system(size: 34, weight: .bold)
    static let displayMedium = Font.system(size: 28, weight: .bold)
    static let displaySmall  = Font.system(size: 22, weight: .bold)

    static let headlineLarge  = Font.system(size: 17, weight: .semibold)
    static let headlineMedium = Font.system(size: 17, weight: .semibold)
    static let headlineSmall  = Font.system(size: 15, weight: .semibold)

    static let bodyLarge  = Font.system(size: 17, weight: .regular)
    static let bodyMedium = Font.system(size: 15, weight: .regular)
    static let bodySmall  = Font.system(size: 13, weight: .regular)

    static let caption     = Font.system(size: 12, weight: .regular)
    static let captionBold = Font.system(size: 12, weight: .semibold)

    static let labelLarge  = Font.system(size: 14, weight: .medium)
    static let labelMedium = Font.system(size: 13, weight: .medium)
    static let labelSmall  = Font.system(size: 11, weight: .medium)

    static let sectionHeader = Font.system(size: 12, weight: .semibold)

    static let price      = Font.system(size: 17, weight: .semibold)
    static let priceLarge = Font.system(size: 22, weight: .bold)

    static let statNumber = Font.system(size: 17, weight: .bold)
    static let statLabel  = Font.system(size: 12, weight: .regular)
}

// MARK: - Spacing

struct AFSpacing {
    static let xxs: CGFloat  = 4
    static let xs: CGFloat   = 8
    static let sm: CGFloat   = 12
    static let md: CGFloat   = 16
    static let lg: CGFloat   = 20
    static let xl: CGFloat   = 24
    static let xxl: CGFloat  = 32
    static let xxxl: CGFloat = 48
}

// MARK: - Corner Radius

struct AFRadius {
    static let xs: CGFloat   = 4
    static let sm: CGFloat   = 8
    static let md: CGFloat   = 12
    static let lg: CGFloat   = 16
    static let xl: CGFloat   = 20
    static let xxl: CGFloat  = 24
    static let full: CGFloat = 999
}

// MARK: - View Extensions

extension View {
    func afCardShadow() -> some View {
        self.shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1)
    }
    func afElevatedShadow() -> some View {
        self.shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
    }
    /// Figma: 0 8px 40px rgba(0,0,0,0.12)
    func afTabBarShadow() -> some View {
        self.shadow(color: Color.black.opacity(0.12), radius: 20, x: 0, y: 8)
    }
    func afGlassShadow() -> some View {
        self.shadow(color: Color.black.opacity(0.12), radius: 20, x: 0, y: 8)
    }

    /// Apply frosted glass style to NavigationBar
    func afGlassNavBar() -> some View {
        self
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
    }
}

// MARK: - Gradients

struct AFGradient {
    static let primaryBlue = LinearGradient(
        colors: [Color(hex: "#3F73D3"), Color(hex: "#2F5FBF")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let avatarBorder = LinearGradient(
        colors: [Color(hex: "#3F73D3"), Color(hex: "#5B8FE8")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let landingOverlay = LinearGradient(
        colors: [Color.clear, Color.black.opacity(0.6), Color.black.opacity(0.9)],
        startPoint: .top, endPoint: .bottom
    )
    // Legacy alias
    static let primaryGold = primaryBlue
    static let artworkCard = LinearGradient(
        colors: [Color.clear, Color.black.opacity(0.5)],
        startPoint: .center, endPoint: .bottom
    )
    static let statBlue = LinearGradient(
        colors: [Color(hex: "#3F73D3").opacity(0.08), Color(hex: "#3F73D3").opacity(0.04)],
        startPoint: .top, endPoint: .bottom
    )
    static let statGreen = LinearGradient(
        colors: [Color(hex: "#34C759").opacity(0.08), Color(hex: "#34C759").opacity(0.04)],
        startPoint: .top, endPoint: .bottom
    )
    static let statOrange = LinearGradient(
        colors: [Color(hex: "#FF8D28").opacity(0.08), Color(hex: "#FF8D28").opacity(0.04)],
        startPoint: .top, endPoint: .bottom
    )
}

// MARK: - Button Styles

struct AFPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AFFont.headlineMedium)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color.afPrimary)
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

struct AFSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AFFont.headlineMedium)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color.white.opacity(0.12))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.30), lineWidth: 1.5))
            .opacity(configuration.isPressed ? 0.85 : 1.0)
    }
}

struct AFOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AFFont.headlineSmall)
            .foregroundColor(.afPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color.afSurface)
            .clipShape(RoundedRectangle(cornerRadius: AFRadius.md))
            .overlay(RoundedRectangle(cornerRadius: AFRadius.md).stroke(Color.afBorder, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.85 : 1.0)
    }
}

// MARK: - Glass Pill Modifier
// Replicates Figma "GlassPill": rgba(255,255,255,0.65) + blur + shadow

struct GlassPillModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: Capsule())
            .afGlassShadow()
    }
}

extension View {
    func glassPill() -> some View {
        modifier(GlassPillModifier())
    }
}
