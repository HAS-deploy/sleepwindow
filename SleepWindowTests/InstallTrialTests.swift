import XCTest
@testable import SleepWindow

/// Covers the 14-day install-time trial:
///   1. Fresh install stamps `firstLaunchAt` and grants full entitlement.
///   2. Inside the 14-day window, `PremiumGate.isEntitled` short-circuits
///      every free-tier cap (calculator quota, presets, reminders).
///   3. After day 14, the user drops back to free-tier behavior.
///   4. Data created during the trial (presets, reminders) is preserved
///      after the trial expires — only gating tightens.
@MainActor
final class InstallTrialTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "sleepwindow.test.installtrial.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    // MARK: - 1. Fresh install grants full Premium for 14 days

    func testFreshInstallStampsFirstLaunchAndActivatesTrial() {
        XCTAssertNil(defaults.object(forKey: PurchaseManager.firstLaunchKey),
                     "Sanity: empty suite should have no first-launch stamp.")

        let now = Date()
        let pm = PurchaseManager(defaults: defaults, now: now)

        XCTAssertNotNil(defaults.object(forKey: PurchaseManager.firstLaunchKey),
                        "First launch should stamp the firstLaunchAt date.")
        XCTAssertTrue(pm.installTrialActive,
                      "Fresh install must activate the install-time trial.")
        XCTAssertFalse(pm.isPremium,
                       "Trial does not imply isPremium — the bool stays false.")
        XCTAssertTrue(pm.isEntitled,
                      "isEntitled must be true during the trial window.")
        XCTAssertEqual(pm.installTrialDaysRemaining(now: now),
                       PurchaseManager.installTrialDays,
                       "Day 0 should report the full 14 days remaining.")
    }

    // MARK: - 2. Gate grants Pro features during the trial

    func testGateGrantsAllProFeaturesDuringTrial() {
        let now = Date()
        let pm = PurchaseManager(defaults: defaults, now: now)
        XCTAssertTrue(pm.installTrialActive)

        let gate = PremiumGate(purchases: pm)

        // Every Pro-only feature should now be allowed.
        XCTAssertTrue(gate.isAllowed(.napPlanner))
        XCTAssertTrue(gate.isAllowed(.caffeineCutoff))
        XCTAssertTrue(gate.isAllowed(.savedPresets))
        XCTAssertTrue(gate.isAllowed(.multipleReminders))

        // Count-limited caps should be uncapped during the trial.
        XCTAssertTrue(gate.canUseWakeCalculator(timesUsedToday: 9_999))
        XCTAssertTrue(gate.canSaveAnotherPreset(currentCount: 9_999))
        XCTAssertTrue(gate.canEnableAnotherReminder(currentCount: 9_999))
    }

    // MARK: - 3. After day 14, gate reverts to free-tier behavior

    func testTrialExpiresAfter14DaysAndGateLocksDown() {
        // Stamp firstLaunchAt 20 days ago, then construct the manager.
        let past = Calendar.current.date(byAdding: .day, value: -20, to: Date())!
        defaults.set(past, forKey: PurchaseManager.firstLaunchKey)

        let now = Date()
        let pm = PurchaseManager(defaults: defaults, now: now)

        XCTAssertFalse(pm.installTrialActive,
                       "After 14 days, the install trial must deactivate.")
        XCTAssertFalse(pm.isPremium,
                       "Trial expiration must NOT silently flip isPremium.")
        XCTAssertFalse(pm.isEntitled,
                       "Post-trial, isEntitled is false until a purchase.")
        XCTAssertEqual(pm.installTrialDaysRemaining(now: now), 0)

        let gate = PremiumGate(purchases: pm)
        XCTAssertFalse(gate.isAllowed(.napPlanner))
        XCTAssertFalse(gate.isAllowed(.caffeineCutoff))
        XCTAssertFalse(gate.isAllowed(.savedPresets))
        XCTAssertFalse(gate.isAllowed(.multipleReminders))
        XCTAssertFalse(gate.canUseWakeCalculator(
            timesUsedToday: PricingConfig.freeWakeCalculationsPerDay))
        XCTAssertFalse(gate.canSaveAnotherPreset(
            currentCount: PricingConfig.freePresetSlots))
        XCTAssertFalse(gate.canEnableAnotherReminder(
            currentCount: PricingConfig.freeReminderSlots))
    }

    // MARK: - 4. Data created during the trial is preserved after expiry

    func testDataPersistsAcrossTrialExpiry() {
        // Day 0: install trial active. Create a couple of presets via the
        // PresetsStore (same persistence layer the UI uses) — they live
        // in UserDefaults and must survive the trial clock rolling over.
        let presets = PresetsStore(defaults: defaults)
        presets.addWakePreset(WakePreset(name: "Weekday", hour: 6, minute: 30))
        presets.addWakePreset(WakePreset(name: "Weekend", hour: 9, minute: 0))
        presets.addWakePreset(WakePreset(name: "Travel",  hour: 5, minute: 45))
        XCTAssertEqual(presets.wakePresets.count, 3,
                       "Preconditions: three trial-era presets saved.")

        // Roll the install clock past day 14 and re-open the manager.
        let past = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        defaults.set(past, forKey: PurchaseManager.firstLaunchKey)
        let pm = PurchaseManager(defaults: defaults, now: Date())
        XCTAssertFalse(pm.isEntitled, "Sanity: trial has ended.")

        // Same suite, same key — the presets must still be there.
        let postTrial = PresetsStore(defaults: defaults)
        XCTAssertEqual(postTrial.wakePresets.count, 3,
                       "Trial-era presets must persist after expiry.")
        XCTAssertEqual(postTrial.wakePresets.map(\.name),
                       ["Weekday", "Weekend", "Travel"])

        // Post-trial: free-tier cap blocks a NEW preset, but the old ones
        // stay readable / deletable — exactly the "data preserved, gating
        // tightens" contract.
        let gate = PremiumGate(purchases: pm)
        XCTAssertFalse(gate.canSaveAnotherPreset(currentCount: postTrial.wakePresets.count))
    }
}
