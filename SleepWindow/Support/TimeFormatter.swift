import Foundation

enum TimeFormatter {
    static func formatted(_ date: Date, use24Hour: Bool) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = use24Hour ? "HH:mm" : "h:mm a"
        return formatter.string(from: date)
    }

    static func hoursAndMinutes(_ totalSeconds: TimeInterval) -> String {
        let minutes = Int(totalSeconds / 60)
        let h = minutes / 60
        let m = minutes % 60
        if h == 0 { return "\(m)m" }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }

    static func dateByCombining(today: Date, hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: today)
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components) ?? today
    }

    /// Parses a time-of-day `Date` into (hour, minute).
    static func hourMinute(_ date: Date) -> (hour: Int, minute: Int) {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0, c.minute ?? 0)
    }
}
