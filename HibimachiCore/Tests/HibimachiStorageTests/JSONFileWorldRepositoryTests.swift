import Foundation
import HibimachiCore
import Testing

@testable import HibimachiStorage

@Suite("JSON file repository")
struct JSONFileWorldRepositoryTests {
    struct WriteFailed: Error {}

    let directory: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("hibimachi-tests-\(UUID().uuidString)", isDirectory: true)
    }

    private func repository(writer: JSONFileWorldRepository.Writer? = nil) -> JSONFileWorldRepository {
        let fixedNow = Date(timeIntervalSince1970: 1_800_000_000)
        if let writer {
            return JSONFileWorldRepository(directory: directory, writer: writer, now: { fixedNow })
        }
        return JSONFileWorldRepository(directory: directory, now: { fixedNow })
    }

    private func write(_ text: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(text.utf8).write(to: repository().fileURL)
    }

    private func game(_ world: World) -> GameSnapshot {
        GameSnapshot(
            world: world, progress: PlayerProgress.starting(for: world, at: Date(timeIntervalSince1970: 0), id: UUID()))
    }

    private func sampleWorld() -> World {
        var world = IslandFactory.makeWorld()
        world.recordDiscovery(.treeNap)
        world.recordDiscovery(.benchRest)
        world.creature.position = TileCoord(x: 2, y: 5)
        return world
    }

    @Test func missingFileIsNotFound() {
        #expect(repository().load() == .notFound)
    }

    @Test func roundTripKeepsLayoutCreatureAndDiscoveries() throws {
        let world = sampleWorld()
        try repository().save(game(world))
        guard case .loaded(let snapshot) = repository().load() else {
            Issue.record("expected loaded world")
            return
        }
        let loaded = snapshot.world
        #expect(loaded.objects == world.objects)
        #expect(loaded.terrain == world.terrain)
        #expect(loaded.discoveries == world.discoveries)
        #expect(loaded.creature.id == world.creature.id)
        #expect(loaded.creature.position == world.creature.position)
    }

    @Test func emptyIslandRoundTrips() throws {
        let world = try World(
            width: 2, height: 1, terrain: [.grass, .path], objects: [],
            creature: Creature(id: UUID(), position: TileCoord(x: 0, y: 0)))
        try repository().save(game(world))
        guard case .loaded(let snapshot) = repository().load() else {
            Issue.record("expected loaded world")
            return
        }
        #expect(snapshot.world.objects.isEmpty && snapshot.world.discoveries.isEmpty)
    }

    @Test func savingTwiceIsByteIdentical() throws {
        let saved = game(sampleWorld())
        let repo = repository()
        try repo.save(saved)
        let first = try Data(contentsOf: repo.fileURL)
        try repo.save(saved)
        #expect(try Data(contentsOf: repo.fileURL) == first)
    }

    @Test func writeFailureKeepsThePreviousSave() throws {
        let original = sampleWorld()
        try repository().save(game(original))
        let before = try Data(contentsOf: repository().fileURL)

        var changed = original
        _ = changed.removeObject(original.objects[0].id)
        #expect(throws: WriteFailed.self) {
            try repository(writer: { _, _ in throw WriteFailed() }).save(game(changed))
        }
        #expect(try Data(contentsOf: repository().fileURL) == before)
    }

    @Test(arguments: [
        "", "not json", "{\"schemaVersion\":1}",
        // Overlapping objects are rejected by World validation.
        """
        {"schemaVersion":1,"width":2,"height":1,"terrain":"gg","discoveries":[],
         "creature":{"id":"00000000-0000-0000-0000-000000000009","x":0,"y":0},
         "objects":[{"id":"00000000-0000-0000-0000-000000000001","kind":"flower","x":1,"y":0},
                    {"id":"00000000-0000-0000-0000-000000000002","kind":"bench","x":1,"y":0}]}
        """,
        // Unknown object kind.
        """
        {"schemaVersion":1,"width":1,"height":1,"terrain":"g","discoveries":[],
         "creature":{"id":"00000000-0000-0000-0000-000000000009","x":0,"y":0},
         "objects":[{"id":"00000000-0000-0000-0000-000000000001","kind":"castle","x":0,"y":0}]}
        """,
    ])
    func unreadableFilesAreMovedAsideNotLost(contents: String) throws {
        try write(contents)
        guard case .unreadable(_, let backup) = repository().load() else {
            Issue.record("expected unreadable")
            return
        }
        let name = try #require(backup)
        #expect(name == "world.unreadable-20270115-080000.json")
        #expect(!FileManager.default.fileExists(atPath: repository().fileURL.path))
        let preserved = try Data(contentsOf: directory.appendingPathComponent(name))
        #expect(preserved == Data(contents.utf8))
    }

    @Test func progressRoundTripsWithGoalsRewardsAndPurchases() throws {
        let world = sampleWorld()
        var progress = PlayerProgress.starting(for: world, at: Date(timeIntervalSince1970: 0), id: UUID())
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let goal = try progress.addGoal(title: "部屋を整える", category: .tidy, at: date, makeID: UUID.init).get()
        let quest = try #require(progress.quests(of: goal.id).first)
        let day = LocalDay(year: 2027, month: 1, day: 15)
        _ = try progress.complete(quest.id, on: day, at: date, completionID: UUID(), transactionID: UUID()).get()
        _ = try progress.purchase(.lamp, at: date, transactionID: UUID()).get()
        progress.skip(quest.id, on: day)
        try repository().save(GameSnapshot(world: world, progress: progress))
        guard case .loaded(let snapshot) = repository().load() else {
            Issue.record("expected loaded game")
            return
        }
        #expect(snapshot.progress == progress)
        #expect(snapshot.progress.sparkles == RewardRule.welcomeSparkles + RewardRule.questSparkles - 10)
        #expect(snapshot.progress.totalXP == RewardRule.questXP)
    }

    @Test func tamperedNegativeBalanceIsUnreadable() throws {
        try write(
            """
            {"schemaVersion":2,"width":1,"height":1,"terrain":"g","discoveries":[],"objects":[],
             "creature":{"id":"00000000-0000-0000-0000-000000000009","x":0,"y":0},
             "progress":{"goals":[],"quests":[],"completions":[],"owned":{},"skippedQuestIDs":[],
              "transactions":[{"reason":"purchase","reference":"house-small","id":"00000000-0000-0000-0000-000000000001",
                "xp":0,"sparkles":-30,"ruleVersion":1,"date":"2027-01-15T08:00:00Z"}]}}
            """)
        guard case .unreadable(let reason, _) = repository().load() else {
            Issue.record("expected unreadable")
            return
        }
        #expect(reason.contains("negativeBalance"))
    }

    @Test func newerSchemaIsNotOverwrittenAndBackupsDoNotCollide() throws {
        try write("{\"schemaVersion\":99}")
        guard case .unreadable(let reason, let first) = repository().load() else {
            Issue.record("expected unreadable")
            return
        }
        #expect(reason.contains("99"))
        try write("{\"schemaVersion\":99}")
        guard case .unreadable(_, let second) = repository().load() else {
            Issue.record("expected unreadable")
            return
        }
        #expect(first != nil && second != nil && first != second)
    }

    @Test func schemaV1FixtureStillLoads() throws {
        // Frozen v1 sample: keep it unchanged so future migrations are tested against real old data.
        try write(
            """
            {"creature":{"id":"00000000-0000-0000-0000-000000000009","x":0,"y":0},
             "discoveries":["tree-nap","removed-reaction"],
             "height":2,"objects":[{"id":"00000000-0000-0000-0000-000000000001","kind":"tree-round","x":1,"y":1}],
             "schemaVersion":1,"terrain":"gpwg","width":2}
            """)
        guard case .loaded(let snapshot) = repository().load() else {
            Issue.record("expected loaded world")
            return
        }
        let world = snapshot.world
        #expect(world.terrain == [.grass, .path, .water, .grass])
        #expect(world.objects.first?.kind == .roundTree)
        #expect(world.discoveries == [.treeNap])
        // v1 -> v2 migration: owns what is placed, gets the welcome gift, no goals yet.
        #expect(snapshot.progress.owned == [.roundTree: 1])
        #expect(snapshot.progress.sparkles == RewardRule.welcomeSparkles)
        #expect(snapshot.progress.goals.isEmpty)
    }
}
