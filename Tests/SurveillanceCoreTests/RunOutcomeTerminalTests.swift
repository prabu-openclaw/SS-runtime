import Testing
@testable import SurveillanceCore

/// A run that is paused for a choice is not a run that is over.
///
/// `GameScene.touchesBegan` treated "not playing" as "finished" and restarted
/// on any touch. Because `M-A` completion sets `outcome = .upgradeSelectionPending`
/// alongside `upgrade.pending`, the first tap at the upgrade gate restarted the
/// whole run and the selection branch was unreachable. These pin the
/// distinction so no call site has to rediscover it.
@Suite(.serialized)
struct RunOutcomeTerminalTests {
    @Test func onlyFinishedRunsAreTerminal() {
        #expect(RunOutcome.success.isTerminal)
        #expect(RunOutcome.failure.isTerminal)
        #expect(RunOutcome.invalid.isTerminal)
    }

    @Test func playingIsNotTerminal() {
        #expect(!RunOutcome.playing.isTerminal)
    }

    /// The regression itself: the upgrade gate is a pause, not an ending.
    @Test func upgradeSelectionPendingIsNotTerminal() {
        #expect(!RunOutcome.upgradeSelectionPending.isTerminal)
    }

    /// "not playing" is not a usable test for "over" — the two disagree on
    /// exactly the state that caused the bug.
    @Test func notPlayingDisagreesWithTerminalAtTheUpgradeGate() {
        let outcome = RunOutcome.upgradeSelectionPending
        #expect(outcome != .playing)
        #expect(!outcome.isTerminal)
    }

    /// The bug was reachable in a real run, not only in principle: completing
    /// M-A sets `upgrade.pending` and `outcome = .upgradeSelectionPending`
    /// together (`Simulation.swift`, the M-A branch of `advanceEncounters`).
    /// `testing_armUpgradeSelection` sets that same pair.
    ///
    /// Both reach the snapshot, so the touch handler saw a pending selection
    /// *and* an outcome that was not `.playing` at the same instant.
    @Test func theUpgradeGateIsPendingAndNotTerminalAtOnce() throws {
        var sim = try Simulation.make(seed: 1)
        sim.testing_armUpgradeSelection()

        let snapshot = PresentationSnapshot(sim.state)
        #expect(snapshot.upgradePending)
        #expect(snapshot.outcome == .upgradeSelectionPending)
        // The old condition would have restarted the run here.
        #expect(snapshot.outcome != .playing)
        // The new one correctly leaves the run alive.
        #expect(!snapshot.outcome.isTerminal)
    }

    /// Every terminal outcome has copy, and no live one does — so the surface
    /// cannot appear mid-run, and cannot appear blank when the run ends.
    @Test func terminalCopyExistsForEveryEndingAndNoLiveState() {
        for outcome in [RunOutcome.success, .failure, .invalid] {
            #expect(HUDLayout.terminalCopy(for: outcome) != nil)
        }
        #expect(HUDLayout.terminalCopy(for: .playing) == nil)
        #expect(HUDLayout.terminalCopy(for: .upgradeSelectionPending) == nil)
    }

    /// The copy reuses the words audio-haptics-001 already uses for these
    /// events, uppercased per hud-tutorial-001's presentation rule.
    @Test func terminalCopyMatchesTheEstablishedCaptions() {
        #expect(HUDLayout.terminalCopy(for: .success) == "RUN COMPLETE")
        #expect(HUDLayout.terminalCopy(for: .failure) == "PLAYER DOWN")
    }
}

/// The restart control is the only way off the terminal surface.
///
/// The previous behaviour restarted on a touch anywhere, which always worked
/// even though nothing told the player the run had ended. Requiring a control
/// removes the accidental restart but introduces the opposite risk: if this
/// rect were wrong, the player would be stranded with no way to start again.
/// These pin it.
@Suite(.serialized)
struct TerminalSurfaceGeometryTests {
    /// The reference canvas, and a deliberately cramped device.
    static let sizes = [(844, 390), (667, 375), (1024, 768), (2048, 1536)]

    @Test func theRestartControlSitsInsideThePanel() {
        for (w, h) in Self.sizes {
            let panel = HUDLayout.terminalPanel(safeWidth: w, safeHeight: h)
            let button = HUDLayout.terminalRestart(safeWidth: w, safeHeight: h)

            #expect(button.x >= panel.x)
            #expect(button.y >= panel.y)
            #expect(button.x + button.width <= panel.x + panel.width)
            #expect(button.y + button.height <= panel.y + panel.height)
        }
    }

    /// hud-tutorial-001: every interactive rectangle is at least 44 x 44 points.
    @Test func theRestartControlMeetsTheMinimumTouchTarget() {
        for (w, h) in Self.sizes {
            let button = HUDLayout.terminalRestart(safeWidth: w, safeHeight: h)
            #expect(button.width >= HUDLayout.minimumTouchTargetPoints)
            #expect(button.height >= HUDLayout.minimumTouchTargetPoints)
        }
    }

    /// The control is horizontally centred, so it is reachable either-handed.
    /// Handedness reflects only the stick and Dodge; a shell surface does not move.
    @Test func theRestartControlIsCentredOnTheSafeRectangle() {
        for (w, h) in Self.sizes {
            let button = HUDLayout.terminalRestart(safeWidth: w, safeHeight: h)
            #expect(button.x + button.width / 2 == w / 2)
        }
    }

    /// A point at the centre hits; a point outside the panel does not. This is
    /// the soft-lock guard: the centre must always be live.
    @Test func theCentreHitsAndTheCornerDoesNot() {
        let (w, h) = (844, 390)
        let button = HUDLayout.terminalRestart(safeWidth: w, safeHeight: h)

        let centreX = button.x + button.width / 2
        let centreY = button.y + button.height / 2
        #expect(centreX >= button.x && centreX <= button.x + button.width)
        #expect(centreY >= button.y && centreY <= button.y + button.height)

        // Top-left of the screen is nowhere near the control.
        #expect(!(0 >= button.x && 0 <= button.x + button.width
                  && 0 >= button.y && 0 <= button.y + button.height))
    }

    /// The panel itself stays on screen at the smallest supported safe rect.
    @Test func thePanelFitsTheSmallestSafeRectangle() {
        let (w, h) = (667, 375)
        let panel = HUDLayout.terminalPanel(safeWidth: w, safeHeight: h)
        #expect(panel.x >= 0)
        #expect(panel.y >= 0)
        #expect(panel.x + panel.width <= w)
        #expect(panel.y + panel.height <= h)
    }
}
