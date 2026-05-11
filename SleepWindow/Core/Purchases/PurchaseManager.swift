import Foundation
import StoreKit

@MainActor
final class PurchaseManager: ObservableObject {
    @Published private(set) var isPremium: Bool = false
    /// True while the user is inside the 14-day install-time trial window
    /// AND is not yet a paying premium user. Reads/writes flow through
    /// UserDefaults key `sleepwindow.firstLaunchAt` (see `installTrialDays`).
    /// `isEntitled` should be preferred over reading this directly.
    @Published private(set) var installTrialActive: Bool = false
    @Published private(set) var lifetimeProduct: Product?
    @Published private(set) var monthlyProduct: Product?
    @Published private(set) var yearlyProduct: Product?
    @Published private(set) var isPurchasing: Bool = false
    @Published var lastError: String?
    /// Set on each purchase attempt so the PaywallView can emit a properly
    /// tagged analytics event distinguishing user-cancel / pending / errors.
    /// Cleared at the start of each new attempt.
    @Published private(set) var lastFailureReason: String?

    private var updatesTask: Task<Void, Never>?
    private let premiumKey = "sleepwindow.isPremium"
    /// UserDefaults key. Set on first launch, read on every subsequent
    /// launch to compute trial state. Never reset by the app itself —
    /// uninstall/reinstall starts a fresh trial (Apple-side trial gating
    /// still applies to paid intro offers).
    static let firstLaunchKey = "sleepwindow.firstLaunchAt"
    /// 14-day install-time trial (matches `PricingConfig.annualTrialDays`).
    static let installTrialDays: Int = PricingConfig.annualTrialDays
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard, now: Date = Date()) {
        self.defaults = defaults
        var initial = defaults.bool(forKey: premiumKey)
        #if DEBUG
        if ProcessInfo.processInfo.environment["SLEEPWINDOW_FORCE_PREMIUM"] == "1"
            || defaults.bool(forKey: "SLEEPWINDOW_FORCE_PREMIUM") {
            initial = true
        }
        #endif
        self.isPremium = initial
        stampFirstLaunchIfNeeded(now: now)
        self.installTrialActive = Self.computeInstallTrialActive(
            isPremium: initial,
            firstLaunchAt: defaults.object(forKey: Self.firstLaunchKey) as? Date,
            now: now
        )
    }

    /// True if this user is currently entitled to Pro features — either
    /// because they paid (`isPremium`) or because they're inside the
    /// 14-day install-time trial. Call sites should prefer this over
    /// reading `isPremium` directly when deciding whether to gate UI.
    var isEntitled: Bool { isPremium || installTrialActive }

    /// Number of days remaining in the install-time trial. Returns 0 once
    /// the trial has elapsed; returns `installTrialDays` if the clock has
    /// not been stamped yet (shouldn't happen after init).
    func installTrialDaysRemaining(now: Date = Date()) -> Int {
        guard !isPremium else { return 0 }
        guard let start = defaults.object(forKey: Self.firstLaunchKey) as? Date else {
            return Self.installTrialDays
        }
        let elapsed = Calendar.current.dateComponents([.day], from: start, to: now).day ?? 0
        return max(0, Self.installTrialDays - elapsed)
    }

    /// Recompute `installTrialActive` against `now`. Called from
    /// `start()` and exposed so a future scene-foreground hook can keep
    /// the published value fresh as days roll over.
    func refreshInstallTrial(now: Date = Date()) {
        installTrialActive = Self.computeInstallTrialActive(
            isPremium: isPremium,
            firstLaunchAt: defaults.object(forKey: Self.firstLaunchKey) as? Date,
            now: now
        )
    }

    private func stampFirstLaunchIfNeeded(now: Date) {
        if defaults.object(forKey: Self.firstLaunchKey) as? Date == nil {
            defaults.set(now, forKey: Self.firstLaunchKey)
        }
    }

    private static func computeInstallTrialActive(isPremium: Bool,
                                                  firstLaunchAt: Date?,
                                                  now: Date) -> Bool {
        guard !isPremium else { return false }
        guard let start = firstLaunchAt else { return true }
        let elapsed = Calendar.current.dateComponents([.day], from: start, to: now).day ?? 0
        return elapsed < installTrialDays
    }

    deinit { updatesTask?.cancel() }

    func start() async {
        await loadProducts()
        await refreshEntitlements()
        refreshInstallTrial()
        observeTransactionUpdates()
    }

    var lifetimeDisplayPrice: String {
        lifetimeProduct?.displayPrice ?? PricingConfig.fallbackLifetimeDisplayPrice
    }

    var monthlyDisplayPrice: String {
        monthlyProduct?.displayPrice ?? PricingConfig.fallbackMonthlyDisplayPrice
    }

    var yearlyDisplayPrice: String {
        yearlyProduct?.displayPrice ?? PricingConfig.fallbackAnnualDisplayPrice
    }

    func loadProducts() async {
        do {
            let products = try await Product.products(for: PricingConfig.allProductIDs)
            self.lifetimeProduct = products.first { $0.id == PricingConfig.lifetimeProductID }
            self.monthlyProduct  = products.first { $0.id == PricingConfig.monthlyProductID }
            self.yearlyProduct   = products.first { $0.id == PricingConfig.annualProductID }
        } catch {
            self.lastError = "Couldn't load the store. Check your connection and try again."
        }
    }

    func purchaseLifetime() async {
        guard let product = lifetimeProduct else {
            self.lastError = "Product unavailable. Try again in a moment."
            return
        }
        await purchase(product)
    }

    func purchaseMonthly() async {
        guard let product = monthlyProduct else {
            self.lastError = "Product unavailable. Try again in a moment."
            return
        }
        await purchase(product)
    }

    func purchaseYearly() async {
        guard let product = yearlyProduct else {
            self.lastError = "Product unavailable. Try again in a moment."
            return
        }
        await purchase(product)
    }

    private func purchase(_ product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }
        lastFailureReason = nil
        do {
            let result = try await product.purchase()
            try await handle(result: result, product: product)
        } catch {
            self.lastError = error.localizedDescription
            self.lastFailureReason = error.localizedDescription
            PortfolioAnalytics.shared.trackPaywallFailure(productId: product.id, error: error)
        }
    }

    private func handle(result: Product.PurchaseResult, product: Product) async throws {
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            setPremium(true)
            await transaction.finish()
        case .userCancelled:
            lastFailureReason = "user_cancelled"
            PortfolioAnalytics.shared.trackPaywallFailure(productId: product.id, reason: .userCanceled)
        case .pending:
            self.lastError = "Purchase is pending approval."
            lastFailureReason = "pending_approval"
            PortfolioAnalytics.shared.trackPaywallFailure(productId: product.id, reason: .pending)
        @unknown default:
            lastFailureReason = "storekit_unknown_case"
            PortfolioAnalytics.shared.trackPaywallFailure(productId: product.id, reason: .unknown)
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            if !isPremium { self.lastError = "No previous purchases found on this Apple ID." }
        } catch {
            self.lastError = error.localizedDescription
        }
    }

    private func refreshEntitlements() async {
        #if DEBUG
        if ProcessInfo.processInfo.environment["SLEEPWINDOW_FORCE_PREMIUM"] == "1"
            || UserDefaults.standard.bool(forKey: "SLEEPWINDOW_FORCE_PREMIUM") {
            setPremium(true); return
        }
        #endif
        var entitled = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               PricingConfig.allProductIDs.contains(transaction.productID),
               transaction.revocationDate == nil {
                entitled = true
            }
        }
        setPremium(entitled)
    }

    private func observeTransactionUpdates() {
        updatesTask?.cancel()
        updatesTask = Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = result {
                    await self.handleVerifiedUpdate(transaction)
                }
            }
        }
    }

    private func handleVerifiedUpdate(_ transaction: Transaction) async {
        if PricingConfig.allProductIDs.contains(transaction.productID),
           transaction.revocationDate == nil {
            setPremium(true)
        } else if transaction.revocationDate != nil {
            await refreshEntitlements()
        }
        await transaction.finish()
    }

    private func setPremium(_ value: Bool) {
        self.isPremium = value
        defaults.set(value, forKey: premiumKey)
        // Premium overrides the trial flag — once paid, `installTrialActive`
        // must read false so analytics / UI don't double-count.
        refreshInstallTrial()
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw PurchaseError.failedVerification
        case .verified(let value): return value
        }
    }

    enum PurchaseError: LocalizedError {
        case failedVerification
        var errorDescription: String? { "Purchase could not be verified." }
    }

    #if DEBUG
    func debugTogglePremium() { setPremium(!isPremium) }
    #endif
}
