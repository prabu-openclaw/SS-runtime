import Foundation

enum BundledResource {
    static func data(name: String, subdirectory: String) -> Data {
        if let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: subdirectory) {
            return try! Data(contentsOf: url)
        }
        let fallback = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/\(subdirectory)/\(name).json")
        return try! Data(contentsOf: fallback)
    }
}

public enum SpecBundle {
    public static func contract(_ name: String) -> Data {
        BundledResource.data(name: name, subdirectory: "contracts")
    }

    public static func fixture(_ name: String) -> Data {
        BundledResource.data(name: name, subdirectory: "fixtures")
    }
}
