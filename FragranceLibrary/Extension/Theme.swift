import SwiftUI

// MARK: - Color Theme

extension Color {
    /// Warm off-white background (Light: #F8F6F2, Dark: #1C1C1E)
    static let perfumeBg = Color(light: Color(hex: 0xF8F6F2), dark: Color(hex: 0x1C1C1E))

    /// Card surface (Light: #FFFFFF, Dark: #2C2C2E)
    static let perfumeCard = Color(light: .white, dark: Color(hex: 0x2C2C2E))

    /// Primary text — deep charcoal (Light: #2D2D2B, Dark: #E5E5E0)
    static let perfumeText = Color(light: Color(hex: 0x2D2D2B), dark: Color(hex: 0xE5E5E0))

    /// Secondary text — muted warm gray
    static let perfumeTextSecondary = Color(light: Color(hex: 0x8E8E8A), dark: Color(hex: 0x999994))

    /// Amber-gold accent (#CC9900)
    static let perfumeAccent = Color(light: Color(hex: 0xCC9900), dark: Color(hex: 0xD4A520))

    /// Border / divider
    static let perfumeBorder = Color(light: Color(hex: 0xE8E6E0), dark: Color(hex: 0x38383A))

    /// Card shadow
    static let perfumeShadow = Color.black.opacity(0.08)

    /// Error / delete red
    static let perfumeDanger = Color(light: Color(hex: 0xD94841), dark: Color(hex: 0xE05550))
}

extension Color {
    init(hex: UInt) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }

    init(light: Color, dark: Color) {
        self.init(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }
}

// MARK: - Animation Presets

extension Animation {
    /// Card entrance spring — bouncy but not cartoonish
    static let cardEntrance = Animation.spring(duration: 0.5, bounce: 0.25)

    /// Button press spring — quick and tight
    static let buttonPress = Animation.spring(duration: 0.3, bounce: 0.15)

    /// Staggered list entrance
    static func cardStagger(index: Int, baseDelay: Double = 0.06) -> Animation {
        .spring(duration: 0.5, bounce: 0.25).delay(Double(index) * baseDelay)
    }

    /// Fade-in with slight lift
    static let fadeUp = Animation.spring(duration: 0.45, bounce: 0.2)

    /// Checkmark pop
    static let checkPop = Animation.spring(duration: 0.4, bounce: 0.5)

    /// Smooth progress
    static let smoothProgress = Animation.spring(duration: 0.6, bounce: 0.1)
}

// MARK: - Shape Constants

enum PerfumeLayout {
    /// Card aspect ratio (4:5 portrait)
    static let cardAspectRatio: CGFloat = 4.0 / 5.0

    /// Grid columns
    static let gridColumns = 2

    /// Grid spacing
    static let gridSpacing: CGFloat = 12

    /// Card corner radius
    static let cardCornerRadius: CGFloat = 16

    /// Image border width
    static let imageBorderWidth: CGFloat = 6

    /// Card horizontal padding
    static let cardHPadding: CGFloat = 16
}

// MARK: - Haptic Feedback

enum Haptic {
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func heavy() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
