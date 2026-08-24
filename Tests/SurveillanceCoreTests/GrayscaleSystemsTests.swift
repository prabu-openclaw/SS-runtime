import Testing
@testable import SurveillanceCore

@Test func exposureEX004SixtyTicksNoRecoveryYet() {
    var state = ExposureState(exposure: 300, detectionState: .observed, noContactTicks: 0)
    for _ in 0..<60 {
        _ = state.resolveTick(survivingContactCount: 0, tamperAmounts: [], signalJammer: false)
    }
    #expect(state.exposure == 300)
    #expect(state.noContactTicks == 60)
}

@Test func exposureEX007TamperWithoutContact() {
    var state = ExposureState(exposure: 190, detectionState: .hidden)
    let result = state.resolveTick(survivingContactCount: 0, tamperAmounts: [100], signalJammer: false)
    #expect(result.contactDelta == 0)
    #expect(state.exposure == 290)
    #expect(state.detectionState == .observed)
}

@Test func exposureEX008TwoTampersLockdownOnce() {
    var state = ExposureState(exposure: 850, detectionState: .hunted)
    let result = state.resolveTick(survivingContactCount: 0, tamperAmounts: [100, 100], signalJammer: false)
    #expect(state.exposure == 1000)
    #expect(state.detectionState == .lockdown)
    #expect(result.lockdownEnteredThisTick)
}

@Test func exposureEX009LockdownIgnoresRecovery() {
    var state = ExposureState(exposure: 1000, detectionState: .lockdown, lockdownEntered: true)
    for _ in 0..<80 {
        _ = state.resolveTick(survivingContactCount: 0, tamperAmounts: [], signalJammer: false)
    }
    #expect(state.exposure == 1000)
    #expect(state.detectionState == .lockdown)
}

@Test func exposureEX010SingleStateJumpEvent() {
    var state = ExposureState()
    let result = state.resolveTick(survivingContactCount: 0, tamperAmounts: [100, 100, 100, 100, 100, 100, 100], signalJammer: false)
    #expect(result.stateBefore == .hidden)
    #expect(result.stateAfter == .hunted || result.stateAfter == .lockdown)
    #expect(state.exposure >= 700)
}

@Test func playerPC002DiagonalDoesNotExceedMaxSpeed() {
    let end = IsolatedKernel.move(ticks: 60, moveX: PlayerCommand.axisMaximum, moveY: PlayerCommand.axisMaximum)
    let distance = IsolatedKernel.distanceUnits(VecI(x: 256, y: 256).asQ8, end)
    #expect(distance >= 239 && distance <= 240)
}

@Test func playerPC003HalfMagnitude() {
    let end = IsolatedKernel.move(ticks: 60, moveX: 16_384, moveY: 0)
    #expect(end.x.unitsTruncated == 376)
    #expect(end.y.unitsTruncated == 256)
}

@Test func playerPC005DodgeAtMostNinetySix() {
    let (player, _) = IsolatedKernel.dodgeOnce()
    #expect(player.position.x.unitsTruncated <= 256 + 96)
    #expect(player.position.x.unitsTruncated >= 256 + 90)
}

@Test func playerPC007RejectedDodgeDuringCooldown() {
    #expect(IsolatedKernel.rejectedDodgeDuringCooldown() == 1)
}

@Test func cameraCD002TwoImpactsRemainCritical() {
    let result = IsolatedKernel.cameraIntegrity(impacts: 2)
    #expect(result.integrity == 1)
    #expect(result.tamper == 0)
    #expect(result.destructions == 0)
}

@Test func hudUI001ReferenceAnchors() {
    #expect(HUDLayout.stick(handedness: .right).x == 104)
    #expect(HUDLayout.dodge(handedness: .right).width == 88)
    #expect(HUDLayout.pause().meetsTouchTarget)
}

@Test func hudUI002HandednessMirrorsOnlyStickAndDodge() {
    #expect(HUDLayout.stick(handedness: .left).x == 740)
    #expect(HUDLayout.dodge(handedness: .left).x == 84)
    #expect(HUDLayout.pause().x == 806)
}

@Test func hudUI006ExtractionSecondsCeil() {
    #expect(HUDLayout.extractionSeconds(300) == 5)
    #expect(HUDLayout.extractionSeconds(1) == 1)
    #expect(HUDLayout.extractionSeconds(0) == 0)
}

@Test func bossPhaseBO002HealthBands() {
    #expect(BossPhase.from(hp: 800) == .publicSafety)
    #expect(BossPhase.from(hp: 600) == .publicSafety)
    #expect(BossPhase.from(hp: 599) == .civilLiberties)
    #expect(BossPhase.from(hp: 400) == .civilLiberties)
    #expect(BossPhase.from(hp: 399) == .temporarySafeguard)
    #expect(BossPhase.from(hp: 200) == .temporarySafeguard)
    #expect(BossPhase.from(hp: 199) == .independentReview)
    #expect(BossPhase.from(hp: 1) == .independentReview)
}

@Test func bossBO003BatchSkipsToTemporarySafeguard() {
    var runtime = BossRuntime()
    let changed = runtime.syncPhase(hp: 390)
    #expect(changed == .temporarySafeguard)
    #expect(runtime.recoveryRemaining == 45)
}

@Test func observationPulsePublicSafetyRoundsHalfAway() {
    #expect(IntMath.divHalfAway(10 * 105, 100) == 11)
    #expect(IntMath.divHalfAway(11 * 75, 100) == 8)
}

@Test func projectilePoolRejectsBeyondCeiling() {
    var pool = ProjectilePool(capacity: 2)
    let proto = ProjectileBody(
        id: EntityID(1),
        ownerId: EntityID(1),
        kind: .civicPulse,
        position: .zero,
        previous: .zero,
        velocity: .zero,
        radius: 4,
        damage: 10,
        cameraDamage: 1,
        age: 1,
        lifetime: 45,
        distanceTravelledQ8: 0,
        maxTravelQ8: 100,
        hitEntityIds: [],
        alive: true
    )
    let first = pool.checkout(proto)
    #expect(first)
    var second = proto
    second.id = EntityID(2)
    let secondOk = pool.checkout(second)
    #expect(secondOk)
    var third = proto
    third.id = EntityID(3)
    let thirdOk = pool.checkout(third)
    #expect(!thirdOk)
    #expect(pool.liveCount == 2)
}

@Test func tutorialT0CompletesAfterNinetySixUnits() {
    var tutorial = TutorialState()
    tutorial.noteDisplacement(96)
    #expect(tutorial.phase == .field)
    #expect(tutorial.copy == "CAMERA FIELDS RAISE EXPOSURE")
}

@Test func tutorialLockdownPreemptsCopy() {
    var tutorial = TutorialState()
    tutorial.lockdownPreempts = true
    #expect(tutorial.copy == "LOCKDOWN")
}
