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
    let isPremium: Bool

    /// Is this feature available to the current user?
    func isAllowed(_ feature: PremiumFeature) -> Bool {
        if isPremium { return true }
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
        if isPremium { return true }
        return timesUsedToday < PricingConfig.freeWakeCalculationsPerDay
    }

    func canSaveAnotherPreset(currentCount: Int) -> Bool {
        if isPremium { return true }
        return currentCount < PricingConfig.freePresetSlots
    }

    func canEnableAnotherReminder(currentCount: Int) -> Bool {
        if isPremium { return true }
        return currentCount < PricingConfig.freeReminderSlots
    }
}
