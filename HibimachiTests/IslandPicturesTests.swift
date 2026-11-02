import CoreGraphics
import Foundation
import HibimachiCore
import Testing

@testable import Hibimachi

@MainActor
@Suite("Island pictures")
struct IslandPicturesTests {
    private func tinyImage() throws -> CGImage {
        let context = try #require(
            CGContext(
                data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 0.2, green: 0.6, blue: 0.3, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        return try #require(context.makeImage())
    }

    @Test func todaysPictureIsKeptAndOldOnesAreRemoved() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("island-days-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let pictures = IslandPictures(directory: directory)
        let old = LocalDay(year: 2027, month: 1, day: 1)
        let today = LocalDay(year: 2027, month: 6, day: 1)
        #expect(pictures.image(for: today) == nil)
        pictures.save(try tinyImage(), day: old)
        try Data("keep".utf8).write(to: directory.appendingPathComponent("notes.txt"))
        pictures.save(try tinyImage(), day: today)
        #expect(pictures.image(for: today) != nil)
        #expect(pictures.image(for: old) == nil, "older than the diary keeps")
        #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent("notes.txt").path))
        pictures.save(nil, day: LocalDay(year: 2027, month: 6, day: 2))
        #expect(pictures.image(for: LocalDay(year: 2027, month: 6, day: 2)) == nil, "no picture, no file")
    }
}

@MainActor
@Suite("Island summary for VoiceOver")
struct IslandSummaryTests {
    @Test func residentsTowersAndPlacedThingsAreRead() throws {
        let store = GameStore(repository: MemoryRepository(), seed: 1)
        #expect(store.addGoal(title: "部屋", category: .tidy))
        let goal = try #require(store.progress.activeGoals.first)
        #expect(store.applyPlan(PlanDraft.template(for: .tidy), to: goal.id))
        let text = IslandSummary.text(for: store)
        #expect(text.contains(Species.mochi.displayName))
        #expect(text.contains("\(store.world.objects.count)"))
        #expect(text.contains("部屋"), "the goal's tower is named")
        #expect(text.contains("1/\(GoalMonument.maxStage)"), "a plan with no finished step is level 1")
    }
}
