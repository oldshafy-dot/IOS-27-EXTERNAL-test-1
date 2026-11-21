import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var language
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.english.rawValue
    @AppStorage(AppTheme.redKey) private var red = AppTheme.defaultChannel
    @AppStorage(AppTheme.greenKey) private var green = AppTheme.defaultChannel
    @AppStorage(AppTheme.blueKey) private var blue = AppTheme.defaultChannel
    @AppStorage(AppTheme.rainbowKey) private var rainbowEnabled = false

    private let discordURL = URL(string: "https://discord.gg/VqkjH4pJv")!

    var body: some View {
        NavigationStack {
            Form {
                Section(language.text("settings.appearance")) {
                    Toggle(isOn: $rainbowEnabled) {
                        Label(language.text("settings.rainbow"), systemImage: "rainbow")
                    }
                    .tint(AppTheme.accent)

                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(AppTheme.accent)
                            .frame(width: 42, height: 28)
                        Text(language.text(rainbowEnabled ? "settings.rainbow_active" : "settings.accent_color"))
                            .foregroundStyle(.primary)
                        Spacer()
                    }

                    rgbRow(title: "R", value: $red, color: .red)
                    rgbRow(title: "G", value: $green, color: .green)
                    rgbRow(title: "B", value: $blue, color: .blue)

                    Button(language.text("settings.reset_color")) {
                        red = AppTheme.defaultChannel
                        green = AppTheme.defaultChannel
                        blue = AppTheme.defaultChannel
                        rainbowEnabled = false
                    }
                }

                Section(language.text("settings.language")) {
                    Picker(language.text("settings.language"), selection: $languageCode) {
                        ForEach(AppLanguage.allCases) { option in
                            Text(option.displayName).tag(option.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section(language.text("settings.support")) {
                    Link(destination: discordURL) {
                        HStack(spacing: 12) {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .foregroundStyle(AppTheme.accent)
                                .frame(width: 30, height: 30)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Discord")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("discord.gg/VqkjH4pJv")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundStyle(AppTheme.accent)
                        }
                    }
                    .accessibilityLabel(language.text("settings.open_support"))
                }
            }
            .tint(AppTheme.accent)
            .scrollContentBackground(.hidden)
            .background(AppTheme.pageBackground)
            .navigationTitle(language.text("settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(language.text("common.done")) { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func rgbRow(title: String, value: Binding<Double>, color: Color) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.headline.monospaced())
                .foregroundStyle(color)
                .frame(width: 24)
            Slider(value: value, in: 0...255, step: 1)
                .tint(color)
            Text("\(Int(value.wrappedValue))")
                .font(.caption.monospacedDigit())
                .frame(width: 32, alignment: .trailing)
        }
        .disabled(rainbowEnabled)
        .opacity(rainbowEnabled ? 0.45 : 1)
    }
}
