import Foundation

/// Feature keys that can be gated behind premium. Keep rules centralized so
/// the paywall, UI, and unit tests agree on what's free vs. paid.
enum PremiumFeature: String, Identifiable, Hashable {
    case bedtimeCalculator
    case wakeTimeCalculator
    case napPlanner
    case caffeineCutoff
    case multipleReminders
    case savedPresets

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bedtimeCalculator: return "Bedtime Calculator"
        case .wakeTimeCalculator: return "Wake-Time Calculator"
        case .napPlanner: return "Nap Planner"
        case .caffeineCutoff: return "Caffeine Cutoff"
        case .multipleReminders: return "Multiple Reminders"
        case .savedPresets: return "Saved Presets"
        }
    }
}

struct PremiumGate {
    /// True if the user has paid (lifetime / monthly / annual). Stays true
    /// after the install trial expires.
    let isPremium: Bool
    /// True while the user is inside the 14-day install-time trial. Gives
    /// full Pro entitlement without a purchase. Independent of `isPremium`.
    let installTrialActive: Bool

    init(isPremium: Bool, installTrialActive: Bool = false) {
        self.isPremium = isPremium
        self.installTrialActive = installTrialActive
    }

    /// Convenience initializer that reads both flags from the purchase
    /// manager so call sites don't have to remember to pass both.
    @MainActor
    init(purchases: PurchaseManager) {
        self.isPremium = purchases.isPremium
        self.installTrialActive = purchases.installTrialActive
    }

    /// True when the user gets Pro access — either paid or inside the
    /// 14-day install trial. Every gating decision below short-circuits
    /// on this.
    var isEntitled: Bool { isPremium || installTrialActive }

    /// Is this feature available to the current user?
    func isAllowed(_ feature: PremiumFeature) -> Bool {
        if isEntitled { return true }
        switch feature {
        case .bedtimeCalculator:
            return true
        case .wakeTimeCalculator:
            return true // allowed but count-limited elsewhere
        case .napPlanner, .caffeineCutoff, .savedPresets, .multipleReminders:
            return false
        }
    }

    /// Can the user run another wake-time calculation today?
    func canUseWakeCalculator(timesUsedToday: Int) -> Bool {
        if isEntitled { return true }
        return timesUsedToday < PricingConfig.freeWakeCalculationsPerDay
    }

    func canSaveAnotherPreset(currentCount: Int) -> Bool {
        if isEntitled { return true }
        return currentCount < PricingConfig.freePresetSlots
    }

    func canEnableAnotherReminder(currentCount: Int) -> Bool {
        if isEntitled { return true }
        return currentCount < PricingConfig.freeReminderSlots
    }
}
