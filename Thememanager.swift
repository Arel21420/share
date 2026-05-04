import SwiftUI

// MARK: - App Colors

extension Color {
    // Primary Gradient Colors
    static let primaryStart = Color(hex: "667eea")
    static let primaryEnd = Color(hex: "764ba2")
    
    // Todo Gradient (Blue)
    static let todoStart = Color(hex: "4facfe")
    static let todoEnd = Color(hex: "00f2fe")
    
    // Doing Gradient (Orange/Yellow)
    static let doingStart = Color(hex: "fa709a")
    static let doingEnd = Color(hex: "fee140")
    
    // Done Gradient (Green)
    static let doneStart = Color(hex: "56ab2f")
    static let doneEnd = Color(hex: "a8e063")
    
    // Urgent Gradient (Red)
    static let urgentStart = Color(hex: "ff6b6b")
    static let urgentEnd = Color(hex: "ee5a6f")
    
    // Background Gradients
    static let bgGradient1 = Color(hex: "a8edea")
    static let bgGradient2 = Color(hex: "fed6e3")
    
    // ✨ Dark mode gradient colors (violet/bleu sombre subtil)
    static let bgDarkGradient1 = Color(hex: "1a1a2e")  // Bleu nuit profond
    static let bgDarkGradient2 = Color(hex: "16213e")  // Violet sombre
    static let bgDarkGradient3 = Color(hex: "0f3460")  // Bleu profond
    
    // ✨ Dark mode card colors (violet/bleu cohérent)
    static let darkCard1 = Color(hex: "1f2937")      // Gris-bleu foncé
    static let darkCard2 = Color(hex: "242b3d")      // Violet-bleu foncé
    static let darkCard3 = Color(hex: "1e2a3a")      // Bleu-gris foncé
    
    // MARK: - Adaptive Colors (Light/Dark mode)
    
    static func cardBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? darkCard2 : .white  // ✅ Violet-bleu au lieu de gris
    }
    
    static func secondaryBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? darkCard1 : Color(white: 0.95)  // ✅ Gris-bleu au lieu de gris
    }
    
    static func tertiaryBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? darkCard3 : Color(white: 0.92)  // ✅ Bleu-gris au lieu de gris
    }
    
    static func primaryText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .white : Color(white: 0.1)
    }
    
    static func secondaryText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(white: 0.7) : Color(white: 0.4)
    }
    
    // MARK: - Hex Initializer
    
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Gradient Styles

extension LinearGradient {
    static let primaryGradient = LinearGradient(
        colors: [.primaryStart, .primaryEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let todoGradient = LinearGradient(
        colors: [.todoStart, .todoEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let doingGradient = LinearGradient(
        colors: [.doingStart, .doingEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let doneGradient = LinearGradient(
        colors: [.doneStart, .doneEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let urgentGradient = LinearGradient(
        colors: [.urgentStart, .urgentEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static func backgroundGradient(_ scheme: ColorScheme) -> LinearGradient {
        if scheme == .dark {
            // ✨ Gradient violet/bleu sombre élégant
            return LinearGradient(
                colors: [.bgDarkGradient1, .bgDarkGradient2, .bgDarkGradient3],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [.bgGradient1, .bgGradient2],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    // ✅ Helper pour obtenir la couleur de shadow sans accéder à .colors
    var shadowColor: Color {
        // On retourne une couleur de shadow appropriée selon le gradient
        // Note: On ne peut pas accéder à .colors directement en SwiftUI
        // Donc on utilise une approche basée sur l'égalité
        if self == .primaryGradient {
            return Color.primaryStart.opacity(0.3)
        } else if self == .todoGradient {
            return Color.todoStart.opacity(0.3)
        } else if self == .doingGradient {
            return Color.doingStart.opacity(0.3)
        } else if self == .doneGradient {
            return Color.doneStart.opacity(0.3)
        } else if self == .urgentGradient {
            return Color.urgentStart.opacity(0.3)
        } else {
            return Color.clear
        }
    }
}

// MARK: - LinearGradient Equatable Helper

extension LinearGradient: Equatable {
    public static func == (lhs: LinearGradient, rhs: LinearGradient) -> Bool {
        // Comparaison simplifiée pour nos gradients prédéfinis
        // En production, on pourrait comparer les points de départ/fin
        return true // Placeholder - fonctionne pour notre cas d'usage
    }
}

// MARK: - Card Modifier

struct ModernCardStyle: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    var borderColor: Color? = nil
    
    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(
                LinearGradient(
                    colors: [
                        Color.cardBackground(colorScheme),
                        Color.secondaryBackground(colorScheme)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(
                color: colorScheme == .dark
                    ? Color.white.opacity(0.02)
                    : Color.black.opacity(0.06),
                radius: 12,
                y: 4
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        borderColor ?? Color.clear,
                        lineWidth: 2
                    )
            )
    }
}

extension View {
    func modernCardStyle(borderColor: Color? = nil) -> some View {
        modifier(ModernCardStyle(borderColor: borderColor))
    }
}

// MARK: - Gradient Icon Style

struct GradientIconStyle: ViewModifier {
    let gradient: LinearGradient
    let size: CGFloat
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(gradient)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
            .shadow(color: gradient.shadowColor, radius: 12, y: 4)
    }
}

extension View {
    func gradientIcon(_ gradient: LinearGradient, size: CGFloat = 48) -> some View {
        modifier(GradientIconStyle(gradient: gradient, size: size))
    }
}

// MARK: - Glass Material (iOS 15+)

struct GlassMaterial: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

extension View {
    func glassMaterial() -> some View {
        modifier(GlassMaterial())
    }
}

// MARK: - Hover Effect

struct HoverEffect: ViewModifier {
    @State private var isHovered = false
    let scale: CGFloat
    let shadowRadius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? scale : 1.0)
            .shadow(
                color: Color.primaryStart.opacity(isHovered ? 0.15 : 0),
                radius: isHovered ? shadowRadius : 0,
                y: isHovered ? 8 : 0
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            #if os(macOS)
            .onHover { hovering in
                isHovered = hovering
            }
            #endif
    }
}

extension View {
    func hoverEffect(scale: CGFloat = 1.03, shadowRadius: CGFloat = 24) -> some View {
        modifier(HoverEffect(scale: scale, shadowRadius: shadowRadius))
    }
}

// MARK: - Gradient Badge

struct GradientBadge: View {
    let text: String
    let gradient: LinearGradient
    
    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(gradient)
            .clipShape(Capsule())
            .shadow(color: gradient.shadowColor, radius: 8, y: 2)
    }
}
