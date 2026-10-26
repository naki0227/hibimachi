public enum Terrain: Character, CaseIterable, Sendable {
    case grass = "g"
    case path = "p"
    case water = "w"

    /// The creature can walk on land only. Objects additionally block tiles (see `World.isWalkable`).
    public var isLand: Bool { self != .water }
}
