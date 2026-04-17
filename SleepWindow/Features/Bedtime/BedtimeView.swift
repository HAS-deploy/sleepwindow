import SwiftUI

struct BedtimeView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var purchases: PurchaseManager
    @Environment(\.analytics) private var analytics

    let onGatedTap: (PremiumFeature) -> Void

    @State private var wakeTime: Date = defaultWake()
    @State private var showCaffeineCard: Bool = true

    private static func defaultWake() -> Date {
        TimeFormatter.dateByCombining(today: Date(), hour: 7, minute: 0)
    }

    private var calc: SleepCalculator { settings.calculator }
    private var gate: PremiumGate { PremiumGate(isPremium: purchases.isPremium) }

    private var bedtimes: [BedtimeOption] {
        // Make sure the computed bedtimes are *before* the wake time (rolls back one day if needed).
        calc.bedtimes(for: wakeTime)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.stackSpacing) {
                header
                wakePicker
                resultsSection
                caffeineSection
                disclaimer
            }
            .padding()
            .padding(.bottom, 24)
        }
        .navigationTitle("Bedtime")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { analytics.track(.calculatorUsed, properties: ["kind": "bedtime_view"]) }
    }

    private var header: some View {
        Text("Pick your wake time. We'll suggest bedtimes that end a full sleep cycle.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private var wakePicker: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Wake at")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                DatePicker("Wake time", selection: $wakeTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.wheel)
                    .frame(maxHeight: 140)
            }
        }
    }

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Go to bed at one of these times")
                .font(.headline)
            ForEach(bedtimes) { option in
                BedtimeResultRow(option: option, use24Hour: settings.use24Hour)
            }
            Text("Based on \(settings.fallAsleepMinutes) min to fall asleep and \(settings.cycleMinutes) min cycles.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var caffeineSection: some View {
        if gate.isAllowed(.caffeineCutoff) {
            let earliest = bedtimes.map(\.bedtime).min() ?? wakeTime
            let cutoff = calc.caffeineCutoff(for: earliest, cutoffHours: settings.caffeineCutoffHours)
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Caffeine cutoff", systemImage: "cup.and.saucer")
                        .font(.headline)
                    Text(TimeFormatter.formatted(cutoff, use24Hour: settings.use24Hour))
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                    Text("Aim to stop caffeine by this time, \(settings.caffeineCutoffHours) hours before your earliest bedtime option.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            UpsellCard(
                title: "Caffeine cutoff planner",
                message: "See when to stop caffeine based on your target bedtime.",
                feature: .caffeineCutoff,
                onTap: onGatedTap
            )
        }
    }

    private var disclaimer: some View {
        Text("Results are estimates for planning sleep timing. Not medical advice.")
            .font(.caption2)
            .foregroundStyle(Theme.subtle)
    }
}

private struct BedtimeResultRow: View {
    let option: BedtimeOption
    let use24Hour: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(TimeFormatter.formatted(option.bedtime, use24Hour: use24Hour))
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
}

struct UpsellCard: View {
    let title: String
    let message: String
    let feature: PremiumFeature
    let onTap: (PremiumFeature) -> Void

    var body: some View {
        Button { onTap(feature) } label: {
            VStack(alignment: .leading, spacing: 8) {
                Label(title, systemImage: "lock.fill")
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Unlock for a one-time purchase")
                    .font(.caption)
                    .foregroundStyle(Theme.accent)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
