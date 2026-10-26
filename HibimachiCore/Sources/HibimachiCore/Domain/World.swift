import Foundation

public enum WorldValidationError: Error, Equatable, Sendable {
    case invalidSize
    case terrainCountMismatch(expected: Int, actual: Int)
    case duplicateObjectID(UUID)
    case invalidObject(UUID, PlacementError)
    case creatureOutOfBounds
    case duplicateResident(UUID)
}

/// The whole persisted island: terrain, placed objects, the residents and discovered reactions.
/// Every initialiser path validates invariants, so a `World` value is always consistent.
public struct World: Equatable, Sendable {
    public private(set) var width: Int
    public private(set) var height: Int
    /// Row-major terrain, index = y * width + x. Only grass <-> path can change (painting paths).
    public private(set) var terrain: [Terrain]
    public private(set) var objects: [WorldObject]
    /// Everyone living on the island; never empty. The first is the original resident.
    public internal(set) var residents: [Creature]
    public private(set) var discoveries: Set<ReactionKind>
    /// How many times the island has grown (`IslandGrowth`); its coast moves out one ring each time.
    public private(set) var growthStage: Int

    /// The original resident (kept as a shortcut: most rules and the tutorial talk about "the creature").
    public var creature: Creature {
        get { residents[0] }
        set { residents[0] = newValue }
    }

    public init(
        width: Int,
        height: Int,
        terrain: [Terrain],
        objects: [WorldObject],
        creature: Creature,
        otherResidents: [Creature] = [],
        discoveries: Set<ReactionKind> = [],
        growthStage: Int = 0
    ) throws(WorldValidationError) {
        guard width > 0, height > 0 else { throw .invalidSize }
        guard terrain.count == width * height else {
            throw .terrainCountMismatch(expected: width * height, actual: terrain.count)
        }
        self.width = width
        self.height = height
        self.terrain = terrain
        self.objects = []
        self.residents = [creature] + otherResidents
        self.discoveries = discoveries
        self.growthStage = max(growthStage, 0)
        for object in objects {
            guard self.object(withID: object.id) == nil else { throw .duplicateObjectID(object.id) }
            if let issue = placementIssue(for: object.kind, at: object.origin) {
                throw .invalidObject(object.id, issue)
            }
            self.objects.append(object)
        }
        var seen = Set<UUID>()
        for resident in residents {
            guard contains(resident.position) else { throw .creatureOutOfBounds }
            guard seen.insert(resident.id).inserted else { throw .duplicateResident(resident.id) }
        }
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

    public mutating func place(_ kind: ObjectKind, at origin: TileCoord, id: UUID, placedAt: Date? = nil)
        -> Result<WorldObject, PlacementError>
    {
        if let issue = placementIssue(for: kind, at: origin) { return .failure(issue) }
        let object = WorldObject(id: id, kind: kind, origin: origin, placedAt: placedAt)
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

    /// Why the tile cannot be switched between grass and path, or `nil` if it can. Water never changes,
    /// and an object standing there must accept the new terrain (a house cannot end up on a path).
    public func pathToggleIssue(at tile: TileCoord) -> PlacementError? {
        guard let current = terrain(at: tile) else { return .outOfBounds }
        guard current != .water else { return .blockedByTerrain(.water) }
        let target: Terrain = current == .path ? .grass : .path
        if let object = object(at: tile), !object.kind.allowedTerrain.contains(target) {
            return .overlapsObject(object.id)
        }
        return nil
    }

    /// Switches grass <-> path. Returns the new terrain.
    public mutating func togglePath(at tile: TileCoord) -> Result<Terrain, PlacementError> {
        if let issue = pathToggleIssue(at: tile) { return .failure(issue) }
        let index = tile.y * width + tile.x
        terrain[index] = terrain[index] == .path ? .grass : .path
        return .success(terrain[index])
    }

    /// Restores objects and terrain (used by undo). Snapshots come from this same world, so they are valid.
    mutating func restore(objects snapshot: [WorldObject], terrain snapshotTerrain: [Terrain]) {
        objects = snapshot
        terrain = snapshotTerrain
        relocateCreatureIfBlocked()
    }

    /// The same island on a larger sea: every tile, object and resident shifts by the added margin, so the
    /// island stays in the middle. Used once to move 16x16 saves onto the 20x20 map (2026-10-26).
    public func padded(toSize size: Int) -> World {
        let margin = (size - max(width, height)) / 2
        guard margin > 0 else { return self }
        var copy = self
        copy.terrain = (0..<size).flatMap { y in
            (0..<size).map { x in terrain(at: TileCoord(x: x - margin, y: y - margin)) ?? .water }
        }
        copy.objects = objects.map { object in
            var moved = object
            moved.origin = object.origin.offset(dx: margin, dy: margin)
            return moved
        }
        copy.residents = residents.map { resident in
            var moved = resident
            moved.position = resident.position.offset(dx: margin, dy: margin)
            return moved
        }
        copy.width = size
        copy.height = size
        return copy
    }

    /// Side (in tiles) of the smallest square around all land, for framing the island on screen.
    public var landSpan: Int {
        let land = (0..<height).flatMap { y in (0..<width).map { TileCoord(x: $0, y: y) } }
            .filter { terrain(at: $0)?.isLand == true }
        guard let minX = land.map(\.x).min(), let maxX = land.map(\.x).max(),
            let minY = land.map(\.y).min(), let maxY = land.map(\.y).max()
        else { return max(width, height) }
        return max(maxX - minX, maxY - minY) + 1
    }

    /// Water tiles the coast would grow into: next to land (sides only) and not on the map's outer edge, so the
    /// island always keeps some sea around it.
    public var growthRing: [TileCoord] {
        (1..<(height - 1)).flatMap { y in
            (1..<(width - 1)).compactMap { x -> TileCoord? in
                let tile = TileCoord(x: x, y: y)
                guard terrain(at: tile) == .water else { return nil }
                let touchesLand = [(1, 0), (-1, 0), (0, 1), (0, -1)].contains { dx, dy in
                    terrain(at: tile.offset(dx: dx, dy: dy))?.isLand == true
                }
                return touchesLand ? tile : nil
            }
        }
    }

    /// Turns the growth ring into grass and counts a stage. Returns the new land.
    @discardableResult
    public mutating func grow() -> [TileCoord] {
        let ring = growthRing
        for tile in ring { terrain[tile.y * width + tile.x] = .grass }
        growthStage += 1
        return ring
    }

    /// Records a reaction as discovered. Returns `true` only the first time, so replaying an event is harmless.
    @discardableResult
    public mutating func recordDiscovery(_ kind: ReactionKind) -> Bool {
        discoveries.insert(kind).inserted
    }

    /// If an object now covers a resident, hop it to the nearest walkable tile and reset its plan.
    mutating func relocateCreatureIfBlocked() {
        for index in residents.indices where !isWalkable(residents[index].position) {
            if let free = nearestWalkableTile(to: residents[index].position) {
                residents[index].position = free
            }
            residents[index].activity = .idle(ticksLeft: 1)
        }
    }

    /// Moves in every species whose arrival condition is met and that does not live here yet.
    /// Newcomers appear on a free tile next to the first resident. Returns who arrived.
    public mutating func welcomeResidentsIfDue(makeID: () -> UUID) -> [Creature] {
        var arrived: [Creature] = []
        for species in Species.allCases
        where discoveries.count >= species.arrivalDiscoveries && !residents.contains(where: { $0.species == species }) {
            let taken = Set(residents.map(\.position))
            let start = creature.position
            let spot =
                nearestTile(to: start) { isWalkable($0) && !taken.contains($0) } ?? creature.position
            let newcomer = Creature(id: makeID(), species: species, position: spot)
            residents.append(newcomer)
            arrived.append(newcomer)
        }
        return arrived
    }

    func nearestWalkableTile(to start: TileCoord) -> TileCoord? {
        nearestTile(to: start, where: isWalkable)
    }

    func nearestTile(to start: TileCoord, where accepts: (TileCoord) -> Bool) -> TileCoord? {
        let maxRadius = max(width, height)
        for radius in 1...maxRadius {
            let ring = (-radius...radius).flatMap { dx in
                (-radius...radius).compactMap { dy in
                    max(abs(dx), abs(dy)) == radius ? start.offset(dx: dx, dy: dy) : nil
                }
            }
            if let tile = ring.first(where: accepts) { return tile }
        }
        return nil
    }
}
