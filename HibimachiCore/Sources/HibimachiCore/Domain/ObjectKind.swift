/// Kinds of placeable objects. Raw values are stable identifiers (asset names, save files).
public enum ObjectKind: String, CaseIterable, Sendable {
    case roundTree = "tree-round"
    case pineTree = "tree-pine"
    case house = "house-small"
    case bench = "bench"
    case flower = "flower"
    case pond = "pond"
    case lamp = "lamp"
    // v1.0 additions (2026-10-26).
    case sakuraTree = "tree-sakura"
    case bush = "bush"
    case rock = "rock"
    case fence = "fence"
    case mailbox = "mailbox"
    case picnicMat = "picnic-mat"
    case birdhouse = "birdhouse"
    case swing = "swing"
    case campfire = "campfire"
    case well = "well"
    case garden = "garden"
    case fountain = "fountain"
    case cafe = "cafe"

    public var footprint: Footprint {
        switch self {
        case .house, .pond, .garden, .fountain, .cafe: Footprint(width: 2, height: 2)
        default: Footprint(width: 1, height: 1)
        }
    }

    /// Terrain the whole footprint must sit on. Things that line paths may stand on them; the rest needs grass.
    public var allowedTerrain: Set<Terrain> {
        switch self {
        case .bench, .lamp, .fence, .mailbox: [.grass, .path]
        default: [.grass]
        }
    }

    public var isTree: Bool { self == .roundTree || self == .pineTree || self == .sakuraTree }
}
