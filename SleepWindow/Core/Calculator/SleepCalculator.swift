import Foundation

struct BedtimeOption: Identifiable, Hashable {
    let id = UUID()
    let cycles: Int
    let bedtime: Date
    let totalSleep: TimeInterval
    var label: String { "\(cycles) cycles" }
    var hoursOfSleep: Double { totalSleep / 3600.0 }
}

struct WakeOption: Identifiable, Hashable {
    let id = UUID()
    let cycles: Int
    let wake: Date
    let totalSleep: TimeInterval
    var label: String { "\(cycles) cycles" }
    var hoursOfSleep: Double { totalSleep / 3600.0 }
}

enum NapKind: String, CaseIterable, Hashable {
    case power
    case short
    case fullCycle
    var displayName: String {
        switch self {
        case .power: return "Power nap"
        case .short: return "Short nap"
        case .fullCycle: return "Full cycle nap"
        }
    }
    var minutes: Int {
        switch self {
        case .power: return 10
        case .short: return 20
        case .fullCycle: return 90
        }
    }
    var subtitle: String {
        switch self {
        case .power: return "Quick refresh; avoids deep sleep"
        case .short: return "Classic 20-min nap; stay light"
        case .fullCycle: return "One full sleep cycle"
        }
    }
}

struct NapOption: Identifiable, Hashable {
    let id = UUID()
    let kind: NapKind
    let start: Date
    let end: Date
    var durationMinutes: Int { kind.minutes }
}

struct SleepCalculator {
    let cycleMinutes: Int
    let fallAsleepMinutes: Int
    let cycleCounts: [Int]

    init(cycleMinutes: Int = 90, fallAsleepMinutes: Int = 15, cycleCounts: [Int] = [6, 5, 4, 3]) {
        self.cycleMinutes = max(30, cycleMinutes)
        self.fallAsleepMinutes = max(0, fallAsleepMinutes)
        // Normalize to descending so the first option is the earliest bedtime / latest wake (longest sleep).
        self.cycleCounts = cycleCounts.sorted(by: >)
    }

    /// Given a target wake time, return bedtime options for the configured cycle counts.
    /// Bedtime = wake - (cycles * cycleMinutes) - fallAsleepMinutes
    func bedtimes(for wake: Date) -> [BedtimeOption] {
        cycleCounts.map { cycles in
            let sleepDuration = TimeInterval(cycles * cycleMinutes * 60)
            let buffer = TimeInterval(fallAsleepMinutes * 60)
            let bedtime = wake.addingTimeInterval(-(sleepDuration + buffer))
            return BedtimeOption(cycles: cycles, bedtime: bedtime, totalSleep: sleepDuration)
        }
    }

    /// Given a moment the user is lying down, return wake-time options per cycle count.
    func wakeTimes(fromSleepStart start: Date) -> [WakeOption] {
        cycleCounts.map { cycles in
            let sleepDuration = TimeInterval(cycles * cycleMinutes * 60)
            let buffer = TimeInterval(fallAsleepMinutes * 60)
            let wake = start.addingTimeInterval(buffer + sleepDuration)
            return WakeOption(cycles: cycles, wake: wake, totalSleep: sleepDuration)
        }
    }

    /// Nap options starting from a given moment.
    func napOptions(from start: Date) -> [NapOption] {
        NapKind.allCases.map { kind in
            let end = start.addingTimeInterval(TimeInterval(kind.minutes * 60))
            return NapOption(kind: kind, start: start, end: end)
        }
    }

    /// Conservative caffeine cutoff: stop N hours before bedtime. Default 8 hours.
    func caffeineCutoff(for bedtime: Date, cutoffHours: Int = 8) -> Date {
        bedtime.addingTimeInterval(-TimeInterval(cutoffHours * 3600))
    }
}
