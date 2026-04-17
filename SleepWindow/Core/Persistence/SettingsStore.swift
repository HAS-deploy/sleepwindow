import Foundation
import SwiftUI
import Combine

/// Lightweight settings backed by UserDefaults. Kept small on purpose.
final class SettingsStore: ObservableObject {
    private enum Keys {
        static let fallAsleepMinutes = "settings.fallAsleepMinutes"
        static let cycleMinutes = "settings.cycleMinutes"
        static let use24Hour = "settings.use24Hour"
        static let caffeineCutoffHours = "settings.caffeineCutoffHours"
        static let appearance = "settings.appearance"
        static let wakeCalcUsesByDay = "settings.wakeCalcUsesByDay" // [yyyy-MM-dd: Int]
    }

    enum Appearance: String, CaseIterable, Identifiable {
        case system, light, dark
        var id: String { rawValue }
        var label: String {
            switch self { case .system: return "System"; case .light: return "Light"; case .dark: return "Dark" }
        }
    }

    @Published var fallAsleepMinutes: Int { didSet { defaults.set(fallAsleepMinutes, forKey: Keys.fallAsleepMinutes) } }
    @Published var cycleMinutes: Int { didSet { defaults.set(cycleMinutes, forKey: Keys.cycleMinutes) } }
    @Published var use24Hour: Bool { didSet { defaults.set(use24Hour, forKey: Keys.use24Hour) } }
    @Published var caffeineCutoffHours: Int { didSet { defaults.set(caffeineCutoffHours, forKey: Keys.caffeineCutoffHours) } }
    @Published var appearance: Appearance {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let fallAsleep = defaults.object(forKey: Keys.fallAsleepMinutes) as? Int ?? 15
        let cycle = defaults.object(forKey: Keys.cycleMinutes) as? Int ?? 90
        let twentyFour = defaults.object(forKey: Keys.use24Hour) as? Bool ?? false
        let caffeine = defaults.object(forKey: Keys.caffeineCutoffHours) as? Int ?? 8
        let appearanceRaw = defaults.string(forKey: Keys.appearance) ?? Appearance.system.rawValue
        self.fallAsleepMinutes = fallAsleep
        self.cycleMinutes = cycle
        self.use24Hour = twentyFour
        self.caffeineCutoffHours = caffeine
        self.appearance = Appearance(rawValue: appearanceRaw) ?? .system
    }

    var forcedColorScheme: ColorScheme? {
        switch appearance {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var calculator: SleepCalculator {
        SleepCalculator(cycleMinutes: cycleMinutes, fallAsleepMinutes: fallAsleepMinutes)
    }

    // MARK: - Daily wake-calculator usage tracking

    private var todayKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: Date())
    }

    func wakeCalcsUsedToday() -> Int {
        let map = defaults.dictionary(forKey: Keys.wakeCalcUsesByDay) as? [String: Int] ?? [:]
        return map[todayKey] ?? 0
    }

    func incrementWakeCalcsToday() {
        var map = defaults.dictionary(forKey: Keys.wakeCalcUsesByDay) as? [String: Int] ?? [:]
        map[todayKey, default: 0] += 1
        // Keep only the last 14 days to avoid growing forever.
        if map.count > 14 {
            let sortedKeys = map.keys.sorted()
            for key in sortedKeys.prefix(map.count - 14) { map.removeValue(forKey: key) }
        }
        defaults.set(map, forKey: Keys.wakeCalcUsesByDay)
        objectWillChange.send()
    }
}
