/// T906: tracked severity-one and severity-two defects blocking expansion gate closure.
public enum DefectStatus: String, Equatable, Sendable {
    case open
    case closed
}

public struct DefectRecord: Equatable, Sendable {
    public var id: String
    public var severity: Int
    public var status: DefectStatus
    public var summary: String
    public var taskReference: String?

    public init(id: String, severity: Int, status: DefectStatus, summary: String, taskReference: String? = nil) {
        self.id = id
        self.severity = severity
        self.status = status
        self.summary = summary
        self.taskReference = taskReference
    }
}

/// Empty registry means no open sev-1/2 defects at release-candidate cut.
public enum DefectRegistry {
    public static let tracked: [DefectRecord] = []

    public static var openSeverityOneDefects: Int {
        tracked.filter { $0.severity == 1 && $0.status == .open }.count
    }

    public static var openSeverityTwoDefects: Int {
        tracked.filter { $0.severity == 2 && $0.status == .open }.count
    }

    public static var openDefects: [DefectRecord] {
        tracked.filter { $0.status == .open }
    }

    public static func canonical() -> CanonicalJSON {
        .object([
            "schemaVersion": .string("defect-registry-001"),
            "openSeverityOneDefects": .integer(Int64(openSeverityOneDefects)),
            "openSeverityTwoDefects": .integer(Int64(openSeverityTwoDefects)),
            "defects": .array(tracked.map { defect in
                .object([
                    "id": .string(defect.id),
                    "severity": .integer(Int64(defect.severity)),
                    "status": .string(defect.status.rawValue),
                    "summary": .string(defect.summary),
                    "taskReference": defect.taskReference.map { .string($0) } ?? .null
                ])
            })
        ])
    }
}
