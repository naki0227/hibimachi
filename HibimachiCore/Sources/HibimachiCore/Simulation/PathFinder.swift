/// Breadth-first search on the 16x16-ish grid. Cheap enough per decision; no heuristics needed in P0.
public enum PathFinder {
    /// Shortest path from `start` to the first tile satisfying `isGoal`, excluding `start`.
    /// Returns `[]` when `start` itself is a goal and `nil` when no goal is reachable.
    public static func path(
        in world: World,
        from start: TileCoord,
        where isGoal: (TileCoord) -> Bool
    ) -> [TileCoord]? {
        if isGoal(start) { return [] }
        var previous: [TileCoord: TileCoord] = [start: start]
        var queue = [start]
        var head = 0
        while head < queue.count {
            let current = queue[head]
            head += 1
            for next in current.neighbors where previous[next] == nil && world.isWalkable(next) {
                previous[next] = current
                if isGoal(next) { return reconstruct(to: next, start: start, previous: previous) }
                queue.append(next)
            }
        }
        return nil
    }

    private static func reconstruct(
        to goal: TileCoord,
        start: TileCoord,
        previous: [TileCoord: TileCoord]
    ) -> [TileCoord] {
        var path = [goal]
        var current = goal
        while let step = previous[current], step != start {
            path.append(step)
            current = step
        }
        return path.reversed()
    }
}
