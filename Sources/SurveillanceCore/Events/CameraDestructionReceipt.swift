import Foundation

public struct CameraDestructionReceiptSummary: Equatable, Sendable {
    public var camerasDamaged: Int
    public var camerasDestroyed: Int
    public var tamperExposureApplied: Int
    public var objectiveDestroyed: Int
    public var objectiveTotal: Int
    public var objectiveComplete: Bool

    public static func project(_ state: WorldState) -> CameraDestructionReceiptSummary {
        let damaged = state.cameras.filter { $0.integrity > 0 && $0.integrity < 3 }.count
        let destroyed = state.destructions.count
        let tamper = state.destructions.reduce(0) { partial, record in
            partial + max(0, record.exposureAfter - record.exposureBefore)
        }
        return CameraDestructionReceiptSummary(
            camerasDamaged: damaged,
            camerasDestroyed: destroyed,
            tamperExposureApplied: tamper,
            objectiveDestroyed: destroyed,
            objectiveTotal: HUDLayout.cameraObjectiveTotal,
            objectiveComplete: state.networkBlackout
        )
    }
}
