import Foundation
import Testing

@testable import HibimachiCore

@Suite("Editing and undo")
struct WorldEditorTests {
    @Test func undoReversesPlaceMoveAndRemoveInOrder() throws {
        var editor = WorldEditor(world: try TestWorlds.grass())
        let id = UUID()
        _ = try editor.place(.bench, at: TileCoord(x: 1, y: 1), id: id).get()
        _ = try editor.move(id, to: TileCoord(x: 5, y: 5)).get()
        _ = try editor.remove(id).get()
        #expect(editor.world.objects.isEmpty)

        let result1 = editor.undo()
        #expect(result1)
        #expect(editor.world.object(withID: id)?.origin == TileCoord(x: 5, y: 5))
        let result2 = editor.undo()
        #expect(result2)
        #expect(editor.world.object(withID: id)?.origin == TileCoord(x: 1, y: 1))
        let result3 = editor.undo()
        #expect(result3)
        #expect(editor.world.objects.isEmpty)
        let result4 = editor.undo()
        #expect(!result4)
        #expect(!editor.canUndo)
    }

    @Test func failedEditsAndNoOpMovesDoNotCreateUndoSteps() throws {
        let tree = TestWorlds.object(.roundTree, 2, 2)
        var editor = WorldEditor(world: try TestWorlds.grass(objects: [tree]))
        let result5 = editor.place(.flower, at: TileCoord(x: 2, y: 2), id: UUID())
        #expect(result5 == .failure(.overlapsObject(tree.id)))
        #expect(throws: Never.self) { try editor.move(tree.id, to: tree.origin).get() }
        #expect(!editor.canUndo)
    }

    @Test func historyIsBounded() throws {
        var editor = WorldEditor(world: try TestWorlds.grass(width: 10, height: 10))
        for index in 0..<(WorldEditor.undoLimit + 5) {
            _ = try editor.place(.flower, at: TileCoord(x: index % 10, y: index / 10), id: UUID()).get()
        }
        var undone = 0
        while editor.undo() { undone += 1 }
        #expect(undone == WorldEditor.undoLimit)
        #expect(editor.world.objects.count == 5)
    }

    @Test func undoKeepsDiscoveriesAndDoesNotTeleportTheCreature() throws {
        var editor = WorldEditor(world: try TestWorlds.grass(creatureAt: TileCoord(x: 6, y: 6)))
        _ = try editor.place(.bench, at: TileCoord(x: 1, y: 1), id: UUID()).get()
        editor.world.recordDiscovery(.benchRest)
        editor.world.creature.position = TileCoord(x: 7, y: 7)
        let result6 = editor.undo()
        #expect(result6)
        #expect(editor.world.discoveries == [.benchRest])
        #expect(editor.world.creature.position == TileCoord(x: 7, y: 7))
    }

    @Test func undoOfRemovalUnderTheCreatureMovesTheCreatureAside() throws {
        let id = UUID()
        var editor = WorldEditor(world: try TestWorlds.grass())
        _ = try editor.place(.house, at: TileCoord(x: 3, y: 3), id: id).get()
        _ = try editor.remove(id).get()
        editor.world.creature.position = TileCoord(x: 3, y: 3)
        let result7 = editor.undo()
        #expect(result7)
        #expect(editor.world.object(withID: id) != nil)
        #expect(editor.world.isWalkable(editor.world.creature.position))
    }
}
