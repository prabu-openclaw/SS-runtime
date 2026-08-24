import Testing
@testable import SurveillanceCore

@Suite(.serialized)
struct SimulationClockTests {
    @Test func clockAdvancesExactlyOneTick() {
        var clock = SimulationClock()
        #expect(clock.advance() == 1)
        #expect(clock.advance() == 2)
        #expect(clock.tick == 2)
    }

    @Test func neutralCommandUsesRequestedTick() {
        let command = PlayerCommand.neutral(tick: 42)
        #expect(command.tick == 42)
        #expect(command.moveX == 0)
        #expect(command.moveY == 0)
        #expect(!command.dodgePressed)
    }
}
