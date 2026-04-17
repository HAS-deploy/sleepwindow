import SwiftUI

struct NapsView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var purchases: PurchaseManager
    @Environment(\.analytics) private var analytics

    let onGatedTap: (PremiumFeature) -> Void

    @State private var start: Date = Date()
    private var calc: SleepCalculator { settings.calculator }
    private var gate: PremiumGate { PremiumGate(isPremium: purchases.isPremium) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.stackSpacing) {
                if gate.isAllowed(.napPlanner) {
                    premiumContent
                } else {
                    locked
                }
            }
            .padding()
        }
        .navigationTitle("Naps")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { analytics.track(.calculatorUsed, properties: ["kind": "nap_view"]) }
    }

    private var premiumContent: some View {
        VStack(alignment: .leading, spacing: Theme.stackSpacing) {
            Text("Plan a nap that ends at the right sleep stage.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Card {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Nap starts at")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    DatePicker("Nap start", selection: $start, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .datePickerStyle(.wheel)
                        .frame(maxHeight: 140)
                }
            }

            Text("Suggested nap options")
                .font(.headline)

            ForEach(calc.napOptions(from: start)) { option in
                Card {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(option.kind.displayName)
                                .font(.headline)
                            Spacer()
                            Text("\(option.durationMinutes) min")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Text("Wake at \(TimeFormatter.formatted(option.end, use24Hour: settings.use24Hour))")
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                        Text(option.kind.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Text("Short naps (under 30 min) avoid deep sleep grogginess. A full 90-min cycle lets you complete one sleep cycle.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var locked: some View {
        VStack(alignment: .leading, spacing: Theme.stackSpacing) {
            Text("Nap planner")
                .font(.largeTitle.bold())
            Text("Plan short, full, or power naps that end at an optimal sleep stage.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            UpsellCard(
                title: "Unlock nap planner",
                message: "Three nap types with wake times aligned to sleep cycles.",
                feature: .napPlanner,
                onTap: onGatedTap
            )
        }
    }
}
