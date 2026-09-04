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

/// Delivered runtime assets admitted under `legacy-admission.md`.
public enum RuntimeAssetBundle {
    /// File URL for a delivered asset, or nil when it is not in the bundle.
    public static func url(forFile name: String) -> URL? {
        if let url = Bundle.module.url(
            forResource: name,
            withExtension: nil,
            subdirectory: "RuntimeAssets"
        ) {
            return url
        }
        let fallback = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/RuntimeAssets/\(name)")
        return FileManager.default.fileExists(atPath: fallback.path) ? fallback : nil
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
