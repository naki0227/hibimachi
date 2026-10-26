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
    let tutorial: TutorialCoach
    let settings: AppSettings
    @State private var scene: IslandScene
    @State private var album: DiscoveryAlbum
    @State private var tab: PaletteTab = .build
    @State private var phaseOverride: DayPhase?
    @State private var overlay: IslandOverlay?
    @Environment(\.scenePhase) private var scenePhase

    init(store: GameStore, tutorial: TutorialCoach, settings: AppSettings, initialPhase: DayPhase? = nil) {
        self.store = store
        self.tutorial = tutorial
        self.settings = settings
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
                HeaderBar(store: store) { overlay = .menu }
                if let message = store.saveErrorMessage {
                    SaveErrorBanner(message: message) { store.persist() }
                }
                // Side buttons never move; the discovery card floats to their left so a tap can't land on a
                // button that just shifted when the card appeared or auto-dismissed.
                HStack(alignment: .top, spacing: 8) {
                    ZStack(alignment: .top) {
                        if let kind = store.pendingDiscoveries.first {
                            DiscoveryCard(kind: kind, image: album.images[kind]) { store.dismissDiscovery() }
                                .transition(.move(edge: .top).combined(with: .opacity))
                        } else if let species = store.pendingArrivals.first {
                            ResidentCard.arrival(species) { store.dismissArrival() }
                                .transition(.move(edge: .top).combined(with: .opacity))
                        } else if let notice = store.pendingFriendships.first {
                            ResidentCard.friendship(notice) { store.dismissFriendship() }
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                    SideButtons(
                        phase: shownPhase,
                        questsLeft: store.progress.activeGoals.isEmpty ? 1 : store.todaysQuests.count,
                        objectCount: store.world.objects.count,
                        highlightsQuests: tutorial.guide.step == .quests && overlay == nil,
                        open: { overlay = $0 }
                    ) { phaseOverride = shownPhase.next }
                }
                Spacer()
                if tutorial.guide.isActive, store.mode == .browse, store.selectedObject == nil {
                    TutorialCard(step: tutorial.guide.step) { tutorial.skip() }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                bottomControls
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            // The keyboard belongs to panels; the island HUD must not slide under the status bar with it.
            .ignoresSafeArea(.keyboard)
            .animation(.easeOut(duration: 0.25), value: store.pendingDiscoveries.first)
            .animation(.easeOut(duration: 0.25), value: store.pendingArrivals.first)
            .animation(.easeOut(duration: 0.25), value: store.pendingFriendships.first)
            .animation(.easeOut(duration: 0.25), value: tutorial.guide.step)
        }
        .modifier(TutorialSignals(store: store, coach: tutorial))
        .onChange(of: phaseOverride) { _, phase in scene.dayPhaseOverride = phase }
        .onChange(of: scenePhase) { _, phase in
            // Leaving the app: the island is still on screen, so this is the moment to picture it for the widget.
            if phase == .inactive { WidgetSync.exportIsland(scene.islandPicture()) }
        }
        .sensoryFeedback(.success, trigger: store.objectsRevision) { _, _ in settings.haptics }
        .sensoryFeedback(.selection, trigger: store.terrainRevision) { _, _ in settings.haptics }
        .sensoryFeedback(.error, trigger: store.lastRejection) { _, new in settings.haptics && new != nil }
        .modifier(SoundCues(store: store, settings: settings, phase: shownPhase))
        .overlay {
            ModalLayer(item: shownOverlay) { overlay in overlayContent(overlay) }
        }
    }

    /// A save that could not be read is announced before anything else.
    private var shownOverlay: Binding<IslandOverlay?> {
        Binding(
            get: { store.startupNotice != nil ? .startupNotice : overlay },
            set: { newValue in
                if newValue == nil, store.startupNotice != nil {
                    store.dismissStartupNotice()
                } else {
                    overlay = newValue
                }
            })
    }

    @ViewBuilder
    private func overlayContent(_ item: IslandOverlay) -> some View {
        let close = { overlay = nil }
        switch item {
        case .menu:
            MenuPanel(
                showWholeIsland: {
                    scene.resetCamera()
                    close()
                },
                followDeviceClock: {
                    phaseOverride = nil
                    close()
                },
                askReset: { overlay = .resetConfirm },
                openSettings: { overlay = .settings },
                previewWidget: Self.widgetPreviewAction { overlay = .widgetPreview },
                close: close)
        case .quests:
            QuestPanel(store: store, close: close)
        case .fieldGuide:
            FieldGuidePanel(
                discoveries: store.world.discoveries, images: album.images,
                residents: store.world.residents, close: close)
        case .objectList:
            ObjectListPanel(store: store, close: close)
        case .album:
            AlbumPanel(store: store, close: close)
        case .settings:
            SettingsPanel(settings: settings, replayTutorial: { tutorial.restart(store: store) }, close: close)
        case .memory(let objectID):
            BuildingMemoryPanel(store: store, objectID: objectID, close: close)
        case .resetConfirm:
            GameDialog(
                symbol: "arrow.counterclockwise", title: "島をはじめからにしますか？",
                message: "置いたもの・小道・図鑑の記録が最初の状態に戻ります。", tint: GameColor.berry,
                identifier: "reset-dialog"
            ) {
                Button("やめておく", action: close).buttonStyle(.game(.secondary))
                Button("はじめから") {
                    store.resetIsland()
                    close()
                }
                .buttonStyle(.game(.danger))
            }
        case .widgetPreview:
            #if DEBUG
                WidgetPreviewPanel(store: store, scene: scene, close: close)
            #else
                EmptyView()
            #endif
        case .startupNotice:
            GameDialog(
                symbol: "exclamationmark.triangle.fill", title: "保存データを読み込めませんでした",
                message: "新しい島ではじめます。読めなかったデータは別名で端末内に残してあります。", tint: GameColor.sun,
                identifier: "startup-notice"
            ) {
                Button("OK") { store.dismissStartupNotice() }.buttonStyle(.game)
            }
        }
    }

    private static func widgetPreviewAction(_ open: @escaping () -> Void) -> (() -> Void)? {
        #if DEBUG
            return open
        #else
            return nil
        #endif
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
                SelectionBar(store: store, object: selected) { overlay = .memory(selected.id) }
            } else {
                BuildPalette(store: store, tab: $tab)
            }
        }
    }
}
