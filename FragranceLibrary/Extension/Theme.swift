import SwiftUI

// MARK: - Color Theme

extension Color {
    /// Warm washi-paper background.
    static let perfumeBg = Color(light: Color(hex: 0xF4F0E8), dark: Color(hex: 0x151412))

    /// Porcelain card surface.
    static let perfumeCard = Color(light: Color(hex: 0xFBFAF6), dark: Color(hex: 0x22201D))

    /// Primary text — ink black.
    static let perfumeText = Color(light: Color(hex: 0x1E1C18), dark: Color(hex: 0xE9E4D8))

    /// Secondary text — warm stone gray.
    static let perfumeTextSecondary = Color(light: Color(hex: 0x756E63), dark: Color(hex: 0xA9A196))

    /// Muted brass accent.
    static let perfumeAccent = Color(light: Color(hex: 0x9D7A3A), dark: Color(hex: 0xC9A867))

    /// Soft blush highlight for a feminine editorial warmth.
    static let perfumeBlush = Color(light: Color(hex: 0xE8D7CA), dark: Color(hex: 0x5B4840))

    /// Warm ivory highlight.
    static let perfumeIvory = Color(light: Color(hex: 0xFFFDF7), dark: Color(hex: 0x2A2722))

    /// Border / divider
    static let perfumeBorder = Color(light: Color(hex: 0xD8D0C2), dark: Color(hex: 0x38352F))

    /// Card shadow
    static let perfumeShadow = Color.black.opacity(0.06)

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

    /// Premium gallery open/close spring.
    static let galleryBloom = Animation.spring(response: 0.55, dampingFraction: 0.82)

    /// Soft editorial reveal.
    static let editorialReveal = Animation.easeOut(duration: 0.55)

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

enum PerfumeType {
    static func label(_ size: CGFloat = 11) -> Font {
        .custom("Avenir Next", size: size).weight(.semibold)
    }

    static func title(_ size: CGFloat = 24) -> Font {
        .custom("Avenir Next", size: size).weight(.medium)
    }

    static func body(_ size: CGFloat = 14) -> Font {
        .custom("Avenir Next", size: size).weight(.regular)
    }

    static func bodyMedium(_ size: CGFloat = 14) -> Font {
        .custom("Avenir Next", size: size).weight(.medium)
    }

    static func display(size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .custom("Avenir Next", size: size).weight(weight)
    }
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

// MARK: - Premium Surfaces

struct PerfumePaperBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: 0xFBF7EF),
                    Color.perfumeBg,
                    Color(hex: 0xEFE5D8)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.perfumeBlush.opacity(0.28))
                .frame(width: 260, height: 260)
                .blur(radius: 72)
                .offset(x: -130, y: -210)

            Circle()
                .fill(Color.perfumeAccent.opacity(0.11))
                .frame(width: 240, height: 240)
                .blur(radius: 70)
                .offset(x: 150, y: 240)
        }
        .ignoresSafeArea()
    }
}

struct PremiumPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                LinearGradient(
                    colors: [
                        Color.perfumeText,
                        Color(hex: 0x3D352C)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .opacity(configuration.isPressed ? 0.86 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.buttonPress, value: configuration.isPressed)
    }
}

struct PremiumSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.perfumeText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Color.perfumeIvory.opacity(configuration.isPressed ? 0.70 : 0.95))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.perfumeText.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: Color.perfumeShadow, radius: 3, y: 1)
            .animation(.buttonPress, value: configuration.isPressed)
    }
}
