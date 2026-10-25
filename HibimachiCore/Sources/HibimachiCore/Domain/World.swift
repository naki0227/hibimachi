import Foundation

public enum WorldValidationError: Error, Equatable, Sendable {
    case invalidSize
    case terrainCountMismatch(expected: Int, actual: Int)
    case duplicateObjectID(UUID)
    case invalidObject(UUID, PlacementError)
    case creatureOutOfBounds
}

/// The whole persisted island: terrain, placed objects, the creature and discovered reactions.
/// Every initialiser path validates invariants, so a `World` value is always consistent.
public struct World: Equatable, Sendable {
    public let width: Int
    public let height: Int
    /// Row-major terrain, index = y * width + x.
    public let terrain: [Terrain]
    public private(set) var objects: [WorldObject]
    public var creature: Creature
    public private(set) var discoveries: Set<ReactionKind>

    public init(
        width: Int,
        height: Int,
        terrain: [Terrain],
        objects: [WorldObject],
        creature: Creature,
        discoveries: Set<ReactionKind> = []
    ) throws(WorldValidationError) {
        guard width > 0, height > 0 else { throw .invalidSize }
        guard terrain.count == width * height else {
            throw .terrainCountMismatch(expected: width * height, actual: terrain.count)
        }
        self.width = width
        self.height = height
        self.terrain = terrain
        self.objects = []
        self.creature = creature
        self.discoveries = discoveries
        for object in objects {
            guard self.object(withID: object.id) == nil else { throw .duplicateObjectID(object.id) }
            if let issue = placementIssue(for: object.kind, at: object.origin) {
                throw .invalidObject(object.id, issue)
            }
            self.objects.append(object)
        }
        guard contains(creature.position) else { throw .creatureOutOfBounds }
        relocateCreatureIfBlocked()
    }

    // MARK: Queries

    public func contains(_ tile: TileCoord) -> Bool {
        (0..<width).contains(tile.x) && (0..<height).contains(tile.y)
    }

    public func terrain(at tile: TileCoord) -> Terrain? {
        contains(tile) ? terrain[tile.y * width + tile.x] : nil
    }

    public func object(withID id: UUID) -> WorldObject? {
        objects.first { $0.id == id }
    }

    public func object(at tile: TileCoord) -> WorldObject? {
        objects.first { $0.tiles.contains(tile) }
    }

    /// Land tile not covered by any object.
    public func isWalkable(_ tile: TileCoord) -> Bool {
        guard let terrain = terrain(at: tile), terrain.isLand else { return false }
        return object(at: tile) == nil
    }

    /// `nil` when `kind` fits at `origin`. `ignoring` lets an object be moved onto tiles it currently covers.
    public func placementIssue(for kind: ObjectKind, at origin: TileCoord, ignoring ignoredID: UUID? = nil)
        -> PlacementError?
    {
        for tile in kind.footprint.tiles(at: origin) {
            guard let terrain = terrain(at: tile) else { return .outOfBounds }
            if !kind.allowedTerrain.contains(terrain) { return .blockedByTerrain(terrain) }
            if let other = object(at: tile), other.id != ignoredID { return .overlapsObject(other.id) }
        }
        return nil
    }

    // MARK: Mutations (validated)

    public mutating func place(_ kind: ObjectKind, at origin: TileCoord, id: UUID) -> Result<
        WorldObject, PlacementError
    > {
        if let issue = placementIssue(for: kind, at: origin) { return .failure(issue) }
        let object = WorldObject(id: id, kind: kind, origin: origin)
        objects.append(object)
        relocateCreatureIfBlocked()
        return .success(object)
    }

    public mutating func moveObject(_ id: UUID, to origin: TileCoord) -> Result<WorldObject, PlacementError> {
        guard let index = objects.firstIndex(where: { $0.id == id }) else { return .failure(.unknownObject(id)) }
        if let issue = placementIssue(for: objects[index].kind, at: origin, ignoring: id) { return .failure(issue) }
        objects[index].origin = origin
        relocateCreatureIfBlocked()
        return .success(objects[index])
    }

    public mutating func removeObject(_ id: UUID) -> Result<WorldObject, PlacementError> {
        guard let index = objects.firstIndex(where: { $0.id == id }) else { return .failure(.unknownObject(id)) }
        return .success(objects.remove(at: index))
    }

    /// Replaces all objects (used by undo). Snapshots come from this same world, so they are valid by construction.
    mutating func restoreObjects(_ snapshot: [WorldObject]) {
        objects = snapshot
        relocateCreatureIfBlocked()
    }

    /// Records a reaction as discovered. Returns `true` only the first time, so replaying an event is harmless.
    @discardableResult
    public mutating func recordDiscovery(_ kind: ReactionKind) -> Bool {
        discoveries.insert(kind).inserted
    }

    /// If an object now covers the creature, hop it to the nearest walkable tile and reset its plan.
    mutating func relocateCreatureIfBlocked() {
        guard !isWalkable(creature.position) else { return }
        if let free = nearestWalkableTile(to: creature.position) {
            creature.position = free
        }
        creature.activity = .idle(ticksLeft: 1)
    }

    func nearestWalkableTile(to start: TileCoord) -> TileCoord? {
        let maxRadius = max(width, height)
        for radius in 1...maxRadius {
            let ring = (-radius...radius).flatMap { dx in
                (-radius...radius).compactMap { dy in
                    max(abs(dx), abs(dy)) == radius ? start.offset(dx: dx, dy: dy) : nil
                }
            }
            if let tile = ring.first(where: isWalkable) { return tile }
        }
        return nil
    }
}
