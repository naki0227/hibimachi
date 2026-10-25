import HibimachiCore
import Testing

@testable import HibimachiStorage

@Test func storageTracksRulesVersion() {
    #expect(HibimachiStorage.supportedRulesVersion == HibimachiCore.rulesVersion)
}
