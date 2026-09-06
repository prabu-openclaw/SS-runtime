import Testing
@testable import SurveillanceCore

/// hud-tutorial-001 §Tutorial state machine, exhaustively.
///
/// Only T0 and the Lockdown preempt had direct coverage; every other
/// transition was asserted by nothing. These pin the thresholds the contract
/// names, so a change to one is a failing test rather than a silent drift.
@Suite(.serialized)
struct TutorialStateMachineTests {
    /// "T0 completes after cumulative Player displacement reaches 96 units."
    @Test func t0CompletesAtNinetySixUnitsAndNotBefore() {
        var tutorial = TutorialState()
        tutorial.noteDisplacement(95)
        #expect(tutorial.phase == .move)
        tutorial.noteDisplacement(1)
        #expect(tutorial.phase == .field)
    }

    /// Displacement accumulates; it is not a per-tick threshold.
    @Test func t0AccumulatesDisplacementAcrossTicks() {
        var tutorial = TutorialState()
        for _ in 0..<96 { tutorial.noteDisplacement(1) }
        #expect(tutorial.phase == .field)
    }

    /// "T1 ... completes after 60 presented ticks."
    @Test func t1CompletesAfterSixtyPresentedTicks() {
        var tutorial = TutorialState()
        tutorial.noteDisplacement(96)
        for _ in 0..<59 { tutorial.noteCameraInViewport() }
        #expect(tutorial.phase == .field)
        tutorial.noteCameraInViewport()
        #expect(tutorial.phase == .contact)
    }

    /// T1 only counts while it is the active phase.
    @Test func t1DoesNotCountBeforeItIsActive() {
        var tutorial = TutorialState()
        for _ in 0..<120 { tutorial.noteCameraInViewport() }
        #expect(tutorial.phase == .move)
    }

    /// "T2 activates on first Camera contact."
    @Test func t2ActivatesOnFirstContact() {
        var tutorial = TutorialState()
        tutorial.noteDisplacement(96)
        tutorial.noteContact(true)
        #expect(tutorial.phase == .contact)
    }

    /// "... completes when contact becomes zero for 30 consecutive ticks."
    @Test func t2CompletesAfterThirtyConsecutiveClearTicks() {
        var tutorial = TutorialState()
        tutorial.noteDisplacement(96)
        tutorial.noteContact(true)
        for _ in 0..<29 { tutorial.noteContact(false) }
        #expect(tutorial.phase == .contact)
        tutorial.noteContact(false)
        #expect(tutorial.phase == .cameraDamage)
    }

    /// "consecutive" is load-bearing: contact resets the count.
    @Test func t2ContactResetsTheClearRun() {
        var tutorial = TutorialState()
        tutorial.noteDisplacement(96)
        tutorial.noteContact(true)
        for _ in 0..<29 { tutorial.noteContact(false) }
        tutorial.noteContact(true)
        for _ in 0..<29 { tutorial.noteContact(false) }
        #expect(tutorial.phase == .contact)
    }

    /// T3 is only reachable from T1 or T2: `noteCameraTargetable` ignores a
    /// standing start, so the machine cannot skip ahead.
    @Test func t3IsNotReachableFromTheOpeningPhase() {
        var tutorial = TutorialState()
        for _ in 0..<400 { tutorial.noteCameraTargetable() }
        #expect(tutorial.phase == .move)
    }

    /// "T3 ... completes on its first valid impact or after 300 eligible ticks."
    @Test func t3CompletesOnFirstImpact() {
        var tutorial = TutorialState()
        tutorial.noteDisplacement(96)   // T3 is reached through the machine,
        tutorial.noteContact(true)      // not from a standing start.
        tutorial.noteCameraTargetable()
        #expect(tutorial.phase == .cameraDamage)
        tutorial.noteCameraImpact()
        #expect(tutorial.phase == .upgrade)
    }

    @Test func t3CompletesAfterThreeHundredEligibleTicks() {
        var tutorial = TutorialState()
        tutorial.noteDisplacement(96)
        tutorial.noteContact(true)
        for _ in 0..<299 { tutorial.noteCameraTargetable() }
        #expect(tutorial.phase == .cameraDamage)
        tutorial.noteCameraTargetable()
        #expect(tutorial.phase == .upgrade)
    }

    /// "T4 activates on M-A completion and completes on accepted upgrade choice."
    @Test func t4RunsFromMobACompletionToAcceptedChoice() {
        var tutorial = TutorialState()
        tutorial.noteMobAComplete()
        #expect(tutorial.phase == .upgrade)
        #expect(tutorial.copy == "CHOOSE ONE COUNTERMEASURE")
        tutorial.noteUpgradeSelected()
        #expect(tutorial.phase == .complete)
        #expect(tutorial.copy.isEmpty)
    }
}

/// hud-tutorial-001: "Each card has a maximum visual duration of 300 ticks,
/// but its completion condition remains authoritative where specified."
@Suite(.serialized)
struct TutorialCardDurationTests {
    @Test func cardRetiresAfterItsMaximumVisualDuration() {
        var tutorial = TutorialState()
        for _ in 0..<(TutorialState.maxCardTicks - 1) { tutorial.notePresentedTick() }
        #expect(tutorial.copy == "MOVE")
        tutorial.notePresentedTick()
        #expect(tutorial.copy.isEmpty)
    }

    /// The cap is visual only. Retiring the card must not advance the phase or
    /// skip the completion condition.
    @Test func retiringTheCardLeavesTheCompletionConditionAuthoritative() {
        var tutorial = TutorialState()
        for _ in 0..<(TutorialState.maxCardTicks * 2) { tutorial.notePresentedTick() }
        #expect(tutorial.copy.isEmpty)
        #expect(tutorial.phase == .move)

        // T0's condition still governs, long after the card stopped showing.
        tutorial.noteDisplacement(96)
        #expect(tutorial.phase == .field)
    }

    /// A new card gets its own full duration.
    @Test func theCounterRestartsWithEachPhase() {
        var tutorial = TutorialState()
        for _ in 0..<TutorialState.maxCardTicks { tutorial.notePresentedTick() }
        #expect(tutorial.copy.isEmpty)

        tutorial.noteDisplacement(96)
        #expect(tutorial.phase == .field)
        #expect(tutorial.copy == "CAMERA FIELDS RAISE EXPOSURE")
    }

    /// A safety message is not a tutorial card and outlives the cap. A Lockdown
    /// that vanished after five seconds would be a safety regression.
    @Test func safetyMessagesSurviveTheCap() {
        var tutorial = TutorialState()
        for _ in 0..<(TutorialState.maxCardTicks * 2) { tutorial.notePresentedTick() }
        #expect(tutorial.copy.isEmpty)

        tutorial.lockdownPreempts = true
        #expect(tutorial.copy == "LOCKDOWN")
    }
}

/// hud-tutorial-001: "Higher safety messages (lethal warning, Lockdown,
/// Extraction) temporarily replace it without changing tutorial progress."
@Suite(.serialized)
struct TutorialPreemptionTests {
    @Test func armedExtractionPreemptsTheCard() {
        var tutorial = TutorialState()
        #expect(tutorial.copy == "MOVE")
        tutorial.extractionPreempts = .armed
        #expect(tutorial.copy == HUDLayout.phoenixStepsOpenCopy)
    }

    @Test func lockedExtractionContactShowsThePrerequisite() {
        var tutorial = TutorialState()
        tutorial.extractionPreempts = .lockedContact
        #expect(tutorial.copy == HUDLayout.lockedExtractionCopy)
    }

    /// "without changing tutorial progress" — the phase is untouched, and the
    /// card returns intact once the message clears.
    @Test func preemptionPreservesProgressAndRestoresTheCard() {
        var tutorial = TutorialState()
        tutorial.noteDisplacement(96)
        #expect(tutorial.phase == .field)

        tutorial.extractionPreempts = .armed
        #expect(tutorial.copy == HUDLayout.phoenixStepsOpenCopy)
        #expect(tutorial.phase == .field)

        tutorial.extractionPreempts = nil
        #expect(tutorial.copy == "CAMERA FIELDS RAISE EXPOSURE")
    }

    /// Lockdown outranks Extraction: M-C activation is the more urgent state.
    @Test func lockdownOutranksExtraction() {
        var tutorial = TutorialState()
        tutorial.extractionPreempts = .armed
        tutorial.lockdownPreempts = true
        #expect(tutorial.copy == "LOCKDOWN")
    }

    /// The tutorial setting hides cards. It must not hide safety copy.
    @Test func safetyCopyIsDistinguishedFromCardCopy() {
        var tutorial = TutorialState()
        #expect(!tutorial.copyIsSafetyMessage)

        tutorial.lockdownPreempts = true
        #expect(tutorial.copyIsSafetyMessage)

        tutorial.lockdownPreempts = false
        tutorial.extractionPreempts = .lockedContact
        #expect(tutorial.copyIsSafetyMessage)
    }
}
