import SwiftUI

enum AppTheme {
    static let redKey = "appAccentRed"
    static let greenKey = "appAccentGreen"
    static let blueKey = "appAccentBlue"
    static let rainbowKey = "appRainbowEnabled"
    static let defaultChannel = 255.0
    static var rainbowHue = 0.0

    private static func channel(_ key: String, fallback: Double) -> Double {
        let value = UserDefaults.standard.object(forKey: key) as? Double ?? fallback
        return min(255, max(0, value)) / 255
    }

    private static var accentRGB: (Double, Double, Double) {
        if UserDefaults.standard.bool(forKey: rainbowKey) {
            let hue = rainbowHue * 6
            let sector = Int(hue) % 6
            let fraction = hue - floor(hue)
            let q = 1 - fraction
            switch sector {
            case 0: return (1, fraction, 0)
            case 1: return (q, 1, 0)
            case 2: return (0, 1, fraction)
            case 3: return (0, q, 1)
            case 4: return (fraction, 0, 1)
            default: return (1, 0, q)
            }
        }
        return (
            channel(redKey, fallback: defaultChannel),
            channel(greenKey, fallback: defaultChannel),
            channel(blueKey, fallback: defaultChannel)
        )
    }

    static var accent: Color {
        let c = accentRGB
        return Color(red: c.0, green: c.1, blue: c.2)
    }
    static var secondaryAccent: Color {
        let c = accentRGB
        return Color(red: min(1, c.0 * 0.78 + 0.22), green: min(1, c.1 * 0.78 + 0.22), blue: min(1, c.2 * 0.78 + 0.22))
    }
    static var pageBackground: Color {
        let c = accentRGB
        return Color(red: c.0 * 0.012, green: c.1 * 0.012, blue: c.2 * 0.012)
    }
    static var consoleBackground: Color {
        let c = accentRGB
        return Color(red: c.0 * 0.025, green: c.1 * 0.025, blue: c.2 * 0.025)
    }
    static var referenceCard: Color {
        let c = accentRGB
        return Color(red: c.0 * 0.07, green: c.1 * 0.07, blue: c.2 * 0.07)
    }
    static let paper = Color(red: 0.94, green: 0.97, blue: 1.00)
    static let ink = Color(red: 0.015, green: 0.035, blue: 0.10)
    static let pageInset: CGFloat = 16
    static let rowIconSize: CGFloat = 17
    static let rowIconFrame: CGFloat = 28
    static let fileRowIconSize: CGFloat = 17
    static let fileRowIconFrame: CGFloat = 30
    static let fileRowHeight: CGFloat = 60
    static let appIconSize: CGFloat = 32
    static let emptyIconSize: CGFloat = 30
    static let selectionIconSize: CGFloat = 18
}

struct AppRowIcon: View {
    let systemName: String
    var tint: Color = AppTheme.accent
    var symbolSize: CGFloat = AppTheme.rowIconSize
    var frameSize: CGFloat = AppTheme.rowIconFrame

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(tint.opacity(0.12))
            Image(systemName: systemName)
                .font(.system(size: symbolSize, weight: .medium))
                .foregroundStyle(tint)
        }
        .frame(width: frameSize, height: frameSize)
        .accessibilityHidden(true)
    }
}

struct AppSearchField: View {
    @Binding var text: String
    let prompt: String
    let clearLabel: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            TextField(prompt, text: $text)
                .font(.body)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(clearLabel)
            }
        }
        .padding(.horizontal, 11)
        .frame(minHeight: 36)
        .background(
            Color(uiColor: .secondarySystemFill),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .padding(.horizontal, AppTheme.pageInset)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

struct AppLogo: View {
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let icon = UIImage(named: "SAKKExternalLogo")
                ?? UIImage(named: "SAKKExternalLogo")
                ?? UIImage(named: "AppIcon60x60")
                ?? Bundle.main.path(forResource: "AppIcon60x60@2x", ofType: "png").flatMap(UIImage.init(contentsOfFile:))
                ?? UIImage(named: "AppIcon") {
                Image(uiImage: icon)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "slider.horizontal.3")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.pageBackground)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        .accessibilityHidden(true)
    }
}
