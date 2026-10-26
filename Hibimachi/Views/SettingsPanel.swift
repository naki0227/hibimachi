import SwiftUI

/// "せってい": sound, music and vibration, the first-run guide again, and where the data lives.
struct SettingsPanel: View {
    @Bindable var settings: AppSettings
    let replayTutorial: () -> Void
    let close: () -> Void

    private static let supportURL = URL(string: "https://enludus.com/products/hibimachi")
    private static let privacyURL = URL(string: "https://enludus.com/products/hibimachi-privacy")

    var body: some View {
        GamePanel(title: "せってい", symbol: "gearshape.fill", identifier: "settings-panel", close: close) {
            VStack(spacing: 12) {
                VStack(spacing: 0) {
                    row("効果音", "speaker.wave.2.fill", $settings.soundEffects, "setting-effects")
                    divider
                    row("音楽", "music.note", $settings.music, "setting-music")
                    divider
                    row("ふるえる", "iphone.radiowaves.left.and.right", $settings.haptics, "setting-haptics")
                }
                .gameCard()
                Button {
                    replayTutorial()
                    close()
                } label: {
                    Label("最初の案内をもう一度見る", systemImage: "questionmark.bubble").frame(maxWidth: .infinity)
                }
                .buttonStyle(.game(.secondary))
                .accessibilityIdentifier("replay-tutorial")
                VStack(alignment: .leading, spacing: 8) {
                    Label("データはこの端末の中だけに保存されます。通信や登録はありません。", systemImage: "lock.fill")
                        .font(GameFont.body(13, weight: .medium))
                        .foregroundStyle(GameColor.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    if let url = Self.privacyURL {
                        Link(destination: url) { Label("プライバシーポリシー", systemImage: "hand.raised.fill") }
                    }
                    if let url = Self.supportURL {
                        Link(destination: url) { Label("サポート・お問い合わせ", systemImage: "envelope.fill") }
                    }
                }
                .font(GameFont.body(14, weight: .bold))
                .tint(GameColor.leafDark)
                .gameCard()
                Text(aboutText)
                    .font(GameFont.caption(11))
                    .foregroundStyle(GameColor.inkSoft)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var aboutText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "-"
        let build = info?["CFBundleVersion"] as? String ?? "-"
        return "ひびまち \(version) (\(build))\n絵と音はすべてコードで描いています。© 2026 enludus"
    }

    private var divider: some View {
        Rectangle().fill(GameColor.line).frame(height: 1.5).padding(.vertical, 4)
    }

    private func row(_ title: String, _ symbol: String, _ value: Binding<Bool>, _ id: String) -> some View {
        Toggle(isOn: value) {
            Label(title, systemImage: symbol)
                .font(GameFont.body(15, weight: .bold))
                .foregroundStyle(GameColor.ink)
        }
        .toggleStyle(GameToggleStyle())
        .accessibilityIdentifier(id)
    }
}

/// Pill switch in the game's colors (the system switch would bring default iOS chrome back).
struct GameToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack {
                configuration.label
                Spacer()
                Capsule()
                    .fill(configuration.isOn ? GameColor.leaf : GameColor.cream)
                    .overlay(Capsule().stroke(configuration.isOn ? GameColor.leafDark : GameColor.line, lineWidth: 2))
                    .frame(width: 52, height: 30)
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle().fill(.white).padding(4).shadow(color: GameColor.ink.opacity(0.2), radius: 1, y: 1)
                    }
                    .animation(.easeOut(duration: 0.15), value: configuration.isOn)
            }
            .contentShape(Rectangle())
            .frame(minHeight: 40)
        }
        .buttonStyle(.plain)
        .accessibilityValue(configuration.isOn ? "オン" : "オフ")
    }
}
