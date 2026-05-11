import Foundation

/// Source of truth for StoreKit product identifiers. Must match the IDs
/// registered in App Store Connect exactly. Do not derive these from user
/// input or rename in place — shipped receipts carry these as literals.
enum ProductIDs {
    static let monthly  = "com.sleepwindow.app.monthly"
    static let yearly   = "com.sleepwindow.app.yearly"
    static let lifetime = "com.sleepwindow.app.lifetime"

    static let subscriptionGroup = "sleepwindow_premium"

    /// Full product-ID set the app queries at launch. Order is display
    /// order in the primary paywall (yearly, monthly, lifetime).
    static let all: [String] = [monthly, yearly, lifetime]

    enum Tier {
        case monthly
        case yearly
        case lifetime
    }

    static func tier(for productId: String) -> Tier? {
        switch productId {
        case monthly: return .monthly
        case yearly: return .yearly
        case lifetime: return .lifetime
        default: return nil
        }
    }
}
