/// Gate C frame-time and stability thresholds from acceptance.md (D-012: 60 Hz target).
public enum PerformanceThresholds {
    public static let frameTimeP50Ms = 16.67
    public static let frameTimeP95Ms = 16.67
    public static let frameTimeP99Ms = 25.0
    public static let frameTimeWorstMs = 50.0
    public static let sustainedPresentationFloorFps = 55
    public static let targetPresentationFps = 60

    /// D-021 ceilings are pending device profiling (T406). Core enforces known simulation bounds.
    public static let civicPoolCapacity = Targeting.activeCeiling
    public static let maxCameraCount = 8
}
