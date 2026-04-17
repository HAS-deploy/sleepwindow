import XCTest
@testable import SleepWindow

final class PresetsStoreTests: XCTestCase {

    private var testDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        let suite = "sleepwindow.test.\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() {
        testDefaults?.removePersistentDomain(forName: testDefaults.dictionaryRepresentation().keys.first ?? "")
        testDefaults = nil
        super.tearDown()
    }

    func testAddAndPersistWakePreset() {
        let store = PresetsStore(defaults: testDefaults)
        XCTAssertTrue(store.wakePresets.isEmpty)
        store.addWakePreset(WakePreset(name: "Weekday", hour: 7, minute: 0))

        let reloaded = PresetsStore(defaults: testDefaults)
        XCTAssertEqual(reloaded.wakePresets.count, 1)
        XCTAssertEqual(reloaded.wakePresets.first?.name, "Weekday")
    }

    func testRemoveAtOffsets() {
        let store = PresetsStore(defaults: testDefaults)
        store.addWakePreset(WakePreset(name: "A", hour: 7, minute: 0))
        store.addWakePreset(WakePreset(name: "B", hour: 8, minute: 0))
        store.addWakePreset(WakePreset(name: "C", hour: 9, minute: 0))

        store.removeWakePreset(at: IndexSet(integer: 1))
        XCTAssertEqual(store.wakePresets.map(\.name), ["A", "C"])
    }

    func testWakePresetClampsHourAndMinute() {
        let p = WakePreset(name: "Edge", hour: 99, minute: -5)
        XCTAssertEqual(p.hour, 23)
        XCTAssertEqual(p.minute, 0)
    }

    func testReminderUpsertReplacesExisting() {
        let store = PresetsStore(defaults: testDefaults)
        let id = UUID()
        store.upsertReminder(ReminderPreset(id: id, name: "Bed", hour: 22, minute: 0, kind: .bedtime))
        store.upsertReminder(ReminderPreset(id: id, name: "Bedtime", hour: 23, minute: 30, kind: .bedtime))

        XCTAssertEqual(store.reminderPresets.count, 1)
        XCTAssertEqual(store.reminderPresets.first?.name, "Bedtime")
        XCTAssertEqual(store.reminderPresets.first?.hour, 23)
    }
}
