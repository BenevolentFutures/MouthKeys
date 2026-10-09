import AppKit
import SwiftUI

private struct ThemeKey: EnvironmentKey {
    static var defaultValue: AppTheme = .dark
}

extension EnvironmentValues {
    var theme: AppTheme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

extension View {
    /// Applies an app theme to the view hierarchy.
    func appTheme(_ theme: AppTheme) -> some View {
        environment(\.theme, theme)
    }
}

struct AdaptiveAppTheme<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var settings = SettingsStore.shared

    let accent: Color
    let content: Content

    init(accent: Color, @ViewBuilder content: () -> Content) {
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        let preferredScheme = self.settings.themePreference.preferredColorScheme
        let activeScheme = preferredScheme ?? self.colorScheme

        self.content
            .appTheme(AppTheme.adaptive(accent: self.accent, colorScheme: activeScheme))
            .preferredColorScheme(preferredScheme)
            .onAppear { AppAppearance.apply(self.settings.themePreference) }
            .onChange(of: self.settings.themePreference) { _, preference in
                AppAppearance.apply(preference)
            }
    }
}

/// The theme setting governs every MouthKeys surface, not only the main window: the overlay,
/// its cards and the menu follow it too, so Getting Started and the overlay it teaches match.
/// "System" leaves macOS in charge. The menu bar mark is a template image, drawn by macOS to
/// suit the menu bar either way.
enum AppAppearance {
    @MainActor
    static func apply(_ preference: SettingsStore.ThemePreference) {
        guard !TestHostQuietMode.isActive else { return }
        let appearance: NSAppearance? = switch preference {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
        guard NSApp.appearance?.name != appearance?.name else { return }
        NSApp.appearance = appearance
    }
}

// MARK: - Color Hex Initializer

extension Color {
    /// Initialize a Color from a hex string (e.g., "#FF5733" or "FF5733")
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        guard hexSanitized.count == 6 else { return nil }

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let red = Double((rgb & 0xff0000) >> 16) / 255.0
        let green = Double((rgb & 0x00ff00) >> 8) / 255.0
        let blue = Double(rgb & 0x0000ff) / 255.0

        self.init(red: red, green: green, blue: blue)
    }

    static var fluidGreen: Color {
        DatasheetTheme.Palette.dark.accent
    }
}
