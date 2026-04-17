import XCTest
@testable import SleepWindow

final class PremiumGateTests: XCTestCase {

    func testFreeUserAllowedBedtimeCalculator() {
        let gate = PremiumGate(isPremium: false)
        XCTAssertTrue(gate.isAllowed(.bedtimeCalculator))
    }

    func testFreeUserBlockedFromPremiumOnlyFeatures() {
        let gate = PremiumGate(isPremium: false)
        XCTAssertFalse(gate.isAllowed(.napPlanner))
        XCTAssertFalse(gate.isAllowed(.caffeineCutoff))
        XCTAssertFalse(gate.isAllowed(.savedPresets))
        XCTAssertFalse(gate.isAllowed(.multipleReminders))
    }

    func testPremiumAllowedEverything() {
        let gate = PremiumGate(isPremium: true)
        for feature in [
            PremiumFeature.bedtimeCalculator,
            .wakeTimeCalculator,
            .napPlanner,
            .caffeineCutoff,
            .savedPresets,
            .multipleReminders
        ] {
            XCTAssertTrue(gate.isAllowed(feature), "Premium should allow \(feature)")
        }
    }

    func testWakeCalculatorDailyLimit() {
        let gate = PremiumGate(isPremium: false)
        XCTAssertTrue(gate.canUseWakeCalculator(timesUsedToday: 0))
        XCTAssertTrue(gate.canUseWakeCalculator(timesUsedToday: PricingConfig.freeWakeCalculationsPerDay - 1))
        XCTAssertFalse(gate.canUseWakeCalculator(timesUsedToday: PricingConfig.freeWakeCalculationsPerDay))
        XCTAssertFalse(gate.canUseWakeCalculator(timesUsedToday: 999))
    }

    func testPremiumWakeCalculatorUnlimited() {
        let gate = PremiumGate(isPremium: true)
        XCTAssertTrue(gate.canUseWakeCalculator(timesUsedToday: 1_000_000))
    }

    func testPresetsLimit() {
        let free = PremiumGate(isPremium: false)
        XCTAssertTrue(free.canSaveAnotherPreset(currentCount: 0))
        XCTAssertFalse(free.canSaveAnotherPreset(currentCount: PricingConfig.freePresetSlots))
        let premium = PremiumGate(isPremium: true)
        XCTAssertTrue(premium.canSaveAnotherPreset(currentCount: 9999))
    }

    func testReminderLimit() {
        let free = PremiumGate(isPremium: false)
        XCTAssertTrue(free.canEnableAnotherReminder(currentCount: 0))
        XCTAssertFalse(free.canEnableAnotherReminder(currentCount: PricingConfig.freeReminderSlots))
    }
}
