/// Kinds of island residents. Raw values are stable IDs (save files).
/// Newcomers arrive as the island gets livelier (measured in discoveries), never by paying or waiting.
public enum Species: String, CaseIterable, Sendable {
    /// The first resident: a round white mochi with a sprout. Likes to sit down.
    case mochi
    /// A small yellow bird. Likes trees, birdhouses and water.
    case kotori
    /// A young tanuki. Likes fire, food and picnics.
    case tanuki

    /// Discoveries on the island before this species moves in.
    public var arrivalDiscoveries: Int {
        switch self {
        case .mochi: 0
        case .kotori: 3
        case .tanuki: 7
        }
    }

    /// Multiplier on a reaction's base weight: what this resident tends to do when it has a choice.
    public func preference(for reaction: ReactionKind) -> Int {
        switch (self, reaction) {
        case (.mochi, .benchRest), (.mochi, .bloomBench), (.mochi, .cafeTerrace), (.mochi, .swingPlay): 2
        case (.kotori, .birdWatch): 4
        case (.kotori, .sakuraViewing): 3
        case (.kotori, .treeNap), (.kotori, .fountainSplash), (.kotori, .wellPeek): 2
        case (.tanuki, .campfireWarm): 4
        case (.tanuki, .gardenTend), (.tanuki, .picnic): 3
        case (.tanuki, .pondVisit), (.tanuki, .cafeVisit): 2
        default: 1
        }
    }
}
