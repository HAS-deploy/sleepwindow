# SleepWindow — Portfolio Audit Fix Pass (2026-05-15)

## Summary

3 HARDs fixed, 4 SIGNIFICANTs fixed, 5 POLISH fixed, 1 SIGNIFICANT + 2 POLISH deferred.

Audit doc: `~/Documents/portfolio-audit/03-sleepwindow.md`
Guidelines: `~/Documents/portfolio-audit/FIX_GUIDELINES.md`

## Fixes applied

### HARD

- **H1 — Paywall renders fallback prices when StoreKit returns empty.**
  Fixed in `SleepWindow/Features/Paywall/PaywallView.swift`. Added a
  `subscriptionsUnavailable` computed property and an orange-tinted
  "Subscriptions temporarily unavailable" banner that renders above the price
  tiles when both monthly and yearly products are nil. Each tile now reads
  `purchases.<product> == nil` and renders "Unavailable" + a "Unavailable on
  this Apple ID" subtitle instead of the fallback price string. No
  fabrication of prices.

- **H2 — `NapsView` gate dropped `installTrialActive`.**
  Fixed in `SleepWindow/Features/Naps/NapsView.swift:12`. Changed
  `PremiumGate(isPremium: purchases.isPremium)` to the convenience
  `PremiumGate(purchases: purchases)`, matching every other view. Trial
  cohort now sees the planner, not the upsell.

- **H3 — `Configuration.storekit` ships in Release.**
  Removed from `resources:` in `project.yml:29-33` (with a comment that local
  StoreKit testing should attach via scheme Run/Test action). Also removed
  the build-file entry and `PBXResourcesBuildPhase` reference from
  `SleepWindow.xcodeproj/project.pbxproj` so the current pbxproj on disk no
  longer bundles it. File reference + group entry kept so the file is still
  visible in the Xcode navigator for local-test attach. The pbxproj is in
  `.gitignore` (regenerated via xcodegen from project.yml) — the canonical
  fix is the project.yml change.

### SIGNIFICANT

- **S1 — Manage Subscription deep link.**
  Added a "Manage subscription" button in `SettingsView.premiumSection`
  visible to `isPremium` users. Calls
  `AppStore.showManageSubscriptions(in: scene)`, pulling the active
  `UIWindowScene` from `UIApplication.shared.connectedScenes`. Restore
  Purchases stays as a sibling button.

- **S2 — Analytics opt-out toggle.**
  Added `Toggle("Share anonymous usage data", isOn: $analyticsEnabled)` in
  the About section, backed by `@State analyticsEnabled` seeded from
  `!PortfolioAnalytics.shared.isOptedOut`. `onChange` routes to
  `PortfolioAnalytics.shared.optIn()` / `.optOut()` per the canonical
  Pattern A in FIX_GUIDELINES.md. Footer copy updated to reflect that
  anonymous analytics are now controllable.

- **S3 + P7 — Privacy/Support host mismatch.**
  Added `PricingConfig.supportURL` and pointed both links in
  `SettingsView.aboutSection` at `PricingConfig.privacyPolicyURL` /
  `PricingConfig.supportURL`. Paywall already used these constants.
  Single source of truth is now `sleepwindow-website` GitHub Pages repo.
  **Owner action: verify
  `https://has-deploy.github.io/sleepwindow-website/support.html` actually
  exists.** If not, either (a) create it (mirror the support.html currently
  at `has-deploy.github.io/sleepwindow/support.html`), or (b) flip
  `PricingConfig.supportURL` and `privacyPolicyURL` to the `sleepwindow/`
  host and update ASC privacy URL there.

- **S4 — Paywall `triggeringFeature` always tagged `.multipleReminders`.**
  Replaced the literal in `SettingsView.swift:37` with `paywallTrigger`, a
  new `@State` property of type `PremiumFeature`. Now set immediately before
  each `showPaywall = true`: premium banner tap → `.savedPresets`,
  preset-cap hit → `.savedPresets`, reminder-cap hit →
  `.multipleReminders`. Funnel analytics will attribute correctly.

### POLISH

- **P1 — Lifetime non-consumable disclosure hardcoded inline.**
  Moved to `PricingConfig.disclosureLifetimeNonConsumable` and replaced the
  string literal in `PaywallView.legalFooter`.

- **P2 — `WakeTimeView.freeTierNotice` recomputed counter per render.**
  Added `@State wakeCalcsToday: Int`, seeded on `.onAppear`, bumped in
  `handleSleepNow()` after `incrementWakeCalcsToday()`. `freeTierNotice`
  and `isAtFreeLimit` now read from the cached value.

- **P3 — `BedtimeView.showCaffeineCard` dead state.**
  Deleted.

- **P4 — Locked NapsView fired `calculator_used` on appear.**
  Wrapped the `analytics.track(.calculatorUsed, ...)` call in
  `if gate.isAllowed(.napPlanner)` so only entitled views count.

- **P5 — `Bundle.marketingVersion` fallback was `"1.0.0"`.**
  Changed to `"unknown"` so the fallback isn't silently wrong.

## Deferred

- **P6 — `PortfolioAnalytics.swift:84` first-launch double-fire race.**
  Per the audit note, this lives in `~/Developer/app-factory/swift/` as the
  canonical source. Per-app fixes would drift the schema. Owner action: fix
  in app-factory and re-copy to every app in the portfolio (incl.
  SleepWindow).

- **S3 host-verification follow-up (see above).**

- **ASC-side IAP configuration.** Monthly + yearly are
  `DEVELOPER_ACTION_NEEDED`; lifetime IAP `com.sleepwindow.app.lifetime`
  status not yet confirmed. Not a code change — owner finishes config in
  ASC before next binary upload. Until then, the new H1 banner in the
  paywall covers reviewer-visible behavior cleanly.

## ASC metadata edits needed

None from this pass. Privacy/support URLs in ASC should reference the
`sleepwindow-website` host (already canonical in the paywall). If owner
verifies in S3 follow-up that the `sleepwindow/` host is actually the
canonical one, flip both `PricingConfig.privacyPolicyURL` and
`PricingConfig.supportURL` together AND update the ASC privacy URL.

## Risk notes

- pbxproj manual edits diverge from xcodegen output until the next `xcodegen
  generate` is run. Running xcodegen will reconcile (project.yml is now the
  source of truth and excludes Configuration.storekit). No CI runs xcodegen
  automatically here — owner should run it locally once before the next
  build to keep pbxproj in sync with project.yml. The current pbxproj is
  consistent with what xcodegen would produce.
- No StoreKit plumbing was touched (per HARD constraints). `PurchaseManager`
  is untouched — H1's fix is rendered entirely in `PaywallView`'s read of
  the already-published `monthlyProduct` / `yearlyProduct` / `lifetimeProduct`.
- `installTrialActive` semantics unchanged. H2 was a one-line gate-init bug.

## Files touched

- `project.yml`
- `SleepWindow.xcodeproj/project.pbxproj` (gitignored — local sync only)
- `SleepWindow/Core/Pricing/PricingConfig.swift`
- `SleepWindow/Features/Paywall/PaywallView.swift`
- `SleepWindow/Features/Settings/SettingsView.swift`
- `SleepWindow/Features/Naps/NapsView.swift`
- `SleepWindow/Features/Bedtime/BedtimeView.swift`
- `SleepWindow/Features/WakeTime/WakeTimeView.swift`
