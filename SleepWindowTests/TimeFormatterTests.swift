import XCTest
@testable import SleepWindow

final class TimeFormatterTests: XCTestCase {

    func testHoursAndMinutesFormatting() {
        XCTAssertEqual(TimeFormatter.hoursAndMinutes(0), "0m")
        XCTAssertEqual(TimeFormatter.hoursAndMinutes(30 * 60), "30m")
        XCTAssertEqual(TimeFormatter.hoursAndMinutes(60 * 60), "1h")
        XCTAssertEqual(TimeFormatter.hoursAndMinutes(90 * 60), "1h 30m")
        XCTAssertEqual(TimeFormatter.hoursAndMinutes(7.5 * 3600), "7h 30m")
    }

    func testDateByCombiningPreservesDayWhenAllowed() {
        let today = Date()
        let result = TimeFormatter.dateByCombining(today: today, hour: 22, minute: 15)
        let c = Calendar.current.dateComponents([.hour, .minute], from: result)
        XCTAssertEqual(c.hour, 22)
        XCTAssertEqual(c.minute, 15)
    }

    func testHourMinuteRoundTrip() {
        let date = TimeFormatter.dateByCombining(today: Date(), hour: 7, minute: 45)
        let hm = TimeFormatter.hourMinute(date)
        XCTAssertEqual(hm.hour, 7)
        XCTAssertEqual(hm.minute, 45)
    }
}
