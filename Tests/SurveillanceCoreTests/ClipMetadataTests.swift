import Foundation
import Testing
@testable import SurveillanceCore

@Suite(.serialized)
struct ClipMetadataTests {
    @Test func clipCatalogDeclaresRequiredMarkersAndFourDirections() throws {
        let catalog = try ClipCatalog.bundled()
        let ids = catalog.clips.map(\.clipId)
        let dodge = try #require(catalog.clipsById["player_dodge"])
        let hurt = try #require(catalog.clipsById["player_hurt"])
        let destroy = try #require(catalog.clipsById["camera_destroy"])
        let fieldOff = try #require(catalog.clipsById["camera_field_off"])
        let idle = try #require(catalog.clipsById["player_idle"])
        let anticipateStates = ClipCatalog.distinctEnemyAnticipateIds.compactMap { catalog.clipsById[$0]?.state }
        let cameraDirections = catalog.clips.filter { $0.actorRole == "camera" }.map(\.directions)
        let dodgeFramesLookLikeEvent = dodge.frameIds.contains("dodgeStarted")
        #expect(catalog.schemaVersion == ContractVersions.clipMetadata)
        #expect(catalog.animationVersion == ContractVersions.animation)
        let destroyDurationMs = destroy.frameIds.count * 1000 / destroy.framesPerSecond
        #expect(ids == ClipCatalog.requiredClipIds)
        #expect(dodge.directions == ClipCatalog.fourDirections)
        #expect(dodge.authoritativeEventMarker == EventType.dodgeStarted.rawValue)
        #expect(catalog.eventType(forClipId: "player_dodge") == .dodgeStarted)
        #expect(!dodgeFramesLookLikeEvent)
        #expect(hurt.authoritativeEventMarker == EventType.playerDamaged.rawValue)
        #expect(destroy.authoritativeEventMarker == EventType.cameraDestroyed.rawValue)
        #expect(destroyDurationMs <= 350)
        #expect(fieldOff.authoritativeEventMarker == EventType.cameraDestroyed.rawValue)
        #expect(fieldOff.blendOrTransition == "immediateOnEvent")
        #expect(idle.loop)
        #expect(idle.authoritativeEventMarker == "none")
        #expect(idle.eventType == nil)
        #expect(Set(anticipateStates).count == 5)
        #expect(cameraDirections.allSatisfy(\.isEmpty))
    }

    @Test func clipCatalogUnknownSchemaFailsClosed() throws {
        let json = #"{"schemaVersion":"clip-metadata-000","animationVersion":"animation-civic-seam-001","clips":[]}"#.data(using: .utf8)!
        do {
            _ = try ClipCatalogLoader.decode(json)
            Issue.record("expected schema failure")
        } catch ClipMetadataError.schemaVersion {
        }
    }

    @Test func clipCatalogMissingFieldFailsClosed() throws {
        let json = try mutatedBundled { clips in
            clips[0].removeValue(forKey: "authoritativeEventMarker")
        }
        do {
            _ = try ClipCatalogLoader.decode(json)
            Issue.record("expected missing key")
        } catch ClipMetadataError.missingKey("authoritativeEventMarker") {
        }
    }

    @Test func clipCatalogMissingRequiredClipFailsClosed() throws {
        let json = try mutatedBundled { clips in
            clips.removeAll { ($0["clipId"] as? String) == "player_idle" }
        }
        do {
            _ = try ClipCatalogLoader.decode(json)
            Issue.record("expected missing required clip")
        } catch ClipMetadataError.missingRequiredClip("player_idle") {
        }
    }

    @Test func clipCatalogRejectsMarkerCopiedFromFrameId() throws {
        let json = try mutatedBundled { clips in
            clips[0]["frameIds"] = ["none"]
        }
        do {
            _ = try ClipCatalogLoader.decode(json)
            Issue.record("expected marker/frame collision")
        } catch ClipMetadataError.markerMatchesFrameId("player_idle") {
        }
    }

    @Test func clipCatalogRejectsUnknownEventMarker() throws {
        let json = try mutatedBundled { clips in
            clips[0]["authoritativeEventMarker"] = "inventedEvent"
        }
        do {
            _ = try ClipCatalogLoader.decode(json)
            Issue.record("expected invalid marker")
        } catch ClipMetadataError.invalidMarker("player_idle") {
        }
    }

    @Test func clipCatalogFieldOffCannotWaitForDestroyClip() throws {
        let json = try mutatedBundled { clips in
            if let index = clips.firstIndex(where: { ($0["clipId"] as? String) == "camera_field_off" }) {
                clips[index]["cancelWindows"] = ["camera_destroy"]
                clips[index]["blendOrTransition"] = "waitForDestroyClip"
            }
        }
        do {
            _ = try ClipCatalogLoader.decode(json)
            Issue.record("expected camera field-off failure")
        } catch ClipMetadataError.cameraFieldOff {
        }
    }

    private func mutatedBundled(_ mutate: (inout [[String: Any]]) -> Void) throws -> Data {
        var root = try JSONSerialization.jsonObject(with: SpecBundle.contract("clip-metadata-001")) as! [String: Any]
        var clips = root["clips"] as! [[String: Any]]
        mutate(&clips)
        root["clips"] = clips
        return try JSONSerialization.data(withJSONObject: root)
    }
}
