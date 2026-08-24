import Testing
@testable import SurveillanceCore

@Suite(.serialized)
struct ContractVersionsTests {
    @Test func currentIdentityIsCompatible() {
        #expect(ReplayIdentity.current.compatibility() == .compatible)
    }

    @Test func unknownIdentityFailsClosed() {
        let received = ReplayIdentity(
            rulesetVersion: "unknown",
            contentVersion: ContractVersions.content,
            arenaVersion: ContractVersions.arena,
            replaySchemaVersion: ContractVersions.replaySchema
        )

        #expect(
            received.compatibility()
                == .incompatible(expected: .current, received: received)
        )
    }
}
