import SwiftUI

/// The game's own UI kit (no system sheets, lists, alerts or bordered buttons): warm paper panels, a leaf-green
/// accent and chunky "pressable" buttons, matching the island art rather than default iOS chrome.
enum GameColor {
    static let paper = Color(red: 1.0, green: 0.992, blue: 0.965)
    static let cream = Color(red: 0.973, green: 0.953, blue: 0.902)
    static let line = Color(red: 0.906, green: 0.863, blue: 0.773)
    static let ink = Color(red: 0.227, green: 0.196, blue: 0.149)
    static let inkSoft = Color(red: 0.471, green: 0.420, blue: 0.345)
    static let leaf = Color(red: 0.427, green: 0.710, blue: 0.357)
    static let leafDark = Color(red: 0.306, green: 0.561, blue: 0.255)
    static let leafPale = Color(red: 0.886, green: 0.949, blue: 0.851)
    static let sky = Color(red: 0.475, green: 0.741, blue: 0.835)
    static let sun = Color(red: 0.969, green: 0.784, blue: 0.333)
    static let apricot = Color(red: 0.929, green: 0.678, blue: 0.580)
    static let berry = Color(red: 0.851, green: 0.392, blue: 0.333)
    static let berryDark = Color(red: 0.663, green: 0.282, blue: 0.239)
    static let wood = Color(red: 0.753, green: 0.541, blue: 0.388)
}

enum GameFont {
    static func title(_ size: CGFloat = 22) -> Font { .system(size: size, weight: .heavy, design: .rounded) }
    static func body(_ size: CGFloat = 16, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    static func caption(_ size: CGFloat = 12) -> Font { .system(size: size, weight: .medium, design: .rounded) }
}

/// Chunky button with a darker "base" that the face sinks into when pressed.
struct GameButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
        case danger
    }

    var kind: Kind = .primary
    var compact = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let (face, base, text): (Color, Color, Color) =
            switch kind {
            case .primary: (GameColor.leaf, GameColor.leafDark, .white)
            case .secondary: (GameColor.paper, GameColor.line, GameColor.ink)
            case .danger: (GameColor.berry, GameColor.berryDark, .white)
            }
        let depth: CGFloat = configuration.isPressed ? 0 : 3
        return configuration.label
            .font(GameFont.body(compact ? 13 : 16, weight: .bold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(text)
            .padding(.horizontal, compact ? 12 : 18)
            .frame(minHeight: compact ? 36 : 46)
            .background(face, in: Capsule())
            .overlay(Capsule().stroke(base, lineWidth: 2))
            .background(base, in: Capsule().offset(y: depth))
            .offset(y: 3 - depth)
            .padding(.bottom, 3)
            .opacity(isEnabled ? 1 : 0.45)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == GameButtonStyle {
    static var game: GameButtonStyle { GameButtonStyle() }
    static func game(_ kind: GameButtonStyle.Kind, compact: Bool = false) -> GameButtonStyle {
        GameButtonStyle(kind: kind, compact: compact)
    }
}

extension EnvironmentValues {
    /// Height a panel may use, set by `ModalLayer` from the space above the keyboard.
    @Entry var gamePanelMaxHeight: CGFloat = 640
}

/// Floating paper panel with a title band and a round close button. The body scrolls only when it is taller
/// than the room the modal layer gives it, so short panels (menus, small lists) stay compact.
struct GamePanel<Content: View>: View {
    let title: String
    let symbol: String
    var identifier = ""
    var scrolls = true
    let close: () -> Void
    @ViewBuilder let content: () -> Content
    @Environment(\.gamePanelMaxHeight) private var maxHeight
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(GameColor.line).frame(height: 2).padding(.horizontal, 12)
            if scrolls {
                ScrollView {
                    content()
                        .padding(16)
                        .onGeometryChange(for: CGFloat.self) {
                            $0.size.height
                        } action: {
                            contentHeight = $0
                        }
                }
                .scrollBounceBehavior(.basedOnSize)
                // 72 = title band; keeps at least a few rows visible even above the keyboard.
                .frame(height: min(contentHeight, max(160, maxHeight - 72)))
            } else {
                content().padding(16)
            }
        }
        .background(GameColor.paper, in: RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(GameColor.line, lineWidth: 3))
        .shadow(color: GameColor.ink.opacity(0.25), radius: 18, y: 8)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityIdentifier(identifier)
        .accessibilityAction(.escape, close)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(GameColor.leaf, in: Circle())
            Text(title).font(GameFont.title()).foregroundStyle(GameColor.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(GameColor.inkSoft)
                    .frame(width: 40, height: 40)
                    .background(GameColor.cream, in: Circle())
                    .overlay(Circle().stroke(GameColor.line, lineWidth: 2))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("閉じる")
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }
}

/// Row/card surface used inside panels.
struct GameCard: ViewModifier {
    var highlighted = false

    func body(content: Content) -> some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(highlighted ? GameColor.leafPale : .white, in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(highlighted ? GameColor.leaf.opacity(0.5) : GameColor.line, lineWidth: 2))
    }
}

extension View {
    func gameCard(highlighted: Bool = false) -> some View { modifier(GameCard(highlighted: highlighted)) }

    /// Section label inside panels.
    func gameSectionTitle() -> some View {
        font(GameFont.body(14, weight: .heavy)).foregroundStyle(GameColor.inkSoft)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Paper card shared by the bottom panels, drawn like the modal panels (no system material).
struct GameBarBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(10)
            .background(GameColor.paper, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(GameColor.line, lineWidth: 3))
            .shadow(color: GameColor.ink.opacity(0.2), radius: 8, y: 3)
    }
}

/// Small rounded tile used by palette cards and icon buttons inside the bottom panels.
struct GameTileBackground: ViewModifier {
    var radius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .background(.white, in: RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(GameColor.line, lineWidth: 2))
    }
}

extension View {
    /// Bottom bars (palette, edit and selection bars).
    func gameBar() -> some View { modifier(GameBarBackground()) }
    func gameTile(radius: CGFloat = 16) -> some View { modifier(GameTileBackground(radius: radius)) }
}

/// Text field drawn like the rest of the UI (paper with a soft outline). Text, placeholder and cursor use the
/// game's ink colors explicitly: system defaults turn white in Dark Mode on this always-light paper.
struct GameTextField: View {
    let placeholder: String
    @Binding var text: String
    /// Multi-line fields grow between these line counts; `nil` keeps a single line.
    var lines: ClosedRange<Int>?

    var body: some View {
        field
            .font(GameFont.body(16, weight: .medium))
            .foregroundStyle(GameColor.ink)
            .tint(GameColor.leafDark)
            .padding(.horizontal, 14)
            .padding(.vertical, lines == nil ? 0 : 12)
            .frame(minHeight: 46)
            .background(GameColor.cream, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(GameColor.line, lineWidth: 2))
            .accessibilityLabel(placeholder)
    }

    @ViewBuilder
    private var field: some View {
        let prompt = Text(placeholder).foregroundStyle(GameColor.inkSoft.opacity(0.7))
        if let lines {
            TextField("", text: $text, prompt: prompt, axis: .vertical).lineLimit(lines)
        } else {
            TextField("", text: $text, prompt: prompt)
        }
    }
}
