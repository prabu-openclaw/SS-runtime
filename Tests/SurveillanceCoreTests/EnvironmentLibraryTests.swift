import Testing
@testable import SurveillanceCore

/// `visual-assets-001` §3a: environment art is optional, admitted per group,
/// and all-or-nothing within a group.
@Suite(.serialized)
struct EnvironmentLibraryTests {
    static func library(delivering ids: [String]) -> EnvironmentLibrary {
        let declared = [
            "env_ground_asphalt", "env_ground_sidewalk",
            "env_solid_01_residential_west", "env_solid_02_residential_north",
            "env_camera_municipal_dome"
        ]
        var paths: [String: String] = [:]
        for id in ids { paths[id] = "\(id)@1x.png" }
        return EnvironmentLibrary(declaredIds: declared, deliveredPaths: paths)
    }

    /// The rule that matters: a group with one missing asset is not used at all.
    ///
    /// Partial art is a legibility hazard rather than a partial improvement — a
    /// player cannot tell which grey rectangles are unfinished and which are
    /// meant to read as concrete.
    @Test func oneMissingAssetLeavesTheWholeGroupUnbacked() {
        let library = Self.library(delivering: ["env_ground_asphalt"])

        #expect(!library.isBacked(.ground))
        // Even the delivered one is withheld while its group is short.
        #expect(library.path(for: "env_ground_asphalt") == nil)
    }

    @Test func aCompleteGroupIsBacked() {
        let library = Self.library(delivering: ["env_ground_asphalt", "env_ground_sidewalk"])

        #expect(library.isBacked(.ground))
        #expect(library.path(for: "env_ground_asphalt") == "env_ground_asphalt@1x.png")
    }

    /// Groups are independent: complete ground does not license partial solids.
    @Test func groupsAreBackedIndependently() {
        let library = Self.library(delivering: [
            "env_ground_asphalt", "env_ground_sidewalk",
            "env_solid_01_residential_west"
        ])

        #expect(library.isBacked(.ground))
        #expect(!library.isBacked(.solid))
        #expect(library.path(for: "env_solid_01_residential_west") == nil)
    }

    @Test func nothingDeliveredMeansNothingBacked() {
        let library = Self.library(delivering: [])
        for group in EnvironmentLibrary.Group.allCases {
            #expect(!library.isBacked(group))
        }
    }

    /// A group the contract never declares is not "complete by vacuity".
    @Test func anEmptyGroupIsNotBacked() {
        let library = Self.library(delivering: [])
        #expect(library.ids(in: .motif).isEmpty)
        #expect(!library.isBacked(.motif))
    }

    /// The one place the solid naming convention lives. If this ever disagrees
    /// with the contract the solid falls back to blockout rather than drawing
    /// the wrong building.
    @Test func solidAssetIdsDeriveFromArenaSolidIds() {
        #expect(EnvironmentLibrary.solidAssetId(forSolidId: "solid-04-civic-west")
                == "env_solid_04_civic_west")
        #expect(EnvironmentLibrary.solidAssetId(forSolidId: "solid-13-phoenix-west")
                == "env_solid_13_phoenix_west")
    }

    /// Camera mounts are synthesised at runtime as `mount-<socket>` and have no
    /// authored art, so they must not resolve to a solid asset.
    @Test func runtimeMountSolidsHaveNoArt() {
        let library = Self.library(delivering: [
            "env_solid_01_residential_west", "env_solid_02_residential_north"
        ])
        let id = EnvironmentLibrary.solidAssetId(forSolidId: "mount-SOCKET-01")
        #expect(library.path(for: id) == nil)
    }

    @Test func coverageCountsOnlyDeclaredIds() {
        let library = Self.library(delivering: ["env_ground_asphalt", "not_declared_at_all"])
        #expect(library.coverage.backed == 1)
        #expect(library.coverage.total == 5)
    }
}

/// The contract has to name the environment, or admitted art is unreachable.
@Suite(.serialized)
struct EnvironmentContractTests {
    @Test func theContractNamesEveryArenaSolid() throws {
        let library = try EnvironmentLibrary.bundled()
        let arena = try ArenaManifest.bundled()

        for solid in arena.permanentSolids {
            let id = EnvironmentLibrary.solidAssetId(forSolidId: solid.id)
            #expect(library.declaredIds.contains(id), "no environment ID for \(solid.id)")
        }
    }

    /// Environment IDs reach the bundle filter. Without this, admitted
    /// environment art is excluded however correctly it was produced — the same
    /// gap `musicAssetIds` closed for music.
    @Test func environmentIdsAreRuntimeReachable() throws {
        let reachable = try RuntimeBundleFilter.reachableAssetIds()
        let library = try EnvironmentLibrary.bundled()

        #expect(!library.declaredIds.isEmpty)
        for id in library.declaredIds {
            #expect(reachable.contains(id), "\(id) is not runtime-reachable")
        }
    }
}
