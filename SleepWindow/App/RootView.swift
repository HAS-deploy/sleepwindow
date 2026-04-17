import SwiftUI

struct RootView: View {
    @EnvironmentObject var purchases: PurchaseManager
    @State private var selection: Tab = RootView.initialTab()
    @State private var paywallTrigger: PremiumFeature?

    enum Tab: Hashable { case bedtime, wake, naps, settings }

    static func initialTab() -> Tab {
        #if DEBUG
        let value = UserDefaults.standard.string(forKey: "SLEEPWINDOW_INITIAL_TAB")
            ?? ProcessInfo.processInfo.environment["SLEEPWINDOW_INITIAL_TAB"]
        switch value {
        case "wake": return .wake
        case "naps": return .naps
        case "settings": return .settings
        default: return .bedtime
        }
        #else
        return .bedtime
        #endif
    }

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                BedtimeView(onGatedTap: { paywallTrigger = $0 })
            }
            .tabItem { Label("Bedtime", systemImage: "moon.stars") }
            .tag(Tab.bedtime)

            NavigationStack {
                WakeTimeView(onGatedTap: { paywallTrigger = $0 })
            }
            .tabItem { Label("Wake", systemImage: "sun.horizon") }
            .tag(Tab.wake)

            NavigationStack {
                NapsView(onGatedTap: { paywallTrigger = $0 })
            }
            .tabItem { Label("Naps", systemImage: "bed.double") }
            .tag(Tab.naps)

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
            .tag(Tab.settings)
        }
        .tint(Theme.accent)
        .sheet(item: $paywallTrigger) { feature in
            PaywallView(triggeringFeature: feature)
                .environmentObject(purchases)
        }
        .onAppear {
            #if DEBUG
            if UserDefaults.standard.bool(forKey: "SLEEPWINDOW_SHOW_PAYWALL") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    paywallTrigger = .napPlanner
                }
            }
            #endif
        }
    }
}
