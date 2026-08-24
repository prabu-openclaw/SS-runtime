import Foundation

public enum MusicState: String, Equatable, Sendable {
    case explore
    case observed
    case lockdown
    case boss
    case extraction
    case terminal
}

public enum HapticPattern: String, Equatable, Sendable {
    case none
    case light
    case warning
    case rigid
    case heavy
    case success
}

public struct PresentationAudioSettings: Equatable, Sendable {
    public var effectsEnabled: Bool
    public var hapticsEnabled: Bool
    public var musicEnabled: Bool
    public var reducedSensory: Bool

    public init(
        effectsEnabled: Bool = true,
        hapticsEnabled: Bool = true,
        musicEnabled: Bool = true,
        reducedSensory: Bool = false
    ) {
        self.effectsEnabled = effectsEnabled
        self.hapticsEnabled = hapticsEnabled
        self.musicEnabled = musicEnabled
        self.reducedSensory = reducedSensory
    }

    public static let enabled = PresentationAudioSettings()
    public static let disabled = PresentationAudioSettings(
        effectsEnabled: false,
        hapticsEnabled: false,
        musicEnabled: false
    )
}

public struct ProjectedCue: Equatable, Sendable {
    public var audioId: String
    public var haptic: HapticPattern
    public var caption: String
    public var priority: Int
    public var consumesEffectVoice: Bool
    public var sourceEntityId: EntityID?
    public var sector: Int?
    public var sequence: Int
    public var variant: Int?
}

public struct AudioProjection: Equatable, Sendable {
    public var cues: [ProjectedCue]
    public var musicState: MusicState
    public var captions: [String]
}

public struct AudioProjector: Equatable, Sendable {
    public var lastWeaponVoiceTick: UInt64?
    public var lastPlayerDamageTick: UInt64?
    public var lastDisplayedCountdown: Int?
    public var captionHistory: [String]
    public var nextSequence: Int

    public init() {
        lastWeaponVoiceTick = nil
        lastPlayerDamageTick = nil
        lastDisplayedCountdown = nil
        captionHistory = []
        nextSequence = 0
    }

    public mutating func reset() {
        self = AudioProjector()
    }

    public mutating func project(
        tick: UInt64,
        events: [AuthoritativeEvent],
        state: WorldState,
        settings: PresentationAudioSettings = .enabled
    ) -> AudioProjection {
        var candidates: [ProjectedCue] = []
        let cameraHits = events.filter { $0.type == .cameraIntegrityChanged }
        let destroyed = events.filter { $0.type == .cameraDestroyed }
        let cameraIDsHit = Set(cameraHits.compactMap { payloadString($0, "cameraId") })

        appendWeapon(tick: tick, events: events, into: &candidates)
        appendImpacts(events: events, playerId: state.player.id, cameraIDsHit: cameraIDsHit, into: &candidates)
        appendPlayerDamage(tick: tick, events: events, into: &candidates)
        appendDodge(events: events, into: &candidates)
        appendCameraHits(cameraHits, into: &candidates)
        appendCameraDestructions(destroyed, into: &candidates)
        appendDetection(events: events, into: &candidates)
        appendLockdown(events: events, into: &candidates)
        appendUpgrade(events: events, into: &candidates)
        appendBossAndElite(events: events, into: &candidates)
        appendExtraction(events: events, into: &candidates)
        appendTerminal(events: events, into: &candidates)

        for index in candidates.indices {
            candidates[index].sequence = nextSequence
            nextSequence += 1
            if let id = candidates[index].sourceEntityId {
                candidates[index].sector = sector(
                    from: state.player.position,
                    to: position(of: id, in: state),
                    viewport: state.arena.viewport
                )
            }
            if !settings.hapticsEnabled {
                candidates[index].haptic = .none
            }
        }

        let voices = stealVoices(candidates.filter(\.consumesEffectVoice))
        for cue in voices where !cue.caption.isEmpty {
            captionHistory.append(cue.caption)
        }
        if captionHistory.count > 8 {
            captionHistory.removeFirst(captionHistory.count - 8)
        }

        return AudioProjection(
            cues: settings.effectsEnabled ? voices : [],
            musicState: Self.musicState(state),
            captions: captionHistory
        )
    }

    public static func musicState(_ state: WorldState) -> MusicState {
        if state.outcome == .success || state.outcome == .failure || state.outcome == .invalid {
            return .terminal
        }
        if state.extraction.armed { return .extraction }
        if state.enemies.contains(where: { $0.alive && $0.archetype == .algorithmicModerate }) {
            return .boss
        }
        if state.exposure.lockdownEntered { return .lockdown }
        if state.exposure.detectionState != .hidden { return .observed }
        return .explore
    }

    private mutating func appendWeapon(
        tick: UInt64,
        events: [AuthoritativeEvent],
        into candidates: inout [ProjectedCue]
    ) {
        let fired = events.contains { $0.type == .weaponFired }
        guard fired else { return }
        if let last = lastWeaponVoiceTick, tick >= last, tick - last < 6 { return }
        lastWeaponVoiceTick = tick
        candidates.append(
            cue("weapon_civic_pulse", haptic: .none, caption: "Civic Pulse", priority: 6, entity: nil)
        )
    }

    private func appendImpacts(
        events: [AuthoritativeEvent],
        playerId: EntityID,
        cameraIDsHit: Set<String>,
        into candidates: inout [ProjectedCue]
    ) {
        var hits: [(damage: Int64, id: EntityID)] = []
        for event in events where event.type == .projectileHit || event.type == .entityDamaged {
            let target = payloadString(event, event.type == .projectileHit ? "targetEntityId" : "entityId")
                ?? event.secondaryEntityId?.decimalString
                ?? event.primaryEntityId?.decimalString
            guard let target, target != playerId.decimalString else { continue }
            if cameraIDsHit.contains(target) { continue }
            let damage = payloadInt(event, event.type == .projectileHit ? "appliedDamage" : "amount") ?? 0
            let id = event.secondaryEntityId ?? event.primaryEntityId ?? EntityID(0)
            if let existing = hits.firstIndex(where: { $0.id.decimalString == target }) {
                if damage > hits[existing].damage {
                    hits[existing] = (damage, id)
                } else if damage == hits[existing].damage, id < hits[existing].id {
                    hits[existing] = (damage, id)
                }
            } else {
                hits.append((damage, id))
            }
        }
        hits.sort {
            if $0.damage != $1.damage { return $0.damage > $1.damage }
            return $0.id < $1.id
        }
        for hit in hits.prefix(2) {
            candidates.append(
                cue("impact_enemy", haptic: .none, caption: "Impact", priority: 6, entity: hit.id)
            )
        }
    }

    private mutating func appendPlayerDamage(
        tick: UInt64,
        events: [AuthoritativeEvent],
        into candidates: inout [ProjectedCue]
    ) {
        let damaged = events.filter { $0.type == .playerDamaged }
        guard !damaged.isEmpty else { return }
        if let last = lastPlayerDamageTick, tick >= last, tick - last < 15 { return }
        lastPlayerDamageTick = tick
        candidates.append(
            cue(
                "player_damage",
                haptic: .light,
                caption: "Player damaged",
                priority: 5,
                entity: damaged[0].secondaryEntityId
            )
        )
    }

    private func appendDodge(events: [AuthoritativeEvent], into candidates: inout [ProjectedCue]) {
        guard events.contains(where: { $0.type == .dodgeStarted }) else { return }
        candidates.append(cue("player_dodge", haptic: .light, caption: "Dodge", priority: 7, entity: nil))
    }

    private func appendCameraHits(_ hits: [AuthoritativeEvent], into candidates: inout [ProjectedCue]) {
        var seen = Set<String>()
        for event in hits {
            let id = payloadString(event, "cameraId") ?? event.primaryEntityId?.decimalString ?? ""
            if seen.contains(id) { continue }
            seen.insert(id)
            let after = payloadInt(event, "after") ?? 0
            let entity = event.primaryEntityId
            if after == 2 {
                candidates.append(cue("camera_hit_01", haptic: .light, caption: "Camera hit", priority: 6, entity: entity))
            } else if after == 1 {
                candidates.append(cue("camera_hit_02", haptic: .light, caption: "Camera hit", priority: 6, entity: entity))
                candidates.append(cue("camera_critical", haptic: .warning, caption: "Camera critical", priority: 4, entity: entity))
            }
        }
    }

    private func appendCameraDestructions(_ destroyed: [AuthoritativeEvent], into candidates: inout [ProjectedCue]) {
        for event in destroyed {
            candidates.append(
                cue(
                    "camera_destroy",
                    haptic: .rigid,
                    caption: "Camera destroyed",
                    priority: 4,
                    entity: event.primaryEntityId
                )
            )
        }
        if !destroyed.isEmpty {
            let variant = min(3, destroyed.count)
            candidates.append(
                cue(
                    "camera_network_tamper",
                    haptic: .rigid,
                    caption: variant >= 3 ? "Network tamper 3+" : "Network tamper \(variant)",
                    priority: 4,
                    entity: nil,
                    variant: variant
                )
            )
        }
    }

    private func appendDetection(events: [AuthoritativeEvent], into candidates: inout [ProjectedCue]) {
        let changes = events.filter { $0.type == .detectionStateChanged }
        guard let last = changes.last else { return }
        let before = payloadString(last, "before").flatMap(DetectionState.init(rawValue:))
        let after = payloadString(last, "after").flatMap(DetectionState.init(rawValue:))
        guard let before, let after, rank(after) > rank(before) else { return }
        candidates.append(
            cue("exposure_state_up", haptic: .warning, caption: "Detection \(after.rawValue)", priority: 3, entity: nil)
        )
    }

    private func appendLockdown(events: [AuthoritativeEvent], into candidates: inout [ProjectedCue]) {
        guard events.contains(where: { $0.type == .lockdownEntered }) else { return }
        candidates.append(cue("lockdown_enter", haptic: .heavy, caption: "Lockdown", priority: 3, entity: nil))
    }

    private func appendUpgrade(events: [AuthoritativeEvent], into candidates: inout [ProjectedCue]) {
        guard let event = events.first(where: { $0.type == .upgradeSelected }) else { return }
        let id = payloadString(event, "upgradeId") ?? UpgradeID.signalJammer.rawValue
        candidates.append(
            cue("upgrade_selected_\(id)", haptic: .success, caption: "Upgrade selected", priority: 7, entity: nil)
        )
    }

    private func appendBossAndElite(events: [AuthoritativeEvent], into candidates: inout [ProjectedCue]) {
        for event in events where event.type == .bossAttackStarted {
            let attack = payloadString(event, "attackId") ?? ""
            let audioId: String
            let caption: String
            if attack.contains("query") {
                audioId = "daemon_query"
                caption = "Query telegraph"
            } else if attack.contains("dash") {
                audioId = "daemon_dash"
                caption = "Dash telegraph"
            } else {
                audioId = "boss_telegraph_\(attack)"
                caption = "Boss telegraph"
            }
            candidates.append(cue(audioId, haptic: .warning, caption: caption, priority: 2, entity: event.primaryEntityId))
        }
        if events.contains(where: { $0.type == .bossPhaseChanged }) {
            if let event = events.last(where: { $0.type == .bossPhaseChanged }),
               let after = payloadString(event, "after")
            {
                candidates.append(
                    cue("boss_phase_\(after)", haptic: .heavy, caption: "Policy phase", priority: 2, entity: nil)
                )
            }
        }
        if events.contains(where: { $0.type == .bossDefeated }) {
            candidates.append(cue("boss_defeated", haptic: .success, caption: "Authority defeated", priority: 2, entity: nil))
        }
        if events.contains(where: { $0.type == .allCamerasDestroyed }) {
            candidates.append(cue("network_blackout", haptic: .success, caption: "Network Blackout 8/8", priority: 4, entity: nil))
        }
    }

    private mutating func appendExtraction(events: [AuthoritativeEvent], into candidates: inout [ProjectedCue]) {
        if events.contains(where: { $0.type == .extractionArmed }) {
            candidates.append(cue("extraction_armed", haptic: .success, caption: "Phoenix Steps open", priority: 2, entity: nil))
        }
        if events.contains(where: { $0.type == .extractionReset }) {
            candidates.append(cue("extraction_reset", haptic: .warning, caption: "Extraction reset", priority: 2, entity: nil))
        }
        if let event = events.last(where: { $0.type == .extractionCountdownChanged }),
           let remaining = payloadInt(event, "remainingTicks")
        {
            let displayed = Int((remaining + 59) / 60)
            if lastDisplayedCountdown != displayed, remaining > 0 {
                lastDisplayedCountdown = displayed
                candidates.append(
                    cue("extraction_tick", haptic: .light, caption: "Extraction \(displayed)", priority: 7, entity: nil)
                )
            }
        }
    }

    private func appendTerminal(events: [AuthoritativeEvent], into candidates: inout [ProjectedCue]) {
        if events.contains(where: { $0.type == .runSucceeded }) {
            candidates.append(cue("run_success", haptic: .success, caption: "Run complete", priority: 2, entity: nil))
        }
        if events.contains(where: { $0.type == .runFailed }) {
            candidates.append(cue("player_death", haptic: .heavy, caption: "Player down", priority: 1, entity: nil))
        }
    }

    private func stealVoices(_ cues: [ProjectedCue]) -> [ProjectedCue] {
        var remaining = cues
        while remaining.count > 8 {
            let lowest = remaining.map(\.priority).max()!
            let oldest = remaining
                .enumerated()
                .filter { $0.element.priority == lowest }
                .min { $0.element.sequence < $1.element.sequence }!
            remaining.remove(at: oldest.offset)
        }
        return remaining
    }

    private func cue(
        _ id: String,
        haptic: HapticPattern,
        caption: String,
        priority: Int,
        entity: EntityID?,
        variant: Int? = nil
    ) -> ProjectedCue {
        ProjectedCue(
            audioId: id,
            haptic: haptic,
            caption: caption,
            priority: priority,
            consumesEffectVoice: true,
            sourceEntityId: entity,
            sector: nil,
            sequence: 0,
            variant: variant
        )
    }

    private func rank(_ state: DetectionState) -> Int {
        switch state {
        case .hidden: 0
        case .observed: 1
        case .tracked: 2
        case .hunted: 3
        case .lockdown: 4
        }
    }

    private func payloadString(_ event: AuthoritativeEvent, _ key: String) -> String? {
        if case .string(let value)? = event.payload[key] { return value }
        return nil
    }

    private func payloadInt(_ event: AuthoritativeEvent, _ key: String) -> Int64? {
        if case .integer(let value)? = event.payload[key] { return value }
        return nil
    }

    private func position(of id: EntityID, in state: WorldState) -> VecQ8? {
        if state.player.id == id { return state.player.position }
        if let enemy = state.enemies.first(where: { $0.id == id }) { return enemy.position }
        if let camera = state.cameras.first(where: { $0.entityId == id }) {
            return camera.position.asQ8
        }
        return nil
    }

    private func sector(from player: VecQ8, to source: VecQ8?, viewport: ViewportSpec) -> Int? {
        guard let source else { return nil }
        let dx = source.x.unitsTruncated - player.x.unitsTruncated
        let dy = source.y.unitsTruncated - player.y.unitsTruncated
        let offscreen = abs(dx) > viewport.baselineWorldWidth / 2 || abs(dy) > viewport.baselineWorldHeight / 2
        guard offscreen else { return nil }
        let milli = Cordic.atan2Milli(y: Int64(dy), x: Int64(dx))
        return MilliDeg.normalize(milli) / 45_000
    }
}
