import Foundation
import SwiftUI

/// Analytics is intentionally abstracted so a real provider can be wired in later
/// without touching call sites. No third-party SDK is included in v1.
enum AnalyticsEvent: String {
    case calculatorUsed = "calculator_used"
    case reminderEnabled = "reminder_enabled"
    case paywallViewed = "paywall_viewed"
    case purchaseStarted = "purchase_started"
    case purchaseCompleted = "purchase_completed"
    case purchaseRestored = "purchase_restored"
    case presetSaved = "preset_saved"
}

protocol AnalyticsService {
    func track(_ event: AnalyticsEvent, properties: [String: String])
}

extension AnalyticsService {
    func track(_ event: AnalyticsEvent) { track(event, properties: [:]) }
}

struct ConsoleAnalytics: AnalyticsService {
    func track(_ event: AnalyticsEvent, properties: [String: String]) {
        #if DEBUG
        let props = properties.isEmpty ? "" : " " + properties.map { "\($0)=\($1)" }.joined(separator: " ")
        print("📊 \(event.rawValue)\(props)")
        #endif
    }
}

struct NoopAnalytics: AnalyticsService {
    func track(_ event: AnalyticsEvent, properties: [String: String]) {}
}

// Environment injection
private struct AnalyticsKey: EnvironmentKey {
    static let defaultValue: AnalyticsService = NoopAnalytics()
}

extension EnvironmentValues {
    var analytics: AnalyticsService {
        get { self[AnalyticsKey.self] }
        set { self[AnalyticsKey.self] = newValue }
    }
}
