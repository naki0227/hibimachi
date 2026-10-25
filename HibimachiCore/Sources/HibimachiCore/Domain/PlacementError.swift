import Foundation

/// Why an object cannot be placed/moved somewhere. Shown to the player; nothing is consumed on failure.
public enum PlacementError: Error, Equatable, Sendable {
    case outOfBounds
    case blockedByTerrain(Terrain)
    case overlapsObject(UUID)
    case unknownObject(UUID)
}
