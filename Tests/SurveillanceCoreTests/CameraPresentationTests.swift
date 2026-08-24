import Testing
@testable import SurveillanceCore

@Suite(.serialized)
struct CameraPresentationTests {
    @Test func cameraStatesFollowIntegrityWithoutMovingHousing() {
        let cameras = [
            CameraPresentationQuery(entityId: EntityID(2), integrity: 3, headingMilli: 90_000, position: VecI(x: 10, y: 20)),
            CameraPresentationQuery(entityId: EntityID(3), integrity: 2, headingMilli: 90_000, position: VecI(x: 10, y: 20)),
            CameraPresentationQuery(entityId: EntityID(4), integrity: 1, headingMilli: 90_000, position: VecI(x: 10, y: 20)),
            CameraPresentationQuery(entityId: EntityID(5), integrity: 0, headingMilli: 90_000, position: VecI(x: 10, y: 20))
        ]
        let frames = CameraPresentation.project(cameras: cameras, events: [])
        let states = frames.map(\.state)
        let fields = frames.map(\.fieldVisible)
        let clips = frames.map(\.clipId)
        let locked = frames.allSatisfy(\.housingTransformLocked)
        let headings = Set(frames.map(\.headingMilli))
        #expect(states == [.operational, .damaged, .critical, .dormant])
        #expect(fields == [true, true, true, false])
        #expect(clips == [
            "camera_operational_idle",
            "camera_hit",
            "camera_critical_enter",
            "camera_destroyed_idle"
        ])
        #expect(locked)
        #expect(headings == [90_000])
    }

    @Test func cameraFieldOffStartsOnDestroyTickAndDoesNotWait() {
        let camera = CameraPresentationQuery(
            entityId: EntityID(8),
            integrity: 0,
            headingMilli: 0,
            position: VecI(x: 64, y: 64)
        )
        let destroyed = AuthoritativeEvent(
            tick: 4,
            phase: 10,
            type: .cameraDestroyed,
            primary: EntityID(8),
            payload: [
                "cameraId": .string("8"),
                "socketId": .string("cam-z02-a"),
                "projectileId": .string("1"),
                "wasDetecting": .bool(false)
            ],
            insertion: 0
        )
        let frame = CameraPresentation.project(cameras: [camera], events: [destroyed], reducedMotion: true)[0]
        let state = frame.state
        let fieldVisible = frame.fieldVisible
        let clip = frame.clipId
        let fieldOff = frame.fieldOffClipId
        let reduced = frame.reducedMotionImmediateSwap
        let heading = frame.headingMilli
        #expect(state == .destroying)
        #expect(!fieldVisible)
        #expect(clip == "camera_destroy")
        #expect(fieldOff == "camera_field_off")
        #expect(reduced)
        #expect(heading == 0)
    }

    @Test func cameraHitDoesNotInterruptFieldOrRotateHousing() {
        let camera = CameraPresentationQuery(
            entityId: EntityID(4),
            integrity: 2,
            headingMilli: 45_000,
            position: VecI(x: 8, y: 8)
        )
        let hit = AuthoritativeEvent(
            tick: 9,
            phase: 9,
            type: .cameraIntegrityChanged,
            primary: EntityID(4),
            payload: [
                "cameraId": .string("4"),
                "before": .integer(3),
                "after": .integer(2)
            ],
            insertion: 0
        )
        let frame = CameraPresentation.project(cameras: [camera], events: [hit])[0]
        let state = frame.state
        let fieldVisible = frame.fieldVisible
        let clip = frame.clipId
        let locked = frame.housingTransformLocked
        let heading = frame.headingMilli
        #expect(state == .hit)
        #expect(fieldVisible)
        #expect(clip == "camera_hit")
        #expect(locked)
        #expect(heading == 45_000)
    }
}
