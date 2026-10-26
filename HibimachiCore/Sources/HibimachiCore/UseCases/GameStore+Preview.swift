import Foundation

/// What the placing/moving preview shows, and where a newly picked object first appears.
extension GameStore {
    public var previewKind: ObjectKind? {
        switch mode {
        case .browse, .paintingPath: nil
        case .placing(let kind, _): kind
        case .moving(let id, _): world.object(withID: id)?.kind
        }
    }

    public var previewOrigin: TileCoord? {
        switch mode {
        case .browse, .paintingPath: nil
        case .placing(_, let origin), .moving(_, let origin): origin
        }
    }

    /// `nil` means the preview can be confirmed.
    public var previewIssue: PlacementError? {
        switch mode {
        case .browse, .paintingPath: nil
        case .placing(let kind, let origin): world.placementIssue(for: kind, at: origin)
        case .moving(let id, let origin):
            if let object = world.object(withID: id) {
                world.placementIssue(for: object.kind, at: origin, ignoring: id)
            } else {
                .unknownObject(id)
            }
        }
    }

    /// First valid spot around the creature, so a new object appears where the player is already looking.
    func suggestedOrigin(for kind: ObjectKind) -> TileCoord {
        let center = world.creature.position
        for radius in 1...max(world.width, world.height) {
            for dy in -radius...radius {
                for dx in -radius...radius where max(abs(dx), abs(dy)) == radius {
                    let origin = center.offset(dx: dx, dy: dy)
                    if world.placementIssue(for: kind, at: origin) == nil { return origin }
                }
            }
        }
        return TileCoord(x: 0, y: 0)
    }
}
