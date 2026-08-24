public enum CameraPresentationState: String, Equatable, Sendable {
    case operational
    case damaged
    case critical
    case hit
    case destroying
    case fieldOff
    case destroyed
    case dormant
}

public struct CameraPresentationQuery: Equatable, Sendable {
    public var entityId: EntityID
    public var integrity: Int
    public var headingMilli: Int
    public var position: VecI

    public init(entityId: EntityID, integrity: Int, headingMilli: Int, position: VecI) {
        self.entityId = entityId
        self.integrity = integrity
        self.headingMilli = headingMilli
        self.position = position
    }
}

public struct CameraPresentation: Equatable, Sendable {
    public var entityId: EntityID
    public var state: CameraPresentationState
    public var integrity: Int
    public var fieldVisible: Bool
    public var clipId: String
    public var fieldOffClipId: String?
    public var headingMilli: Int
    public var housingTransformLocked: Bool
    public var reducedMotionImmediateSwap: Bool

    public static func persistentState(integrity: Int) -> CameraPresentationState {
        switch integrity {
        case 3: .operational
        case 2: .damaged
        case 1: .critical
        default: .dormant
        }
    }

    public static func clipId(for state: CameraPresentationState) -> String {
        switch state {
        case .operational: "camera_operational_idle"
        case .damaged, .hit: "camera_hit"
        case .critical: "camera_critical_enter"
        case .destroying: "camera_destroy"
        case .fieldOff: "camera_field_off"
        case .destroyed, .dormant: "camera_destroyed_idle"
        }
    }

    public static func project(
        cameras: [CameraPresentationQuery],
        events: [AuthoritativeEvent],
        reducedMotion: Bool = false
    ) -> [CameraPresentation] {
        let hitIds = Set(events.filter { $0.type == .cameraIntegrityChanged }.compactMap(\.primaryEntityId))
        let destroyedIds = Set(events.filter { $0.type == .cameraDestroyed }.compactMap(\.primaryEntityId))
        return cameras.map { camera in
            let destroyedNow = destroyedIds.contains(camera.entityId)
            let hitNow = hitIds.contains(camera.entityId) && camera.integrity > 0
            let persistent = persistentState(integrity: camera.integrity)
            let state: CameraPresentationState
            if destroyedNow {
                state = .destroying
            } else if camera.integrity <= 0 {
                state = .dormant
            } else if hitNow {
                state = .hit
            } else {
                state = persistent
            }
            let fieldVisible = camera.integrity > 0 && !destroyedNow
            return CameraPresentation(
                entityId: camera.entityId,
                state: state,
                integrity: camera.integrity,
                fieldVisible: fieldVisible,
                clipId: clipId(for: state),
                fieldOffClipId: destroyedNow ? CameraPresentation.clipId(for: .fieldOff) : nil,
                headingMilli: camera.headingMilli,
                housingTransformLocked: true,
                reducedMotionImmediateSwap: reducedMotion
            )
        }
    }
}
