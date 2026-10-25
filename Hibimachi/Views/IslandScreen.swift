import HibimachiCore
import SpriteKit
import SwiftUI

/// The single P0 screen: the island fills the display; small controls sit at the top and bottom edges.
struct IslandScreen: View {
    let store: GameStore
    @State private var scene: IslandScene
    @State private var showsFieldGuide = false
    @State private var showsObjectList = false
    @State private var confirmsReset = false

    init(store: GameStore) {
        self.store = store
        _scene = State(initialValue: IslandScene(store: store))
    }

    var body: some View {
        ZStack {
            SpriteView(scene: scene, preferredFramesPerSecond: 60)
                .ignoresSafeArea()
                .accessibilityElement()
                .accessibilityLabel("ひびまちの島")
                .accessibilityHint("配置物の一覧ボタンから、島のものを選んだり動かしたりできます")
                .accessibilityIdentifier("island-view")

            VStack(spacing: 8) {
                topBar
                if let message = store.saveErrorMessage {
                    SaveErrorBanner(message: message) { store.persist() }
                }
                if let kind = store.pendingDiscoveries.first {
                    DiscoveryToast(kind: kind) { store.dismissDiscovery() }
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer()
                bottomControls
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            .animation(.easeOut(duration: 0.2), value: store.pendingDiscoveries.first)
        }
        .sensoryFeedback(.success, trigger: store.objectsRevision)
        .sensoryFeedback(.error, trigger: store.lastRejection) { _, new in new != nil }
        .sheet(isPresented: $showsFieldGuide) {
            FieldGuideView(discoveries: store.world.discoveries)
        }
        .sheet(isPresented: $showsObjectList) {
            ObjectListView(store: store)
        }
        .confirmationDialog("島をはじめからにしますか？", isPresented: $confirmsReset, titleVisibility: .visible) {
            Button("はじめから", role: .destructive) { store.resetIsland() }
        } message: {
            Text("置いたものと図鑑の記録が最初の状態に戻ります。")
        }
        .alert(
            "保存データを読み込めませんでした",
            isPresented: Binding(get: { store.startupNotice != nil }, set: { if !$0 { store.dismissStartupNotice() } })
        ) {
            Button("OK") { store.dismissStartupNotice() }
        } message: {
            Text("新しい島ではじめます。読めなかったデータは別名で端末内に残してあります。")
        }
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            Label("\(store.world.objects.count)", systemImage: "square.grid.2x2")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(.regularMaterial, in: Capsule())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("置いたもの \(store.world.objects.count)こ")
                .accessibilityIdentifier("object-count")
            Spacer()
            HUDButton(systemImage: "list.bullet", label: "配置物の一覧", identifier: "object-list") {
                showsObjectList = true
            }
            HUDButton(
                systemImage: "book.closed", label: "図鑑 \(store.world.discoveries.count)件", identifier: "field-guide"
            ) {
                showsFieldGuide = true
            }
            Menu {
                Button("島をはじめからにする", systemImage: "arrow.counterclockwise") { confirmsReset = true }
                Button("島全体を表示", systemImage: "arrow.up.left.and.arrow.down.right") { scene.resetCamera() }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 44, height: 44)
                    .background(.regularMaterial, in: Circle())
            }
            .accessibilityLabel("メニュー")
        }
    }

    @ViewBuilder
    private var bottomControls: some View {
        switch store.mode {
        case .placing, .moving:
            EditBar(store: store)
        case .browse:
            if let selected = store.selectedObject {
                SelectionBar(store: store, object: selected)
            } else {
                BuildPalette(store: store)
            }
        }
    }
}

struct HUDButton: View {
    let systemImage: String
    let label: String
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 44, height: 44)
                .background(.regularMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }
}

struct DiscoveryToast: View {
    let kind: ReactionKind
    let dismiss: () -> Void

    var body: some View {
        Button(action: dismiss) {
            VStack(alignment: .leading, spacing: 2) {
                Text("発見！").font(.caption.weight(.bold)).foregroundStyle(.orange)
                Text(kind.title).font(.headline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("発見！ \(kind.title)")
        .accessibilityHint("タップで閉じます。図鑑に記録されました")
        .accessibilityIdentifier("discovery-toast")
        .task(id: kind) {
            try? await Task.sleep(for: .seconds(4))
            dismiss()
        }
    }
}

struct SaveErrorBanner: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        HStack {
            Text("保存できませんでした。島はこのまま残っています。")
                .font(.footnote)
            Spacer()
            Button("再試行", action: retry)
                .frame(minHeight: 44)
        }
        .padding(.horizontal, 12)
        .background(.orange.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier("save-error")
    }
}
