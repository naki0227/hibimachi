import Testing

@testable import HibimachiCore

@Suite("Isometric coordinates and camera")
struct GeometryTests {
    let grid = IsoGrid(tileWidth: 64, tileHeight: 32, columns: 16, rows: 16, baseHeight: 48)

    @Test func mapSizeCoversTheDiamondAndCliffs() {
        #expect(grid.mapSize == SceneSize(width: 1024, height: 16 * 32 + 48))
    }

    @Test func cornersProjectToTheDiamondVertices() {
        // Front (bottom), right, back (top) and left corners of the whole map.
        #expect(grid.point(x: 0, y: 0) == ScenePoint(x: 512, y: 48))
        #expect(grid.point(x: 16, y: 0) == ScenePoint(x: 1024, y: 48 + 256))
        #expect(grid.point(x: 16, y: 16) == ScenePoint(x: 512, y: 48 + 512))
        #expect(grid.point(x: 0, y: 16) == ScenePoint(x: 0, y: 48 + 256))
    }

    @Test func tileCenterRoundTrips() {
        for x in [0, 7, 15] {
            for y in [0, 9, 15] {
                let tile = TileCoord(x: x, y: y)
                #expect(grid.tile(at: grid.center(of: tile)) == tile)
            }
        }
    }

    @Test func pointsJustInsideADiamondEdgeBelongToThatTile() {
        let center = grid.center(of: TileCoord(x: 4, y: 4))
        // Just inside the right vertex (half width minus a little) is still the same tile.
        #expect(grid.tile(at: ScenePoint(x: center.x + 31, y: center.y)) == TileCoord(x: 4, y: 4))
        // Just past the top vertex is the tile behind (x+1, y+1).
        #expect(grid.tile(at: ScenePoint(x: center.x, y: center.y + 17)) == TileCoord(x: 5, y: 5))
    }

    @Test(arguments: [
        ScenePoint(x: 512, y: 47), ScenePoint(x: 0, y: 0), ScenePoint(x: 1024, y: 600), ScenePoint(x: 2, y: 302),
    ])
    func pointsOutsideTheIslandHaveNoTile(point: ScenePoint) {
        #expect(grid.tile(at: point) == nil)
    }

    @Test func dragAnchorsTwoByTwoAtItsCenter() {
        let footprint = Footprint(width: 2, height: 2)
        let center = grid.center(of: footprint, at: TileCoord(x: 4, y: 4))
        #expect(center == grid.point(x: 5, y: 5))
        #expect(grid.origin(for: footprint, centeredAt: center) == TileCoord(x: 4, y: 4))
        let single = Footprint(width: 1, height: 1)
        #expect(grid.origin(for: single, centeredAt: grid.center(of: TileCoord(x: 1, y: 2))) == TileCoord(x: 1, y: 2))
    }

    @Test func nearerObjectsDrawOnTop() {
        let one = Footprint(width: 1, height: 1)
        let front = grid.depth(of: one, at: TileCoord(x: 2, y: 2))
        let back = grid.depth(of: one, at: TileCoord(x: 3, y: 3))
        #expect(front > back)
        // A 2x2 house at (3,3) sorts like its center (4,4): behind (3,3)'s neighbour in front, ahead of (5,5).
        let house = grid.depth(of: Footprint(width: 2, height: 2), at: TileCoord(x: 3, y: 3))
        #expect(house < front && house > grid.depth(of: one, at: TileCoord(x: 5, y: 5)))
    }

    @Test func zoomIsClamped() {
        let bounds = CameraBounds(mapSize: grid.mapSize)
        #expect(bounds.clampScale(0.01) == bounds.minScale)
        #expect(bounds.clampScale(10) == bounds.maxScale)
        #expect(bounds.clampScale(1) == 1)
    }

    @Test func smallViewportCanPanButNotPastTheMargin() {
        let bounds = CameraBounds(mapSize: SceneSize(width: 512, height: 512), margin: 40)
        let viewport = SceneSize(width: 200, height: 300)
        let clamped = bounds.clampPosition(ScenePoint(x: -1_000, y: 10_000), viewport: viewport, scale: 1)
        #expect(clamped == ScenePoint(x: 100 - 40, y: 512 - 150 + 40))
        let inside = ScenePoint(x: 256, y: 256)
        #expect(bounds.clampPosition(inside, viewport: viewport, scale: 1) == inside)
    }

    @Test func zoomedOutViewKeepsTheMapCentered() {
        let bounds = CameraBounds(mapSize: SceneSize(width: 512, height: 512), margin: 40)
        let clamped = bounds.clampPosition(
            ScenePoint(x: 0, y: 0), viewport: SceneSize(width: 400, height: 800), scale: 1.5)
        #expect(clamped == ScenePoint(x: 256, y: 256))
    }

    @Test func fittingScaleShowsTheWholeIslandOnAPhone() {
        let bounds = CameraBounds(mapSize: grid.mapSize, margin: 48)
        let scale = bounds.fittingScale(for: SceneSize(width: 390, height: 844))
        #expect(abs(scale - (1024.0 + 96) / 390) < 0.0001 || scale == bounds.maxScale)
        #expect(bounds.fittingScale(for: SceneSize(width: 0, height: 0)) == bounds.maxScale)
    }
}

@Suite("Day phase")
struct DayPhaseTests {
    @Test(arguments: [
        (5, DayPhase.morning), (8, .morning), (9, .day), (16, .day), (17, .evening), (19, .night), (0, .night),
        (4, .night), (-1, .night), (29, .morning),
    ])
    func phaseForHour(hour: Int, expected: DayPhase) {
        #expect(DayPhase(hour: hour) == expected)
    }

    @Test func lightsOnlyInTheEveningAndAtNight() {
        #expect(DayPhase.allCases.filter(\.lightsOn) == [.evening, .night])
    }

    @Test func previewCyclesThroughAllPhases() {
        var phase = DayPhase.morning
        var seen: [DayPhase] = []
        for _ in 0..<4 {
            seen.append(phase)
            phase = phase.next
        }
        #expect(seen == DayPhase.allCases && phase == .morning)
    }
}
