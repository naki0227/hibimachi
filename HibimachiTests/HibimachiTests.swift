import HibimachiCore
import Testing

@testable import Hibimachi

@MainActor
@Test func appLinksCoreModule() {
    #expect(IslandFactory.makeWorld().objects.count == 6)
}
