import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var purchases: PurchaseManager
    @EnvironmentObject var presets: PresetsStore
    @Environment(\.analytics) private var analytics
    @Environment(\.reminders) private var reminders

    @State private var showPaywall = false
    @State private var showingReminderSheet = false
    @State private var bedtimeReminderTime: Date = TimeFormatter.dateByCombining(today: Date(), hour: 22, minute: 30)
    @State private var bedtimeReminderEnabled: Bool = false
    @State private var reminderAuthStatus: ReminderManager.AuthStatus = .notDetermined

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
            PaywallView(triggeringFeature: .multipleReminders)
                .environmentObject(purchases)
        }
    }

    // MARK: - Sections

    private var premiumSection: some View {
        Section {
            if purchases.isPremium {
                Label("Premium unlocked", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(Theme.accent)
            } else {
                Button {
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
                let gate = PremiumGate(isPremium: purchases.isPremium)
                if gate.canSaveAnotherPreset(currentCount: presets.wakePresets.count) {
                    let preset = WakePreset(name: "Preset \(presets.wakePresets.count + 1)", hour: 7, minute: 0)
                    presets.addWakePreset(preset)
                    analytics.track(.presetSaved)
                } else {
                    showPaywall = true
                }
            } label: {
                Label("Add wake time preset", systemImage: "plus")
            }
        } header: {
            Text("Saved presets")
        } footer: {
            if !purchases.isPremium {
                Text("Free tier: up to \(PricingConfig.freePresetSlots) presets. Unlock for unlimited.")
            }
        }
    }

    private var aboutSection: some View {
        Section {
            Link("Privacy policy", destination: URL(string: "https://has-deploy.github.io/sleepwindow/privacy.html")!)
            Link("Support", destination: URL(string: "https://has-deploy.github.io/sleepwindow/support.html")!)
            LabeledContent("Version", value: Bundle.main.marketingVersion)
        } header: {
            Text("About")
        } footer: {
            Text("SleepWindow helps plan sleep timing. Results are estimates and not medical advice.")
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
        let gate = PremiumGate(isPremium: purchases.isPremium)
        let pending = await reminders.pendingIdentifiers()
        let others = pending.filter { $0 != "bedtime_reminder" }.count
        if !gate.canEnableAnotherReminder(currentCount: others) {
            bedtimeReminderEnabled = false
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
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0.0"
    }
}
