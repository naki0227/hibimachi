import Foundation
import Testing

@testable import HibimachiCore

@Suite("Island diary pictures")
struct IslandDiaryTests {
    @Test func namesRoundTripAndForeignFilesAreIgnored() {
        let day = LocalDay(year: 2027, month: 1, day: 5)
        #expect(IslandDiary.fileName(for: day) == "island-2027-01-05.png")
        #expect(IslandDiary.day(fromFileName: "island-2027-01-05.png") == day)
        for name in [
            "photo.jpg", "island-2027-1-5.png", "island-2027-13-01.png", "island-.png", "island-2027-01-05.jpg",
        ] {
            #expect(IslandDiary.day(fromFileName: name) == nil, "\(name)")
        }
    }

    @Test func onlyDiaryPicturesOlderThanTheLimitAreRemoved() {
        let today = LocalDay(year: 2027, month: 6, day: 1)
        let names = [
            "island-2027-06-01.png", "island-2027-02-02.png", "island-2027-01-31.png", "island-2026-01-01.png",
            "abc.jpg", "notes.txt",
        ]
        // 2027-02-02 is 119 days before 2027-06-01; 2027-01-31 is 121.
        #expect(IslandDiary.filesToRemove(names, today: today) == ["island-2027-01-31.png", "island-2026-01-01.png"])
        #expect(IslandDiary.filesToRemove([], today: today).isEmpty)
    }
}
