import Foundation

/// The island's own diary: one picture of the island per day, kept as files next to the photos (TODO
/// "街の歴史の振り返り"). The app writes today's picture when it leaves the foreground; this type only names the
/// files and decides which are old enough to remove. Nothing about it is in the save file.
public enum IslandDiary {
    /// About four months of pictures (a few hundred KB each).
    public static let keepDays = 120
    private static let prefix = "island-"
    private static let suffix = ".png"

    public static func fileName(for day: LocalDay) -> String { "\(prefix)\(day.description)\(suffix)" }

    /// The day a file belongs to, or `nil` for anything that is not a diary picture.
    public static func day(fromFileName name: String) -> LocalDay? {
        guard name.hasPrefix(prefix), name.hasSuffix(suffix) else { return nil }
        let middle = name.dropFirst(prefix.count).dropLast(suffix.count)
        guard let day = LocalDay(string: String(middle)), fileName(for: day) == name else { return nil }
        return day
    }

    /// Diary files older than `keepDays`; other files in the folder are never touched.
    public static func filesToRemove(_ names: [String], today: LocalDay) -> [String] {
        names.filter { name in
            guard let day = day(fromFileName: name) else { return false }
            return today.daysSince(day) >= keepDays
        }
    }
}
