import Foundation
import Testing

@testable import HibimachiCore

@Suite("Next-step suggestions and building dates")
struct NextStepTests {
    private func progress(sparkles: Int) throws -> PlayerProgress {
        try PlayerProgress(ledger: [
            RewardTransaction(
                id: UUID(), reason: .welcome, xpDelta: 0, sparkleDelta: sparkles, ruleVersion: 1,
                date: Date(timeIntervalSince1970: 0))
        ])
    }

    @Test func suggestsSomethingAffordableThatSomeoneWouldReactTo() throws {
        let world = try TestWorlds.grass()
        let step = NextStep.suggestion(world: world, progress: try progress(sparkles: 10))
        guard case .canBuild(let kind) = step else {
            Issue.record("expected a building, got \(String(describing: step))")
            return
        }
        #expect(RewardRule.price(of: kind) <= 10)
        #expect(Unlocks.requirement(for: kind) == .always)
        #expect(ReactionRule.all.contains { $0.targetKinds.contains(kind) })
    }

    @Test func withoutSparklesItHintsAtAReactionOnTheIsland() throws {
        let world = try TestWorlds.grass(objects: [TestWorlds.object(.bench, 2, 2)])
        let step = NextStep.suggestion(world: world, progress: try progress(sparkles: 0))
        #expect(step == .tryReaction(.benchRest) || step == .tryReaction(.bloomBench))
    }

    @Test func otherwiseItNamesWhatUnlocksNext() throws {
        let world = try TestWorlds.grass()
        let step = NextStep.suggestion(world: world, progress: try progress(sparkles: 0))
        guard case .unlocksSoon(let kind, let requirement) = step else {
            Issue.record("expected an unlock hint, got \(String(describing: step))")
            return
        }
        #expect(requirement.level == 2)
        #expect(Unlocks.requirement(for: kind) == requirement)
    }

    @Test func varietyRotatesBetweenEqualOptions() throws {
        let world = try TestWorlds.grass()
        let wallet = try progress(sparkles: 1_000)
        let options = (0..<6).map { NextStep.suggestion(world: world, progress: wallet, variety: $0) }
        #expect(options.contains { $0 != options[0] })
    }

    @MainActor
    @Test func placedObjectsRememberTheirDay() throws {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        let repository = FakeRepository(.loaded(snapshot(try TestWorlds.grass())))
        let store = GameStore(repository: repository, seed: 1, now: { date }, calendar: calendar)
        store.beginPlacing(.flower)
        store.setPreviewOrigin(TileCoord(x: 5, y: 5))
        #expect(store.confirmPreview())
        let placed = try #require(store.selectedObject)
        #expect(placed.placedAt == date)
        #expect(store.placedDay(of: placed) == LocalDay(date: date, calendar: calendar))
        #expect(repository.saved.last?.world.object(withID: placed.id)?.placedAt == date)
    }
}
