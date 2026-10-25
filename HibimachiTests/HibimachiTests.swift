import HibimachiCore
import Testing

@testable import Hibimachi

@MainActor
@Test func appLinksCoreModule() {
    #expect(HibimachiCore.rulesVersion > 0)
}
