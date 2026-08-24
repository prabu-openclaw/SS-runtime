import Foundation
import Testing
@testable import SurveillanceCore

@Test func sha256KnownVector() {
    #expect(SHA256.hex("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    #expect(SHA256.hex([UInt8]()) == SHA256.emptyDigest)
}

@Test func splitMixAndXoshiroGoldenSequence() {
    var rng = Xoshiro256StarStar(seed: 1)
    #expect(rng.s0 == 0x910a2dec89025cc1)
    #expect(rng.s1 == 0xbeeb8da1658eec67)
    #expect(rng.s2 == 0xf893a2eefb32555e)
    #expect(rng.s3 == 0x71c18690ee42c90b)
    #expect(rng.next() == 12_966_619_160_104_079_557)
    #expect(rng.next() == 9_600_361_134_598_540_522)
}

@Test func cameraPlacementStreamIsIsolatedFromCombat() {
    var combat = Xoshiro256StarStar.combat(runSeed: 1)
    var placement = Xoshiro256StarStar.cameraPlacement(runSeed: 1)
    #expect(combat.next() != placement.next())
    var combatAgain = Xoshiro256StarStar.combat(runSeed: 1)
    _ = Xoshiro256StarStar.cameraPlacement(runSeed: 1)
    var combatControl = Xoshiro256StarStar.combat(runSeed: 1)
    #expect(combatAgain.next() == combatControl.next())
}

@Test func entityIdsAreMonotonicAndNeverReused() {
    var allocator = EntityAllocator()
    let a = allocator.next()
    let b = allocator.next()
    #expect(a.raw == 1)
    #expect(b.raw == 2)
    #expect(a < b)
}

@Test func quadraticDiscriminantFitsAndRejectsNegative() {
    #expect(IntMath.quadraticDiscriminant(a: 1, b: 0, c: -1) == 4)
    #expect(IntMath.quadraticDiscriminant(a: 1, b: 0, c: 1) == nil)
    let wide = IntMath.quadraticDiscriminant(a: 9_000_000, b: 3_620_000_000, c: 348_000_000_000)
    #expect(wide != nil)
}

@Test func canonicalJSONSortsKeysAndHashes() {
    let json = CanonicalJSON.object([
        "b": .integer(2),
        "a": .integer(1)
    ])
    #expect(json.serialize() == "{\"a\":1,\"b\":2}")
    #expect(json.sha256Hex().count == 64)
}
