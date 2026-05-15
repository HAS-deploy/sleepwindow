import SwiftUI

struct PaywallView: View {
    @EnvironmentObject var purchases: PurchaseManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.analytics) private var analytics

    let triggeringFeature: PremiumFeature

    /// True when StoreKit returned no subscription products on this Apple ID
    /// (typical when the products are still DEVELOPER_ACTION_NEEDED in ASC).
    /// Lifetime is non-renewing and unaffected.
    private var subscriptionsUnavailable: Bool {
        purchases.monthlyProduct == nil && purchases.yearlyProduct == nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    benefits
                    if subscriptionsUnavailable {
                        unavailableBanner
                    }
                    yearlyCard
                    monthlyButton
                    lifetimeButton
                    restoreButton
                    if let error = purchases.lastError {
                        Text(error).font(.caption).foregroundStyle(.red)
                    }
                    legalFooter
                }
                .padding()
            }
            .navigationTitle(PricingConfig.paywallTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } }
            }
        }
        .onAppear {
            analytics.track(.paywallViewed, properties: ["feature": triggeringFeature.rawValue])
            PortfolioAnalytics.shared.track(PortfolioEvent.paywallViewed, [
                "source": triggeringFeature.rawValue,
            ])
        }
        .onChange(of: purchases.isPremium) { newValue in
            if newValue { dismiss() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 42))
                .foregroundStyle(Theme.accent)
            Text("Unlock everything").font(.largeTitle.bold())
            Text(PricingConfig.paywallSubtitle).font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(PricingConfig.paywallBenefits, id: \.self) { item in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
                    Text(item)
                }.font(.body)
            }
        }
    }

    /// Shown when StoreKit returned no monthly/yearly products. Tells the user
    /// up-front that subscriptions are temporarily unavailable on this Apple
    /// ID before they tap a non-functional buy button.
    private var unavailableBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text("Subscriptions temporarily unavailable")
                    .font(.subheadline.weight(.semibold))
                Text("Monthly and yearly plans aren't loading on this Apple ID right now. Lifetime is still available, or try again later.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .fill(Color.orange.opacity(0.12))
        )
    }

    // MARK: - Yearly (with 14-day trial)

    private var yearlyCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                analytics.track(.purchaseStarted, properties: ["product": "yearly"])
                PortfolioAnalytics.shared.track(PortfolioEvent.paywallPurchaseClick, [
                    "source": triggeringFeature.rawValue,
                    "product_id": PricingConfig.annualProductID,
                ])
                Task {
                    let before = purchases.isPremium
                    await purchases.purchaseYearly()
                    if purchases.isPremium && !before {
                        analytics.track(.purchaseCompleted, properties: ["product": "yearly"])
                        PortfolioAnalytics.shared.track(PortfolioEvent.paywallPurchaseSuccess, [
                            "is_sub": true,
                            "source": triggeringFeature.rawValue,
                            "product_id": PricingConfig.annualProductID,
                        ])
                    }
                    // paywall.purchase_failed is emitted from PurchaseManager with
                    // a typed PurchaseFailureReason. Don't double-emit here.
                }
            } label: {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("Yearly").font(.headline).foregroundStyle(.white)
                            Text("Best Value")
                                .font(.caption.bold())
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(Color.white.opacity(0.22))
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                        Text(PricingConfig.annualTrialDescription)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    Spacer()
                    Text(purchases.yearlyProduct == nil ? "Unavailable" : "\(purchases.yearlyDisplayPrice)/yr")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16).padding(.horizontal, 16)
                .background(Theme.accent.opacity(purchases.yearlyProduct == nil ? 0.5 : 1))
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(purchases.isPurchasing || purchases.yearlyProduct == nil)

            // 3.1.2(a) forfeiture sentence — rendered inline under the
            // trial offer so the reviewer sees it next to the buy button.
            // Paired with the same line in the bottom disclosure block.
            Text(PricingConfig.disclosureFreeTrial)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - Monthly

    private var monthlyButton: some View {
        Button {
            analytics.track(.purchaseStarted, properties: ["product": "monthly"])
            PortfolioAnalytics.shared.track(PortfolioEvent.paywallPurchaseClick, [
                "source": triggeringFeature.rawValue,
                "product_id": PricingConfig.monthlyProductID,
            ])
            Task {
                let before = purchases.isPremium
                await purchases.purchaseMonthly()
                if purchases.isPremium && !before {
                    analytics.track(.purchaseCompleted, properties: ["product": "monthly"])
                    PortfolioAnalytics.shared.track(PortfolioEvent.paywallPurchaseSuccess, [
                        "is_sub": true,
                        "source": triggeringFeature.rawValue,
                        "product_id": PricingConfig.monthlyProductID,
                    ])
                }
                // paywall.purchase_failed is emitted from PurchaseManager with
                // a typed PurchaseFailureReason. Don't double-emit here.
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Monthly").font(.headline)
                    Text(purchases.monthlyProduct == nil ? "Unavailable on this Apple ID" : "Flexible — cancel anytime")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(purchases.monthlyProduct == nil ? "Unavailable" : "\(purchases.monthlyDisplayPrice)/mo")
                    .font(.headline.monospacedDigit())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14).padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .stroke(Theme.accent.opacity(0.6), lineWidth: 1.5)
                    .background(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous).fill(Color(.secondarySystemBackground)))
            )
            .opacity(purchases.monthlyProduct == nil ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .disabled(purchases.isPurchasing || purchases.monthlyProduct == nil)
    }

    // MARK: - Lifetime

    private var lifetimeButton: some View {
        Button {
            analytics.track(.purchaseStarted, properties: ["product": "lifetime"])
            PortfolioAnalytics.shared.track(PortfolioEvent.paywallPurchaseClick, [
                "source": triggeringFeature.rawValue,
                "product_id": PricingConfig.lifetimeProductID,
            ])
            Task {
                let before = purchases.isPremium
                await purchases.purchaseLifetime()
                if purchases.isPremium && !before {
                    analytics.track(.purchaseCompleted, properties: ["product": "lifetime"])
                    PortfolioAnalytics.shared.track(PortfolioEvent.paywallPurchaseSuccess, [
                        "is_sub": false,
                        "source": triggeringFeature.rawValue,
                        "product_id": PricingConfig.lifetimeProductID,
                    ])
                }
                // paywall.purchase_failed is emitted from PurchaseManager with
                // a typed PurchaseFailureReason. Don't double-emit here.
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Lifetime").font(.headline)
                    Text(purchases.lifetimeProduct == nil ? "Unavailable on this Apple ID" : "One-time unlock · keep forever")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(purchases.lifetimeProduct == nil ? "Unavailable" : purchases.lifetimeDisplayPrice)
                    .font(.headline.monospacedDigit())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14).padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .stroke(Theme.accent.opacity(0.4), lineWidth: 1)
                    .background(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous).fill(Color(.tertiarySystemBackground)))
            )
            .opacity(purchases.lifetimeProduct == nil ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .disabled(purchases.isPurchasing || purchases.lifetimeProduct == nil)
    }

    private var restoreButton: some View {
        Button {
            PortfolioAnalytics.shared.track(PortfolioEvent.paywallRestoreClick)
            Task {
                await purchases.restorePurchases()
                if purchases.isPremium { analytics.track(.purchaseRestored) }
            }
        } label: {
            Text("Restore purchases").font(.subheadline).foregroundStyle(Theme.accent)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Legal footer (3.1.2(a) disclosure block, verbatim from PricingConfig)

    private var legalFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Auto-renewing subscriptions (SleepWindow Premium Monthly, SleepWindow Premium Yearly)")
                .font(.footnote).fontWeight(.semibold)
            // 3.1.2(a) disclosure block — rendered VERBATIM from
            // PricingConfig so paywall copy + ASC metadata stay in lockstep.
            // The free-trial forfeiture sentence appears here AND inline
            // under the yearly card per the canonical pattern.
            VStack(alignment: .leading, spacing: 4) {
                Text("• " + PricingConfig.disclosurePaymentCharged)
                Text("• " + PricingConfig.disclosureAutoRenew)
                Text("• " + PricingConfig.disclosureRenewalCharge)
                Text("• " + PricingConfig.disclosureManage)
                Text("• " + PricingConfig.disclosureFreeTrial)
                Text("• " + PricingConfig.disclosureLifetimeNonConsumable)
            }
            .font(.caption2).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                Link("Terms of Use (EULA)", destination: URL(string: PricingConfig.appleStdEULAURL)!)
                Text("·")
                Link("Privacy Policy", destination: URL(string: PricingConfig.privacyPolicyURL)!)
            }
            .font(.caption2)
        }
        .foregroundStyle(Theme.subtle)
    }
}
