/// Kinds of placeable objects. Raw values are stable identifiers (asset names, save files).
public enum ObjectKind: String, CaseIterable, Sendable {
    case roundTree = "tree-round"
    case pineTree = "tree-pine"
    case house = "house-small"
    case bench = "bench"
    case flower = "flower"
    case pond = "pond"

    public var footprint: Footprint {
        switch self {
        case .house, .pond: Footprint(width: 2, height: 2)
        case .roundTree, .pineTree, .bench, .flower: Footprint(width: 1, height: 1)
        }
    }

    /// Terrain the whole footprint must sit on. Benches may line paths; everything else needs grass.
    public var allowedTerrain: Set<Terrain> {
        switch self {
        case .bench: [.grass, .path]
        case .roundTree, .pineTree, .house, .flower, .pond: [.grass]
        }
    }

    public var isTree: Bool { self == .roundTree || self == .pineTree }
}
