import Foundation
import Combine

struct WakePreset: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var hour: Int
    var minute: Int

    init(id: UUID = UUID(), name: String, hour: Int, minute: Int) {
        self.id = id
        self.name = name
        self.hour = max(0, min(23, hour))
        self.minute = max(0, min(59, minute))
    }
}

struct ReminderPreset: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var hour: Int
    var minute: Int
    var kind: Kind

    enum Kind: String, Codable, CaseIterable { case bedtime, windDown }

    init(id: UUID = UUID(), name: String, hour: Int, minute: Int, kind: Kind) {
        self.id = id
        self.name = name
        self.hour = max(0, min(23, hour))
        self.minute = max(0, min(59, minute))
        self.kind = kind
    }
}

final class PresetsStore: ObservableObject {
    private enum Keys {
        static let wakePresets = "presets.wake"
        static let reminderPresets = "presets.reminders"
    }

    @Published private(set) var wakePresets: [WakePreset] = []
    @Published private(set) var reminderPresets: [ReminderPreset] = []

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.wakePresets = Self.decode([WakePreset].self, from: defaults, key: Keys.wakePresets) ?? []
        self.reminderPresets = Self.decode([ReminderPreset].self, from: defaults, key: Keys.reminderPresets) ?? []
    }

    // MARK: - Wake presets

    func addWakePreset(_ preset: WakePreset) {
        wakePresets.append(preset)
        persistWake()
    }

    func removeWakePreset(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) where wakePresets.indices.contains(index) {
            wakePresets.remove(at: index)
        }
        persistWake()
    }

    func removeWakePreset(id: UUID) {
        wakePresets.removeAll { $0.id == id }
        persistWake()
    }

    private func persistWake() {
        if let data = try? JSONEncoder().encode(wakePresets) {
            defaults.set(data, forKey: Keys.wakePresets)
        }
    }

    // MARK: - Reminder presets

    func upsertReminder(_ preset: ReminderPreset) {
        if let idx = reminderPresets.firstIndex(where: { $0.id == preset.id }) {
            reminderPresets[idx] = preset
        } else {
            reminderPresets.append(preset)
        }
        persistReminders()
    }

    func removeReminder(id: UUID) {
        reminderPresets.removeAll { $0.id == id }
        persistReminders()
    }

    private func persistReminders() {
        if let data = try? JSONEncoder().encode(reminderPresets) {
            defaults.set(data, forKey: Keys.reminderPresets)
        }
    }

    // MARK: - Helpers

    private static func decode<T: Decodable>(_ type: T.Type, from defaults: UserDefaults, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
