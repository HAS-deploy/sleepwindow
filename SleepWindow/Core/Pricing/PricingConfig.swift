import Foundation

/// Single source of truth for pricing. Update values here, not scattered.
/// Product IDs must match App Store Connect and Configuration.storekit.
enum PricingConfig {
    static let lifetimeProductID  = "com.sleepwindow.app.lifetime"
    static let monthlyProductID   = "com.sleepwindow.app.monthly"
    static let subscriptionGroupID = "sleepwindow_premium"

    static let fallbackLifetimeDisplayPrice = "$7.99"
    static let fallbackMonthlyDisplayPrice  = "$2.99"

    static let allProductIDs: [String] = [monthlyProductID, lifetimeProductID]

    static let paywallTitle    = "Unlock SleepWindow"
    static let paywallSubtitle = "Choose monthly or one-time lifetime unlock."

    static let paywallBenefits: [String] = [
        "Unlimited wake-time calculations",
        "Nap planner with three nap types",
        "Caffeine cutoff planner",
        "Unlimited saved presets",
        "Unlimited bedtime reminders",
    ]

    // Free-tier caps.
    static let freeWakeCalculationsPerDay = 3
    static let freeReminderSlots = 1
    static let freePresetSlots = 2
}
