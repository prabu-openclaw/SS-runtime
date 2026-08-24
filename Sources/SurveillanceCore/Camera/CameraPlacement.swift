public struct SelectedCamera: Equatable, Sendable {
    public var socketId: String
    public var entityId: EntityID
    public var housingFamily: HousingFamily
    public var zoneId: String
    public var position: VecI
    public var headingMilliDegrees: Int
    public var rangeUnits: Int
    public var fieldAngleMilliDegrees: Int
    public var tutorialEligible: Bool
    public var returnVisible: Bool
    public var integrity: Int
    public var mountCollisionRadius: Int
    public var hitRadius: Int
    public var fieldOrigin: VecQ8
    public var targetAnchor: VecQ8
    public var wasDetecting: Bool

    public var isDestroyed: Bool { integrity <= 0 }
    public var isDamageable: Bool { integrity > 0 }
}

public enum CameraPlacement {
    public static let requiredByZone: [(zone: String, count: Int)] = [
        ("Z-02", 2), ("Z-03", 1), ("Z-04", 2), ("Z-05", 2), ("Z-06", 1)
    ]

    public static func select(
        sockets: [CameraSocket],
        geometry: StandardCameraGeometry,
        runSeed: UInt64,
        allocator: inout EntityAllocator
    ) -> [SelectedCamera]? {
        var rng = Xoshiro256StarStar.cameraPlacement(runSeed: runSeed)
        let enabled = sockets.filter(\.enabled).sorted { $0.socketId.utf8LessThan($1.socketId) }
        var shuffledByZone: [String: [CameraSocket]] = [:]
        for (zone, _) in requiredByZone {
            var list = enabled.filter { $0.zoneId == zone }
            rng.shuffle(&list)
            shuffledByZone[zone] = list
        }

        var housingBySocket: [String: HousingFamily] = [:]
        for socket in enabled {
            var families = socket.allowedHousingFamilies
            rng.shuffle(&families)
            housingBySocket[socket.socketId] = families[0]
        }

        guard let chosen = search(
            zoneIndex: 0,
            selected: [],
            shuffledByZone: shuffledByZone,
            housingBySocket: housingBySocket
        ) else {
            return nil
        }

        let ordered = chosen.sorted { $0.socketId.utf8LessThan($1.socketId) }
        return ordered.map { socket in
            let heading = socket.headingMilliDegrees
            let origin = offsetPoint(socket.position, geometry.fieldOriginOffset, heading)
            let anchor = offsetPoint(socket.position, geometry.targetAnchorOffset, heading)
            return SelectedCamera(
                socketId: socket.socketId,
                entityId: allocator.next(),
                housingFamily: housingBySocket[socket.socketId]!,
                zoneId: socket.zoneId,
                position: socket.position,
                headingMilliDegrees: heading,
                rangeUnits: socket.rangeUnits,
                fieldAngleMilliDegrees: socket.fieldAngleMilliDegrees,
                tutorialEligible: socket.tutorialEligible,
                returnVisible: socket.returnVisible,
                integrity: 3,
                mountCollisionRadius: geometry.mountCollisionRadiusUnits,
                hitRadius: geometry.hitRadiusUnits,
                fieldOrigin: origin,
                targetAnchor: anchor,
                wasDetecting: false
            )
        }
    }

    private static func search(
        zoneIndex: Int,
        selected: [CameraSocket],
        shuffledByZone: [String: [CameraSocket]],
        housingBySocket: [String: HousingFamily]
    ) -> [CameraSocket]? {
        if zoneIndex == requiredByZone.count {
            return isLegal(selected, housingBySocket: housingBySocket) ? selected : nil
        }
        let spec = requiredByZone[zoneIndex]
        let pool = shuffledByZone[spec.zone] ?? []
        return choose(from: pool, need: spec.count, picked: [], rest: selected, zoneIndex: zoneIndex, shuffledByZone: shuffledByZone, housingBySocket: housingBySocket)
    }

    private static func choose(
        from pool: [CameraSocket],
        need: Int,
        picked: [CameraSocket],
        rest: [CameraSocket],
        zoneIndex: Int,
        shuffledByZone: [String: [CameraSocket]],
        housingBySocket: [String: HousingFamily]
    ) -> [CameraSocket]? {
        if picked.count == need {
            if requiredByZone[zoneIndex].zone == "Z-02",
               !picked.contains(where: \.tutorialEligible)
            {
                return nil
            }
            return search(
                zoneIndex: zoneIndex + 1,
                selected: rest + picked,
                shuffledByZone: shuffledByZone,
                housingBySocket: housingBySocket
            )
        }
        let start = picked.isEmpty ? 0 : (pool.firstIndex { $0.socketId == picked.last!.socketId } ?? -1) + 1
        if start >= pool.count { return nil }
        for i in start..<pool.count {
            let candidate = pool[i]
            let soFar = rest + picked
            if soFar.contains(where: { $0.socketId == candidate.socketId }) { continue }
            if isIncompatible(candidate, with: soFar) { continue }
            if let found = choose(
                from: pool,
                need: need,
                picked: picked + [candidate],
                rest: rest,
                zoneIndex: zoneIndex,
                shuffledByZone: shuffledByZone,
                housingBySocket: housingBySocket
            ) {
                return found
            }
        }
        return nil
    }

    private static func isIncompatible(_ candidate: CameraSocket, with selected: [CameraSocket]) -> Bool {
        let bans = Set(candidate.incompatibleSocketIds)
        return selected.contains { bans.contains($0.socketId) || $0.incompatibleSocketIds.contains(candidate.socketId) }
    }

    private static func isLegal(_ selected: [CameraSocket], housingBySocket: [String: HousingFamily]) -> Bool {
        guard selected.count == 8 else { return false }
        let families = Set(selected.map { housingBySocket[$0.socketId]! })
        let returnVisible = selected.filter(\.returnVisible).count
        return families.count >= 4 && returnVisible >= 4
    }

    private static func offsetPoint(_ origin: VecI, _ local: VecI, _ headingMilli: Int) -> VecQ8 {
        let heading = Cordic.headingUnit(milliDegrees: headingMilli)
        // local.x is right, local.y is forward along heading.
        let fx = Int64(heading.x)
        let fy = Int64(heading.y)
        let rx = fy
        let ry = -fx
        let x = Int64(origin.x) * Q8.scale
            + IntMath.mulDivHalfAway(rx, Int64(local.x) * Q8.scale, Int64(Cordic.q15))
            + IntMath.mulDivHalfAway(fx, Int64(local.y) * Q8.scale, Int64(Cordic.q15))
        let y = Int64(origin.y) * Q8.scale
            + IntMath.mulDivHalfAway(ry, Int64(local.x) * Q8.scale, Int64(Cordic.q15))
            + IntMath.mulDivHalfAway(fy, Int64(local.y) * Q8.scale, Int64(Cordic.q15))
        return VecQ8(x: Q8(raw: x), y: Q8(raw: y))
    }
}

public enum Detection {
    public static func sampleContacts(
        cameras: inout [SelectedCamera],
        player: PlayerBody,
        tick: UInt64,
        solids: [(id: String, box: AABB)]
    ) -> [EntityID] {
        guard !player.isCameraInvisible(tick: tick) else {
            for i in cameras.indices { cameras[i].wasDetecting = false }
            return []
        }
        var contacts: [EntityID] = []
        for i in cameras.indices {
            guard cameras[i].isDamageable else {
                cameras[i].wasDetecting = false
                continue
            }
            let detecting = Collision.pointInCone(
                origin: cameras[i].fieldOrigin,
                point: player.position,
                headingMilli: cameras[i].headingMilliDegrees,
                halfFieldMilli: cameras[i].fieldAngleMilliDegrees / 2,
                rangeUnits: cameras[i].rangeUnits
            ) && Collision.lineOfFireClear(from: cameras[i].fieldOrigin, to: player.position, solids: solids)
            cameras[i].wasDetecting = detecting
            if detecting { contacts.append(cameras[i].entityId) }
        }
        contacts.sort()
        return contacts
    }
}
