import HibimachiCore

/// Player-facing Japanese copy. Kept in the app layer so domain types stay free of presentation text.
extension ObjectKind {
    var displayName: String {
        switch self {
        case .roundTree: "まるい木"
        case .pineTree: "とがった木"
        case .house: "小さな家"
        case .bench: "ベンチ"
        case .flower: "花"
        case .pond: "池"
        }
    }

    var symbolName: String {
        switch self {
        case .roundTree: "tree.fill"
        case .pineTree: "tree"
        case .house: "house.fill"
        case .bench: "chair.lounge.fill"
        case .flower: "camera.macro"
        case .pond: "drop.fill"
        }
    }
}

extension ReactionKind {
    var title: String {
        switch self {
        case .benchRest: "ベンチでひと休み"
        case .bloomBench: "花をながめて休む"
        case .treeNap: "木かげでうたた寝"
        case .pondVisit: "池をのぞきこむ"
        }
    }

    var detail: String {
        switch self {
        case .benchRest: "近くにベンチがあると、腰かけてのんびりする。"
        case .bloomBench: "花のとなりのベンチがお気に入り。いつもよりうれしそう。"
        case .treeNap: "木のそばに来ると、ころんと横になって眠ってしまう。"
        case .pondVisit: "池のふちで、水面をじっとのぞきこむ。"
        }
    }

    /// Short emote shown above the creature while reacting.
    var emote: String {
        switch self {
        case .benchRest: "♪"
        case .bloomBench: "✿♪"
        case .treeNap: "z z"
        case .pondVisit: "…"
        }
    }
}

extension PlacementError {
    var message: String {
        switch self {
        case .outOfBounds: "島の外には置けません"
        case .blockedByTerrain(.water): "水の上には置けません"
        case .blockedByTerrain(.path): "小道の上には置けません"
        case .blockedByTerrain(.grass): "この地面には置けません"
        case .overlapsObject: "ほかのものと重なっています"
        case .unknownObject: "動かすものが見つかりません"
        }
    }
}
