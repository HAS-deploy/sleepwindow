import Foundation

/// Single source of truth for pricing. Change values here, not scattered through the app.
/// `productID` must match the product configured in App Store Connect and in
/// `Configuration.storekit` for local sandbox testing.
enum PricingConfig {
    /// Lifetime unlock product identifier.
    static let lifetimeProductID = "com.sleepwindow.app.lifetime"

    /// Fallback display price if StoreKit hasn't loaded yet or is unreachable.
    /// Actual price charged is whatever App Store Connect returns for the product.
    static let fallbackLifetimeDisplayPrice = "$7.99"

    /// Copy used on the paywall title.
    static let paywallTitle = "Unlock SleepWindow"
    static let paywallSubtitle = "One-time purchase. No subscriptions."

    /// Bullet points shown on the paywall.
    static let paywallBenefits: [String] = [
        "Unlimited wake-time calculations",
        "Nap planner with three nap types",
        "Caffeine cutoff planner",
        "Unlimited saved presets",
        "Unlimited bedtime reminders"
    ]

    /// Free-tier daily limit on wake-time calculations. Set to `Int.max` to disable.
    static let freeWakeCalculationsPerDay = 3

    /// Free-tier reminders cap.
    static let freeReminderSlots = 1

    /// Free-tier preset cap.
    static let freePresetSlots = 2
}
