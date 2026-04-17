import XCTest
@testable import SleepWindow

final class SleepCalculatorTests: XCTestCase {

    private func date(h: Int, m: Int) -> Date {
        TimeFormatter.dateByCombining(today: Date(), hour: h, minute: m)
    }

    func testBedtimesAreBeforeWake() {
        let calc = SleepCalculator(cycleMinutes: 90, fallAsleepMinutes: 15, cycleCounts: [4, 5, 6])
        let wake = date(h: 7, m: 0)
        let options = calc.bedtimes(for: wake)
        XCTAssertEqual(options.count, 3)
        for option in options {
            XCTAssertLessThan(option.bedtime, wake, "Bedtime must precede wake")
        }
    }

    func testBedtimeMathFor5Cycles() {
        let calc = SleepCalculator(cycleMinutes: 90, fallAsleepMinutes: 15, cycleCounts: [5])
        let wake = date(h: 7, m: 0)
        let option = calc.bedtimes(for: wake).first!
        // 5 * 90 = 450 min of sleep + 15 min to fall asleep = 465 min before wake.
        // 7:00 - 7h45m = 23:15 the previous day.
        let expected = wake.addingTimeInterval(-TimeInterval(465 * 60))
        XCTAssertEqual(option.bedtime.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 1.0)
        XCTAssertEqual(option.totalSleep, 5 * 90 * 60, accuracy: 0.1)
    }

    func testWakeTimesAreAfterSleepStart() {
        let calc = SleepCalculator()
        let start = date(h: 23, m: 0)
        let options = calc.wakeTimes(fromSleepStart: start)
        XCTAssertFalse(options.isEmpty)
        for option in options {
            XCTAssertGreaterThan(option.wake, start, "Wake time must follow sleep start")
        }
    }

    func testWakeTimeRollsOverMidnight() {
        let calc = SleepCalculator(cycleMinutes: 90, fallAsleepMinutes: 15, cycleCounts: [5])
        let start = date(h: 23, m: 30) // 11:30 PM
        let option = calc.wakeTimes(fromSleepStart: start).first!
        // 23:30 + 7h45m = 07:15 next day
        let expected = start.addingTimeInterval(TimeInterval(465 * 60))
        XCTAssertEqual(option.wake.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 1.0)
    }

    func testNapOptionsIncludeAllKinds() {
        let calc = SleepCalculator()
        let options = calc.napOptions(from: date(h: 14, m: 0))
        let minutes = Set(options.map { $0.durationMinutes })
        XCTAssertEqual(minutes, Set([10, 20, 90]))
        for option in options {
            XCTAssertEqual(option.end.timeIntervalSince(option.start),
                           TimeInterval(option.durationMinutes * 60),
                           accuracy: 0.5)
        }
    }

    func testCaffeineCutoffSubtractsHours() {
        let calc = SleepCalculator()
        let bedtime = date(h: 23, m: 0)
        let cutoff = calc.caffeineCutoff(for: bedtime, cutoffHours: 8)
        XCTAssertEqual(cutoff.timeIntervalSince(bedtime), -8 * 3600, accuracy: 1.0)
    }

    func testFallAsleepBufferZero() {
        let calc = SleepCalculator(cycleMinutes: 90, fallAsleepMinutes: 0, cycleCounts: [5])
        let wake = date(h: 7, m: 0)
        let option = calc.bedtimes(for: wake).first!
        XCTAssertEqual(option.bedtime.timeIntervalSince(wake), -5 * 90 * 60, accuracy: 1.0)
    }

    func testCycleCountsDeterminesOptionCount() {
        let calc = SleepCalculator(cycleCounts: [3, 4, 5, 6])
        XCTAssertEqual(calc.bedtimes(for: Date()).count, 4)
        XCTAssertEqual(calc.wakeTimes(fromSleepStart: Date()).count, 4)
    }
}
