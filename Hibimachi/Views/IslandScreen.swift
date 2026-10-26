import HibimachiCore
import Observation
import SpriteKit
import SwiftUI

/// Pictures of reactions taken by the scene this session (not saved; P2's album will own persistence).
@MainActor
@Observable
final class DiscoveryAlbum {
    var images: [ReactionKind: CGImage] = [:]
}

/// The island screen: the world fills the display; header, side buttons and palette float above it.
struct IslandScreen: View {
    let store: GameStore
    @State private var scene: IslandScene
    @State private var album: DiscoveryAlbum
    @State private var tab: PaletteTab = .build
    @State private var phaseOverride: DayPhase?
    @State private var showsFieldGuide = false
    @State private var showsObjectList = false
    @State private var confirmsReset = false

    init(store: GameStore, initialPhase: DayPhase? = nil) {
        self.store = store
        let scene = IslandScene(store: store)
        scene.dayPhaseOverride = initialPhase
        _phaseOverride = State(initialValue: initialPhase)
        let album = DiscoveryAlbum()
        scene.onDiscoverySnapshot = { kind, image in album.images[kind] = image }
        _scene = State(initialValue: scene)
        _album = State(initialValue: album)
    }

    private var shownPhase: DayPhase {
        phaseOverride ?? DayPhase(hour: Calendar.current.component(.hour, from: Date()))
    }

    var body: some View {
        ZStack(alignment: .top) {
            SpriteView(scene: scene, preferredFramesPerSecond: 60)
                .ignoresSafeArea()
                .accessibilityElement()
                .accessibilityLabel("ひびまちの島")
                .accessibilityHint("配置物の一覧ボタンから、島のものを選んだり動かしたりできます")
                .accessibilityIdentifier("island-view")

            VStack(spacing: 10) {
                HeaderBar(store: store, confirmsReset: $confirmsReset, phaseOverride: $phaseOverride, scene: scene)
                if let message = store.saveErrorMessage {
                    SaveErrorBanner(message: message) { store.persist() }
                }
                if let kind = store.pendingDiscoveries.first {
                    DiscoveryCard(kind: kind, image: album.images[kind]) { store.dismissDiscovery() }
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                HStack {
                    Spacer()
                    SideButtons(
                        phase: shownPhase,
                        showsFieldGuide: $showsFieldGuide,
                        showsObjectList: $showsObjectList
                    ) { phaseOverride = shownPhase.next }
                }
                Spacer()
                bottomControls
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            .animation(.easeOut(duration: 0.25), value: store.pendingDiscoveries.first)
        }
        .onChange(of: phaseOverride) { _, phase in scene.dayPhaseOverride = phase }
        .sensoryFeedback(.success, trigger: store.objectsRevision)
        .sensoryFeedback(.selection, trigger: store.terrainRevision)
        .sensoryFeedback(.error, trigger: store.lastRejection) { _, new in new != nil }
        .sheet(isPresented: $showsFieldGuide) {
            FieldGuideView(discoveries: store.world.discoveries, images: album.images)
        }
        .sheet(isPresented: $showsObjectList) {
            ObjectListView(store: store)
        }
        .confirmationDialog("島をはじめからにしますか？", isPresented: $confirmsReset, titleVisibility: .visible) {
            Button("はじめから", role: .destructive) { store.resetIsland() }
        } message: {
            Text("置いたもの・小道・図鑑の記録が最初の状態に戻ります。")
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

    @ViewBuilder
    private var bottomControls: some View {
        switch store.mode {
        case .placing, .moving:
            EditBar(store: store)
        case .paintingPath:
            PathBar(store: store)
        case .browse:
            if let selected = store.selectedObject {
                SelectionBar(store: store, object: selected)
            } else {
                BuildPalette(store: store, tab: $tab)
            }
        }
    }
}
