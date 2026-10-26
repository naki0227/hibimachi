/// Time of day used for lighting. Purely cosmetic: nothing in the rules depends on it (no night penalties).
public enum DayPhase: String, CaseIterable, Sendable {
    case morning
    case day
    case evening
    case night

    /// Phase for a local wall-clock hour (0...23). Values outside the range wrap around.
    public init(hour: Int) {
        switch ((hour % 24) + 24) % 24 {
        case 5..<9: self = .morning
        case 9..<17: self = .day
        case 17..<19: self = .evening
        default: self = .night
        }
    }

    /// Whether lamps and windows should glow.
    public var lightsOn: Bool { self == .evening || self == .night }

    /// Next phase, for the manual preview button.
    public var next: DayPhase {
        let all = Self.allCases
        return all[(all.firstIndex(of: self).map { $0 + 1 } ?? 0) % all.count]
    }
}
