import SwiftUI
import StoreKit

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var purchases: PurchaseManager
    @EnvironmentObject var presets: PresetsStore
    @Environment(\.analytics) private var analytics
    @Environment(\.reminders) private var reminders

    @State private var showPaywall = false
    /// Source attribution for paywall presentations from Settings. Set
    /// immediately before flipping `showPaywall = true` so funnel
    /// analytics record the correct trigger feature.
    @State private var paywallTrigger: PremiumFeature = .multipleReminders
    @State private var showingReminderSheet = false
    @State private var bedtimeReminderTime: Date = TimeFormatter.dateByCombining(today: Date(), hour: 22, minute: 30)
    @State private var bedtimeReminderEnabled: Bool = false
    @State private var reminderAuthStatus: ReminderManager.AuthStatus = .notDetermined
    @State private var presetSaveTrigger = 0
    @State private var reminderEnabledTrigger = 0
    /// Mirrors `!PortfolioAnalytics.shared.isOptedOut`. Bound to the
    /// analytics toggle so flipping it routes to `optIn` / `optOut`.
    @State private var analyticsEnabled: Bool = !PortfolioAnalytics.shared.isOptedOut

    var body: some View {
        Form {
            premiumSection
            remindersSection
            sleepAssumptionsSection
            displaySection
            presetsSection
            aboutSection
            moreFromUsSection
            #if DEBUG
            debugSection
            #endif
        }
        .navigationTitle("Settings")
        .task {
            reminderAuthStatus = await reminders.currentStatus()
            bedtimeReminderEnabled = await reminders.pendingIdentifiers().contains("bedtime_reminder")
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(triggeringFeature: paywallTrigger)
                .environmentObject(purchases)
        }
        .hapticSuccess(trigger: presetSaveTrigger)
        .hapticSuccess(trigger: reminderEnabledTrigger)
    }

    // MARK: - Sections

    private var premiumSection: some View {
        Section {
            if purchases.isPremium {
                Label("Premium unlocked", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(Theme.accent)
                Button("Manage subscription") {
                    Task {
                        guard let scene = UIApplication.shared.connectedScenes
                            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
                            ?? UIApplication.shared.connectedScenes.first as? UIWindowScene else {
                            return
                        }
                        try? await AppStore.showManageSubscriptions(in: scene)
                    }
                }
                Button("Restore purchases") {
                    Task { await purchases.restorePurchases() }
                }
            } else if purchases.installTrialActive {
                let remaining = purchases.installTrialDaysRemaining()
                VStack(alignment: .leading, spacing: 4) {
                    Label("Free trial active", systemImage: "sparkles")
                        .foregroundStyle(Theme.accent)
                    Text("All Pro features unlocked. \(remaining) day\(remaining == 1 ? "" : "s") remaining.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button {
                    paywallTrigger = .savedPresets
                    showPaywall = true
                } label: {
                    Text("Unlock permanently").font(.subheadline)
                }
                Button("Restore purchases") {
                    Task { await purchases.restorePurchases() }
                }
            } else {
                Button {
                    paywallTrigger = .savedPresets
                    showPaywall = true
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Unlock everything").font(.headline)
                            Text("One-time \(purchases.lifetimeDisplayPrice). No subscription.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.secondary)
                    }
                }
                Button("Restore purchases") {
                    Task { await purchases.restorePurchases() }
                }
            }
        } header: {
            Text("SleepWindow Premium")
        }
    }

    @ViewBuilder
    private var remindersSection: some View {
        Section {
            Toggle("Bedtime reminder", isOn: $bedtimeReminderEnabled)
                .onChange(of: bedtimeReminderEnabled) { enabled in
                    Task { await handleBedtimeToggle(enabled) }
                }

            if bedtimeReminderEnabled {
                DatePicker("Time", selection: $bedtimeReminderTime, displayedComponents: .hourAndMinute)
                    .onChange(of: bedtimeReminderTime) { _ in
                        Task { await rescheduleBedtime() }
                    }
            }

            if reminderAuthStatus == .denied {
                Text("Notifications are disabled for SleepWindow. Enable them in Settings to use reminders.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Reminders")
        } footer: {
            Text("Free tier: \(PricingConfig.freeReminderSlots) reminder. Unlock for unlimited.")
        }
    }

    private var sleepAssumptionsSection: some View {
        Section {
            Stepper("Fall-asleep buffer: \(settings.fallAsleepMinutes) min",
                    value: $settings.fallAsleepMinutes, in: 0...45, step: 5)
            Stepper("Sleep cycle: \(settings.cycleMinutes) min",
                    value: $settings.cycleMinutes, in: 60...120, step: 5)
            Stepper("Caffeine cutoff: \(settings.caffeineCutoffHours) h before bed",
                    value: $settings.caffeineCutoffHours, in: 4...12)
        } header: {
            Text("Sleep assumptions")
        } footer: {
            Text("Defaults: 90-min cycles, 15-min fall-asleep, 8-hour caffeine cutoff. Adjust to what works for you.")
        }
    }

    private var displaySection: some View {
        Section {
            Toggle("Use 24-hour time", isOn: $settings.use24Hour)
            Picker("Appearance", selection: $settings.appearance) {
                ForEach(SettingsStore.Appearance.allCases) { appearance in
                    Text(appearance.label).tag(appearance)
                }
            }
        } header: {
            Text("Display")
        }
    }

    @ViewBuilder
    private var presetsSection: some View {
        Section {
            if presets.wakePresets.isEmpty {
                Text("No saved wake times yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(presets.wakePresets) { preset in
                    HStack {
                        Text(preset.name)
                        Spacer()
                        Text(String(format: "%02d:%02d", preset.hour, preset.minute))
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete { offsets in presets.removeWakePreset(at: offsets) }
            }
            Button {
                let gate = PremiumGate(purchases: purchases)
                if gate.canSaveAnotherPreset(currentCount: presets.wakePresets.count) {
                    let preset = WakePreset(name: "Preset \(presets.wakePresets.count + 1)", hour: 7, minute: 0)
                    presets.addWakePreset(preset)
                    analytics.track(.presetSaved)
                    presetSaveTrigger &+= 1
                } else {
                    paywallTrigger = .savedPresets
                    showPaywall = true
                }
            } label: {
                Label("Add wake time preset", systemImage: "plus")
            }
        } header: {
            Text("Saved presets")
        } footer: {
            if !PremiumGate(purchases: purchases).isEntitled {
                Text("Free tier: up to \(PricingConfig.freePresetSlots) presets. Unlock for unlimited.")
            }
        }
    }

    private var aboutSection: some View {
        Section {
            Toggle("Share anonymous usage data", isOn: $analyticsEnabled)
                .onChange(of: analyticsEnabled) { newValue in
                    if newValue {
                        PortfolioAnalytics.shared.optIn()
                    } else {
                        PortfolioAnalytics.shared.optOut()
                    }
                }
            Link("Privacy policy", destination: URL(string: PricingConfig.privacyPolicyURL)!)
            Link("Support", destination: URL(string: PricingConfig.supportURL)!)
            LabeledContent("Version", value: Bundle.main.marketingVersion)
        } header: {
            Text("About")
        } footer: {
            Text("Anonymous analytics help us improve SleepWindow. No identifying data is collected. Results are estimates and not medical advice.")
        }
    }

    private var moreFromUsSection: some View {
        Section {
            Link(destination: URL(string: "https://apps.apple.com/app/id6762470335")!) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("HydroLite").font(.body).foregroundStyle(.primary)
                    Text("Simple, friendly hydration tracking.").font(.caption).foregroundStyle(.secondary)
                }
            }
            Link(destination: URL(string: "https://apps.apple.com/app/id6762468976")!) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("WalkCue").font(.body).foregroundStyle(.primary)
                    Text("Step-by-step audio cues for your walks.").font(.caption).foregroundStyle(.secondary)
                }
            }
            Link(destination: URL(string: "https://apps.apple.com/app/id6762492636")!) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("RackTimer").font(.body).foregroundStyle(.primary)
                    Text("Smart rest timer for the gym.").font(.caption).foregroundStyle(.secondary)
                }
            }
        } header: { Text("More from us") } footer: {
            Text("Other useful apps from the same team. Tap to open in the App Store.")
        }
    }

    #if DEBUG
    private var debugSection: some View {
        Section("Developer (DEBUG only)") {
            Button(purchases.isPremium ? "Disable premium (debug)" : "Enable premium (debug)") {
                purchases.debugTogglePremium()
            }
            Text("Wake calcs used today: \(settings.wakeCalcsUsedToday())")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    #endif

    // MARK: - Reminder flow

    private func handleBedtimeToggle(_ enabled: Bool) async {
        guard enabled else {
            reminders.cancel(identifier: "bedtime_reminder")
            return
        }
        let gate = PremiumGate(purchases: purchases)
        let pending = await reminders.pendingIdentifiers()
        let others = pending.filter { $0 != "bedtime_reminder" }.count
        if !gate.canEnableAnotherReminder(currentCount: others) {
            bedtimeReminderEnabled = false
            paywallTrigger = .multipleReminders
            showPaywall = true
            return
        }

        if reminderAuthStatus == .notDetermined {
            let granted = await reminders.requestAuthorization()
            reminderAuthStatus = granted ? .authorized : .denied
            if !granted {
                bedtimeReminderEnabled = false
                return
            }
        } else if reminderAuthStatus == .denied {
            bedtimeReminderEnabled = false
            return
        }

        await rescheduleBedtime()
        analytics.track(.reminderEnabled, properties: ["kind": "bedtime"])
        reminderEnabledTrigger &+= 1
    }

    private func rescheduleBedtime() async {
        let hm = TimeFormatter.hourMinute(bedtimeReminderTime)
        do {
            try await reminders.scheduleDailyReminder(
                identifier: "bedtime_reminder",
                title: "Wind down",
                body: "Heads up — your target bedtime is near.",
                hour: hm.hour,
                minute: hm.minute
            )
        } catch {
            bedtimeReminderEnabled = false
        }
    }
}

private extension Bundle {
    var marketingVersion: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "unknown"
    }
}
