import SwiftUI

struct WakeTimeView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var purchases: PurchaseManager
    @Environment(\.analytics) private var analytics

    let onGatedTap: (PremiumFeature) -> Void

    @State private var sleepStart: Date = Date()
    @State private var results: [WakeOption] = []
    @State private var showLimitNotice: Bool = false

    private var gate: PremiumGate { PremiumGate(isPremium: purchases.isPremium) }
    private var calc: SleepCalculator { settings.calculator }
    private var isAtFreeLimit: Bool {
        !gate.canUseWakeCalculator(timesUsedToday: settings.wakeCalcsUsedToday())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.stackSpacing) {
                Text("Tap below when you're lying down. We'll suggest wake times that end a full sleep cycle.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                sleepNowButton

                if !results.isEmpty {
                    resultsSection
                }

                if !purchases.isPremium {
                    freeTierNotice
                }

                disclaimer
            }
            .padding()
        }
        .navigationTitle("Wake Time")
        .navigationBarTitleDisplayMode(.large)
        .alert("Daily limit reached", isPresented: $showLimitNotice) {
            Button("Unlock") { onGatedTap(.wakeTimeCalculator) }
            Button("Later", role: .cancel) { }
        } message: {
            Text("Free users can run the wake-time calculator \(PricingConfig.freeWakeCalculationsPerDay) times per day. Unlock for unlimited use.")
        }
    }

    private var sleepNowButton: some View {
        Button {
            handleSleepNow()
        } label: {
            HStack {
                Image(systemName: "bed.double.fill")
                Text("If I fall asleep now")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.accent.opacity(isAtFreeLimit ? 0.6 : 1))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Calculate wake times assuming you fall asleep now.")
    }

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Wake times")
                .font(.headline)
            ForEach(results) { option in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(TimeFormatter.formatted(option.wake, use24Hour: settings.use24Hour))
                            .font(.system(size: 26, weight: .semibold, design: .rounded))
                        Text("\(option.label) · \(TimeFormatter.hoursAndMinutes(option.totalSleep)) of sleep")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            }
            Text("Assumes you fell asleep around \(TimeFormatter.formatted(sleepStart, use24Hour: settings.use24Hour)) plus \(settings.fallAsleepMinutes) min to drift off.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var freeTierNotice: some View {
        let used = settings.wakeCalcsUsedToday()
        let remaining = max(0, PricingConfig.freeWakeCalculationsPerDay - used)
        return Text("Free tier: \(remaining) wake-time calculation\(remaining == 1 ? "" : "s") left today.")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private var disclaimer: some View {
        Text("Results are estimates for planning sleep timing. Not medical advice.")
            .font(.caption2)
            .foregroundStyle(Theme.subtle)
    }

    private func handleSleepNow() {
        if isAtFreeLimit {
            showLimitNotice = true
            return
        }
        let now = Date()
        sleepStart = now
        results = calc.wakeTimes(fromSleepStart: now)
        if !purchases.isPremium { settings.incrementWakeCalcsToday() }
        analytics.track(.calculatorUsed, properties: ["kind": "wake_time"])
    }
}
