import Testing

@testable import HibimachiCore

@Suite("First-run tutorial")
struct TutorialGuideTests {
    @Test func stepsAdvanceOnlyOnTheirOwnSignal() {
        var guide = TutorialGuide()
        guide.record(.discovered)  // not this step's signal
        #expect(guide.step == .place)
        guide.record(.placedObject)
        #expect(guide.step == .discover)
        guide.record(.createdGoal)
        #expect(guide.step == .discover)
        guide.record(.discovered)
        #expect(guide.step == .quests)
        guide.record(.createdGoal)
        #expect(guide.step == .finished)
        #expect(!guide.isActive)
    }

    @Test func stepsAlreadyDoneAreSkipped() {
        var guide = TutorialGuide(step: .discover)
        guide.catchUp(hasDiscoveries: true, hasGoals: true)
        #expect(guide.step == .finished)

        var placing = TutorialGuide()
        placing.catchUp(hasDiscoveries: true, hasGoals: true)
        #expect(placing.step == .place, "placing is always shown first: it is the core verb")
    }

    @Test func savedStepsRestoreAndSkipEnds() {
        #expect(TutorialGuide(rawStep: nil).step == .place)
        #expect(TutorialGuide(rawStep: 2).step == .quests)
        #expect(TutorialGuide(rawStep: 99).step == .finished)
        var guide = TutorialGuide()
        guide.skip()
        #expect(guide.step == .finished)
        #expect(TutorialGuide.stepCount == 3)
    }
}
