import Foundation

/// How close a resident and the player are. Grows by petting (a few times a day) and by the discoveries the
/// resident makes on the player's island; it never goes down, so a day away costs nothing.
public struct Friendship: Equatable, Sendable {
    public enum Level: Int, Comparable, CaseIterable, Sendable {
        case new
        /// なかよし
        case friend
        /// だいすき
        case bestFriend

        public static func < (lhs: Level, rhs: Level) -> Bool { lhs.rawValue < rhs.rawValue }

        /// Points needed to reach this level.
        public var threshold: Int {
            switch self {
            case .new: 0
            case .friend: 6
            case .bestFriend: 20
            }
        }
    }

    /// Petting counts at most this many times per resident per day; more taps are still welcome, just not counted.
    public static let petsPerDay = 3
    public static let pointsPerPet = 1
    public static let pointsPerDiscovery = 2

    public private(set) var points: Int
    /// The day of the last counted pet and how many were counted that day.
    public private(set) var petDay: LocalDay?
    public private(set) var petsOnPetDay: Int

    public init(points: Int = 0, petDay: LocalDay? = nil, petsOnPetDay: Int = 0) {
        self.points = max(points, 0)
        self.petDay = petDay
        self.petsOnPetDay = petDay == nil ? 0 : min(max(petsOnPetDay, 0), Self.petsPerDay)
    }

    public var level: Level {
        Level.allCases.last { points >= $0.threshold } ?? .new
    }

    /// Points still needed for the next level, or `nil` at the top.
    public var pointsToNextLevel: Int? {
        Level(rawValue: level.rawValue + 1).map { $0.threshold - points }
    }

    /// Counts a pet unless today's are used up. Returns whether it counted.
    public mutating func pet(on day: LocalDay) -> Bool {
        if petDay != day {
            petDay = day
            petsOnPetDay = 0
        }
        guard petsOnPetDay < Self.petsPerDay else { return false }
        petsOnPetDay += 1
        points += Self.pointsPerPet
        return true
    }

    public mutating func addDiscovery() {
        points += Self.pointsPerDiscovery
    }
}
