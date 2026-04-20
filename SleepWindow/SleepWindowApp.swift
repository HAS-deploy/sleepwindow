import SwiftUI

@main
struct SleepWindowApp: App {
    @StateObject private var purchases = PurchaseManager()
    @StateObject private var settings = SettingsStore()
    @StateObject private var presets = PresetsStore()
    private let analytics: AnalyticsService = ConsoleAnalytics()
    private let reminders = ReminderManager()

    init() {
        PortfolioAnalytics.shared.start(appName: "sleepwindow")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(purchases)
                .environmentObject(settings)
                .environmentObject(presets)
                .environment(\.analytics, analytics)
                .environment(\.reminders, reminders)
                .task { await purchases.start() }
                .preferredColorScheme(settings.forcedColorScheme)
        }
    }
}
