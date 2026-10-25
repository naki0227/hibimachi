import Testing

@testable import HibimachiCore

@Test func rulesVersionIsPositive() {
    #expect(HibimachiCore.rulesVersion > 0)
}
