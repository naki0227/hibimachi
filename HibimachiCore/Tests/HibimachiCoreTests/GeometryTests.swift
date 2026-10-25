import Testing

@testable import HibimachiCore

@Suite("Coordinates and camera")
struct GeometryTests {
    let grid = GridGeometry(tileSize: 32, columns: 16, rows: 16)

    @Test func tileCenterRoundTrips() {
        for x in [0, 7, 15] {
            for y in [0, 9, 15] {
                let tile = TileCoord(x: x, y: y)
                #expect(grid.tile(at: grid.center(of: tile)) == tile)
            }
        }
    }

    @Test func tileEdgesBelongToTheUpperTile() {
        #expect(grid.tile(at: ScenePoint(x: 31.99, y: 0)) == TileCoord(x: 0, y: 0))
        #expect(grid.tile(at: ScenePoint(x: 32, y: 32)) == TileCoord(x: 1, y: 1))
    }

    @Test(arguments: [
        ScenePoint(x: -0.1, y: 10), ScenePoint(x: 10, y: -5), ScenePoint(x: 512, y: 10), ScenePoint(x: 10, y: 600),
    ])
    func pointsOutsideTheMapHaveNoTile(point: ScenePoint) {
        #expect(grid.tile(at: point) == nil)
    }

    @Test func dragAnchorsTwoByTwoAtItsCenter() {
        let footprint = Footprint(width: 2, height: 2)
        // Finger near the shared corner of tiles (4,4)-(5,5) → origin (4,4).
        #expect(grid.origin(for: footprint, centeredAt: ScenePoint(x: 160, y: 160)) == TileCoord(x: 4, y: 4))
        #expect(grid.center(of: footprint, at: TileCoord(x: 4, y: 4)) == ScenePoint(x: 160, y: 160))
        // 1x1 behaves like tile lookup.
        #expect(
            grid.origin(for: Footprint(width: 1, height: 1), centeredAt: ScenePoint(x: 40, y: 70))
                == TileCoord(x: 1, y: 2))
    }

    @Test func zoomIsClamped() {
        let bounds = CameraBounds(mapSize: grid.mapSize)
        #expect(bounds.clampScale(0.01) == bounds.minScale)
        #expect(bounds.clampScale(10) == bounds.maxScale)
        #expect(bounds.clampScale(1) == 1)
    }

    @Test func smallViewportCanPanButNotPastTheMargin() {
        let bounds = CameraBounds(mapSize: grid.mapSize, margin: 40)
        let viewport = SceneSize(width: 200, height: 300)
        let clamped = bounds.clampPosition(ScenePoint(x: -1_000, y: 10_000), viewport: viewport, scale: 1)
        #expect(clamped == ScenePoint(x: 100 - 40, y: 512 - 150 + 40))
        let inside = ScenePoint(x: 256, y: 256)
        #expect(bounds.clampPosition(inside, viewport: viewport, scale: 1) == inside)
    }

    @Test func zoomedOutViewKeepsTheMapCentered() {
        let bounds = CameraBounds(mapSize: grid.mapSize, margin: 40)
        let clamped = bounds.clampPosition(
            ScenePoint(x: 0, y: 0), viewport: SceneSize(width: 400, height: 800), scale: 1.5)
        #expect(clamped == ScenePoint(x: 256, y: 256))
    }

    @Test func fittingScaleShowsTheWholeIslandOnAPhone() {
        let bounds = CameraBounds(mapSize: grid.mapSize, margin: 48)
        let scale = bounds.fittingScale(for: SceneSize(width: 375, height: 667))
        #expect(abs(scale - 608.0 / 375.0) < 0.0001)
        #expect(bounds.fittingScale(for: SceneSize(width: 0, height: 0)) == bounds.maxScale)
    }
}
