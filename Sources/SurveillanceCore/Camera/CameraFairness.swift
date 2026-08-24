/// Exhaustive Camera fairness for content CI (CP-010). Never called from `ArenaManifest.bundled()` or `Simulation.make`.
public enum CameraFairness {
    public struct Report: Equatable, Sendable {
        public var legalSetCount: Int
        public var protectedZ01Keys: [String]
        public var chokeKeys: [String]
        public var pulseStandKeys: [String]
        public var zeroContactRouteKeys: [String]
        public var z04BranchKeys: [String]
        public var captainSafeKeys: [String]
        public var extractionKeys: [String]
        public var accessibilityKeys: [String]
        public var fieldOriginKeys: [String]
        public var overlapKeys: [String]
    }

    public static func evaluate(_ manifest: ArenaManifest) -> Report {
        let sockets = manifest.cameraSockets.filter(\.enabled)
        let legal = CameraPlacement.enumerateLegalSocketSets(sockets)
        let geometry = manifest.standardCameraGeometry
        let solids = manifest.solidsForCollision
        let step = ArenaReachability.gridStep
        let cols = (manifest.boundsUnits.maxX / step) + 1
        let rows = (manifest.boundsUnits.maxY / step) + 1
        let cellCount = cols * rows
        let bounds = ArenaReachability.boundsBox(manifest)
        let solidBoxes = ArenaReachability.boxes(manifest)
        let spawn = VecI(x: manifest.playerSpawn.x, y: manifest.playerSpawn.y)
        let spawnFlood = ArenaReachability.flood(
            from: spawn,
            radius: PlayerBody.radiusUnits,
            manifest: manifest
        )
        let z01 = ArenaReachability.zone(manifest, id: "Z-01")?.aabb
        let court = ArenaReachability.zone(manifest, id: "Z-06")?.aabb

        var walkable = BitGrid(cellCount: cellCount)
        var z01Walkable = BitGrid(cellCount: cellCount)
        var reachable = BitGrid(cellCount: cellCount)
        var zoneCells: [String: BitGrid] = [:]
        for id in ArenaReachability.consecutiveZoneIDs {
            zoneCells[id] = BitGrid(cellCount: cellCount)
        }

        for gy in 0..<rows {
            for gx in 0..<cols {
                let i = gy * cols + gx
                let point = VecI(x: gx * step, y: gy * step)
                if ArenaReachability.isWalkable(point, radius: PlayerBody.radiusUnits, bounds: bounds, solids: solidBoxes) {
                    walkable.insert(i)
                    if spawnFlood.containsGrid(x: gx, y: gy) { reachable.insert(i) }
                    if let z01, z01.contains(point) { z01Walkable.insert(i) }
                    for id in ArenaReachability.consecutiveZoneIDs {
                        if let zone = ArenaReachability.zone(manifest, id: id), zone.aabb.contains(point) {
                            if var grid = zoneCells[id] {
                                grid.insert(i)
                                zoneCells[id] = grid
                            }
                        }
                    }
                }
            }
        }

        var prep: [String: SocketPrep] = [:]
        for socket in sockets {
            let origin = CameraPlacement.fieldOrigin(socket: socket, geometry: geometry)
            let anchor = CameraPlacement.targetAnchor(socket: socket, geometry: geometry)
            let originPoint = VecI(x: origin.x.unitsTruncated, y: origin.y.unitsTruncated)
            let originInSolid = solidBoxes.contains { $0.contains(originPoint) }
            let mount = Circle(center: socket.position.asQ8, radiusUnits: geometry.mountCollisionRadiusUnits)
            let mountInZ01 = z01.map { mount.penetrates($0) } ?? false
            var field = BitGrid(cellCount: cellCount)
            var pulse = BitGrid(cellCount: cellCount)
            let rangeSq = Int64(Targeting.civicPulseRange) * Int64(Targeting.civicPulseRange) * Q8.scale * Q8.scale
            for gy in 0..<rows {
                for gx in 0..<cols {
                    let i = gy * cols + gx
                    let point = VecI(x: gx * step, y: gy * step)
                    let q = point.asQ8
                    if Collision.pointInCone(
                        origin: origin,
                        point: q,
                        headingMilli: socket.headingMilliDegrees,
                        halfFieldMilli: socket.fieldAngleMilliDegrees / 2,
                        rangeUnits: socket.rangeUnits
                    ), Collision.lineOfFireClear(from: origin, to: q, solids: solids) {
                        field.insert(i)
                    }
                    if walkable.contains(i),
                       point.asQ8.distanceSquared(to: anchor) <= rangeSq,
                       Collision.lineOfFireClear(from: q, to: anchor, solids: solids)
                    {
                        pulse.insert(i)
                    }
                }
            }
            prep[socket.socketId] = SocketPrep(
                id: socket.socketId,
                originInSolid: originInSolid,
                mountInZ01: mountInZ01,
                field: field,
                pulse: pulse,
                position: socket.position
            )
        }

        let chokes = chokeRegions(manifest)
        let westBranch = VecI(x: 1248, y: 1088)
        let eastBranch = VecI(x: 1536, y: 1088)
        let extract = manifest.extraction.center
        let boss = VecI(x: manifest.bossSpawn.x, y: manifest.bossSpawn.y)

        var report = Report(
            legalSetCount: legal.count,
            protectedZ01Keys: [],
            chokeKeys: [],
            pulseStandKeys: [],
            zeroContactRouteKeys: [],
            z04BranchKeys: [],
            captainSafeKeys: [],
            extractionKeys: [],
            accessibilityKeys: [],
            fieldOriginKeys: [],
            overlapKeys: []
        )

        for set in legal {
            let key = CameraPlacement.setKey(set)
            let selected = set.compactMap { prep[$0.socketId] }
            var unionField = BitGrid(cellCount: cellCount)
            for camera in selected { unionField.formUnion(camera.field) }

            if selected.contains(where: \.mountInZ01) || z01Walkable.intersects(unionField) {
                report.protectedZ01Keys.append(key)
            }

            if chokeViolated(chokes, fields: selected.map(\.field), cols: cols, rows: rows, step: step) {
                report.chokeKeys.append(key)
            }

            var pulseFail = false
            var accessFail = false
            for camera in selected {
                let stands = camera.pulse.intersection(reachable)
                if stands.isEmpty { pulseFail = true }
                if !stands.intersects(walkable) { accessFail = true }
            }
            if pulseFail { report.pulseStandKeys.append(key) }
            if accessFail { report.accessibilityKeys.append(key) }

            if zeroContactMissing(
                zoneCells: zoneCells,
                walkable: walkable,
                blocked: unionField,
                cols: cols,
                rows: rows
            ) {
                report.zeroContactRouteKeys.append(key)
            }

            if branchBlocked(
                west: westBranch,
                east: eastBranch,
                trigger: manifest.encounterTriggers.first { $0.encounterId == "M-B" }?.center ?? VecI(x: 1280, y: 1088),
                walkable: walkable,
                blocked: unionField,
                cols: cols,
                rows: rows,
                step: step
            ) {
                report.z04BranchKeys.append(key)
            }

            let mounts = set.map {
                AABB(
                    center: $0.position,
                    halfSize: VecI(x: geometry.mountCollisionRadiusUnits, y: geometry.mountCollisionRadiusUnits)
                )
            }
            let captainFlood = ArenaReachability.flood(
                from: boss,
                radius: ArenaReachability.bossCorridorRadius,
                manifest: manifest,
                extraSolids: mounts
            )
            let courtReachable = court.map { captainFlood.intersects($0) } ?? false
            var uncoveredCourt = false
            if let court {
                for gy in 0..<rows {
                    for gx in 0..<cols {
                        let point = VecI(x: gx * step, y: gy * step)
                        let i = gy * cols + gx
                        if court.contains(point), walkable.contains(i), !unionField.contains(i) {
                            uncoveredCourt = true
                            break
                        }
                    }
                    if uncoveredCourt { break }
                }
            }
            if !captainFlood.originWalkable || !courtReachable || !uncoveredCourt {
                report.captainSafeKeys.append(key)
            }

            if !spawnFlood.containsPoint(extract) {
                report.extractionKeys.append(key)
            }

            if selected.contains(where: \.originInSolid) {
                report.fieldOriginKeys.append(key)
            }

            if mountsOverlap(set, geometry: geometry) {
                report.overlapKeys.append(key)
            }
        }

        return report
    }

    private static func chokeRegions(_ manifest: ArenaManifest) -> [AABB] {
        var regions = manifest.gates.map(\.aabb)
        let ids = ArenaReachability.consecutiveZoneIDs
        for (aID, bID) in zip(ids, ids.dropFirst()) {
            guard let a = ArenaReachability.zone(manifest, id: aID),
                  let b = ArenaReachability.zone(manifest, id: bID),
                  let overlap = intersection(a.aabb, b.aabb)
            else { continue }
            regions.append(overlap)
        }
        return regions
    }

    private static func chokeViolated(
        _ chokes: [AABB],
        fields: [BitGrid],
        cols: Int,
        rows: Int,
        step: Int
    ) -> Bool {
        for choke in chokes {
            let minGX = max(0, choke.minX / step)
            let maxGX = min(cols - 1, choke.maxX / step)
            let minGY = max(0, choke.minY / step)
            let maxGY = min(rows - 1, choke.maxY / step)
            guard minGX <= maxGX, minGY <= maxGY else { continue }
            for gy in minGY...maxGY {
                for gx in minGX...maxGX {
                    let point = VecI(x: gx * step, y: gy * step)
                    guard choke.contains(point) else { continue }
                    let i = gy * cols + gx
                    var cover = 0
                    for field in fields where field.contains(i) {
                        cover += 1
                        if cover > 2 { return true }
                    }
                }
            }
        }
        return false
    }

    private static func zeroContactMissing(
        zoneCells: [String: BitGrid],
        walkable: BitGrid,
        blocked: BitGrid,
        cols: Int,
        rows: Int
    ) -> Bool {
        for (aID, bID) in zip(ArenaReachability.consecutiveZoneIDs, ArenaReachability.consecutiveZoneIDs.dropFirst()) {
            guard let a = zoneCells[aID], let b = zoneCells[bID] else { return true }
            let start = a.intersection(walkable).subtracting(blocked)
            if start.isEmpty { return true }
            let reached = flood(start: start, walkable: walkable, blocked: blocked, cols: cols, rows: rows)
            if !reached.intersects(b.intersection(walkable).subtracting(blocked)) {
                return true
            }
        }
        return false
    }

    private static func branchBlocked(
        west: VecI,
        east: VecI,
        trigger: VecI,
        walkable: BitGrid,
        blocked: BitGrid,
        cols: Int,
        rows: Int,
        step: Int
    ) -> Bool {
        let startIndex = (trigger.y / step) * cols + (trigger.x / step)
        var start = BitGrid(cellCount: walkable.cellCount)
        if walkable.contains(startIndex) { start.insert(startIndex) }
        if start.isEmpty { return true }
        let reached = flood(start: start, walkable: walkable, blocked: blocked, cols: cols, rows: rows)
        let westIndex = (west.y / step) * cols + (west.x / step)
        let eastIndex = (east.y / step) * cols + (east.x / step)
        return !reached.contains(westIndex) || !reached.contains(eastIndex)
    }

    private static func flood(
        start: BitGrid,
        walkable: BitGrid,
        blocked: BitGrid,
        cols: Int,
        rows: Int
    ) -> BitGrid {
        var seen = BitGrid(cellCount: walkable.cellCount)
        var queue: [Int] = []
        for i in 0..<walkable.cellCount where start.contains(i) && walkable.contains(i) && !blocked.contains(i) {
            seen.insert(i)
            queue.append(i)
        }
        var cursor = 0
        while cursor < queue.count {
            let i = queue[cursor]
            cursor += 1
            let gx = i % cols
            let gy = i / cols
            for (nx, ny) in [(gx + 1, gy), (gx - 1, gy), (gx, gy + 1), (gx, gy - 1)] {
                guard nx >= 0, ny >= 0, nx < cols, ny < rows else { continue }
                let n = ny * cols + nx
                if seen.contains(n) || !walkable.contains(n) || blocked.contains(n) { continue }
                seen.insert(n)
                queue.append(n)
            }
        }
        return seen
    }

    private static func mountsOverlap(_ sockets: [CameraSocket], geometry: StandardCameraGeometry) -> Bool {
        for i in sockets.indices {
            for j in sockets.indices where j > i {
                if circlesOverlap(
                    sockets[i].position,
                    geometry.mountCollisionRadiusUnits,
                    sockets[j].position,
                    geometry.mountCollisionRadiusUnits
                ) { return true }
                if circlesOverlap(
                    sockets[i].position,
                    geometry.hitRadiusUnits,
                    sockets[j].position,
                    geometry.hitRadiusUnits
                ) { return true }
            }
        }
        return false
    }

    private static func circlesOverlap(_ a: VecI, _ ra: Int, _ b: VecI, _ rb: Int) -> Bool {
        let dx = Int64(a.x - b.x)
        let dy = Int64(a.y - b.y)
        let r = Int64(ra + rb)
        return dx * dx + dy * dy < r * r
    }

    private static func intersection(_ a: AABB, _ b: AABB) -> AABB? {
        let minX = max(a.minX, b.minX)
        let maxX = min(a.maxX, b.maxX)
        let minY = max(a.minY, b.minY)
        let maxY = min(a.maxY, b.maxY)
        guard minX <= maxX, minY <= maxY else { return nil }
        return AABB(
            center: VecI(x: (minX + maxX) / 2, y: (minY + maxY) / 2),
            halfSize: VecI(x: (maxX - minX) / 2, y: (maxY - minY) / 2)
        )
    }
}

private struct SocketPrep {
    var id: String
    var originInSolid: Bool
    var mountInZ01: Bool
    var field: BitGrid
    var pulse: BitGrid
    var position: VecI
}

private struct BitGrid: Equatable, Sendable {
    var words: [UInt64]
    let cellCount: Int

    init(cellCount: Int) {
        self.cellCount = cellCount
        words = [UInt64](repeating: 0, count: (cellCount + 63) / 64)
    }

    func contains(_ index: Int) -> Bool {
        guard index >= 0, index < cellCount else { return false }
        return words[index >> 6] & (UInt64(1) << (index & 63)) != 0
    }

    mutating func insert(_ index: Int) {
        guard index >= 0, index < cellCount else { return }
        words[index >> 6] |= UInt64(1) << (index & 63)
    }

    var isEmpty: Bool {
        words.allSatisfy { $0 == 0 }
    }

    func intersects(_ other: BitGrid) -> Bool {
        for i in words.indices where words[i] & other.words[i] != 0 {
            return true
        }
        return false
    }

    mutating func formUnion(_ other: BitGrid) {
        for i in words.indices { words[i] |= other.words[i] }
    }

    func intersection(_ other: BitGrid) -> BitGrid {
        var result = self
        for i in words.indices { result.words[i] &= other.words[i] }
        return result
    }

    func subtracting(_ other: BitGrid) -> BitGrid {
        var result = self
        for i in words.indices { result.words[i] &= ~other.words[i] }
        return result
    }
}
