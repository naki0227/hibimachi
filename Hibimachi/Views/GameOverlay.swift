import HibimachiCore
import SwiftUI

/// Everything that floats above the island. One at a time, so there is never a stack of system sheets.
enum IslandOverlay: Hashable {
    case menu
    case quests
    case fieldGuide
    case objectList
    case album
    case settings
    /// The day a selected object was placed.
    case memory(UUID)
    case resetConfirm
    case startupNotice
    /// A picture of the island (no personal data) to share.
    case share
    /// Debug builds only: the home-screen widget with live data.
    case widgetPreview
}

/// Dimmed backdrop (tap to close) plus the panel sliding up from the bottom. Replaces `.sheet` / `.alert`.
struct ModalLayer<Item: Hashable, Content: View>: View {
    @Binding var item: Item?
    @ViewBuilder let content: (Item) -> Content

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                if item != nil {
                    GameColor.ink.opacity(0.38)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture { item = nil }
                        .accessibilityHidden(true)
                        .transition(.opacity)
                }
                if let item {
                    content(item)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                        .frame(maxWidth: 560)
                        .environment(\.gamePanelMaxHeight, proxy.size.height * 0.86)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .id(item)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        // Never swallow touches meant for the island while nothing is shown.
        .allowsHitTesting(item != nil)
        .animation(.spring(duration: 0.32, bounce: 0.18), value: item)
    }
}

/// Small centered dialog: a big round icon, a title, a message and the game's buttons.
struct GameDialog<Actions: View>: View {
    let symbol: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var tint = GameColor.leaf
    var identifier = ""
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(tint, in: Circle())
                .overlay(Circle().stroke(.white, lineWidth: 4))
                .shadow(color: GameColor.ink.opacity(0.2), radius: 4, y: 2)
            Text(title)
                .font(GameFont.title(20))
                .foregroundStyle(GameColor.ink)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(message)
                .font(GameFont.body(14, weight: .medium))
                .foregroundStyle(GameColor.inkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) { actions() }
                .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: 360)
        .background(GameColor.paper, in: RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(GameColor.line, lineWidth: 3))
        .shadow(color: GameColor.ink.opacity(0.25), radius: 18, y: 8)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityIdentifier(identifier)
        // Dialogs sit in the middle of the screen, panels at the bottom.
        .frame(maxHeight: .infinity)
    }
}

/// The header's menu, drawn as a small panel under the menu button.
struct MenuPanel: View {
    let showWholeIsland: () -> Void
    let followDeviceClock: () -> Void
    let askReset: () -> Void
    let openSettings: () -> Void
    let shareIsland: () -> Void
    /// Debug builds pass this to show the widget preview row.
    var previewWidget: (() -> Void)?
    let close: () -> Void

    var body: some View {
        GamePanel(title: "メニュー", symbol: "line.3.horizontal", identifier: "menu-panel", scrolls: false, close: close) {
            VStack(spacing: 10) {
                row("島全体を表示", "arrow.up.left.and.arrow.down.right", .secondary, showWholeIsland)
                row("時間帯を端末の時刻に戻す", "clock", .secondary, followDeviceClock)
                row("島の絵をシェア", "square.and.arrow.up", .secondary, shareIsland)
                row("せってい", "gearshape.fill", .secondary, openSettings)
                if let previewWidget {
                    row("ウィジェットのプレビュー", "square.grid.2x2", .secondary, previewWidget)
                }
                row("島をはじめからにする", "arrow.counterclockwise", .danger, askReset)
            }
        }
        .frame(maxWidth: 340)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(.top, 56)
    }

    private func row(
        _ title: LocalizedStringKey, _ symbol: String, _ kind: GameButtonStyle.Kind, _ action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol).frame(maxWidth: .infinity)
        }
        .buttonStyle(.game(kind))
    }
}
