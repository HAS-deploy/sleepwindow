# SleepWindow

Lightweight paid utility for planning sleep timing. **Not a tracker, not a medical app.**

- **Bedtime calculator** — pick a wake time, get 4 bedtime options aligned to 90-minute sleep cycles.
- **Wake-time calculator** — tap "if I fall asleep now," get wake options aligned to sleep cycles.
- **Nap planner** — 10-min power, 20-min short, 90-min full-cycle.
- **Caffeine cutoff** — conservative stop time based on your target bedtime.
- **Reminders** — local notifications for bedtime.
- **Presets** — save common wake times for workdays / weekends.

100% on-device. No account, no cloud, no network calls, no analytics SDKs.

## Stack

- **SwiftUI**, iOS 16+ universal (iPhone + iPad, Mac via Designed-for-iPad).
- **StoreKit 2** for a one-time lifetime unlock ($7.99 default).
- **UNUserNotificationCenter** for local reminders.
- **UserDefaults** for settings + presets (no CoreData / SwiftData).
- **XCTest** for unit tests.

## Build & Run

### Requirements
- Xcode 15.3+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen` (or `~/.local/bin/xcodegen`)

### First-time generate + run
```bash
cd ~/Developer/sleepwindow
xcodegen generate
open SleepWindow.xcodeproj
```

In Xcode pick the **SleepWindow** scheme and run on an iPhone 15 / iPhone SE simulator.

### Sandbox / local purchase testing

The project includes `SleepWindow/Resources/Configuration.storekit`. In Xcode:

1. Edit scheme → **Run → Options** → **StoreKit Configuration** → select `Configuration.storekit`.
2. Run on a simulator.
3. Tap any locked feature to open the paywall, then "Unlock for $7.99."
4. The purchase completes locally. Restore purchases works against the same local transaction database.
5. For full App Store sandbox: create a sandbox tester in App Store Connect, sign out of the App Store on the device, run the archive build.

### Run tests
```bash
xcodebuild -project SleepWindow.xcodeproj \
  -scheme SleepWindow \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  test
```

## App Store Connect — in-app purchase setup

Create **one** non-consumable in-app purchase:

| Field | Value |
|---|---|
| Reference Name | `Lifetime Unlock` |
| Product ID | `com.sleepwindow.app.lifetime` (must match `PricingConfig.lifetimeProductID`) |
| Type | Non-Consumable |
| Price | USD $7.99 (tier 8) or your chosen tier |
| Display Name | `SleepWindow Lifetime Unlock` |
| Description | `One-time purchase. Unlock every calculator, planner, and unlimited reminders.` |
| Review Screenshot | Screenshot of the paywall screen |

No subscription, no introductory offer in v1. Add a promotional offer later by creating a new SKU and wiring it into `PricingConfig` — pricing copy lives in one file.

## Where pricing lives

One file: `SleepWindow/Core/Pricing/PricingConfig.swift`.

Change the product ID, fallback display price, paywall copy, and all free-tier caps in one place.

## Project layout

```
.
├── README.md
├── APP_STORE_PLAN.md               # Review audit prompt + submission speed-run
├── project.yml                     # XcodeGen spec
├── SleepWindow/
│   ├── SleepWindowApp.swift        # @main, ModelContainer not used
│   ├── App/                        # RootView (TabView), Theme
│   ├── Core/
│   │   ├── Calculator/             # SleepCalculator — pure logic, no UI deps
│   │   ├── Pricing/                # PricingConfig
│   │   ├── Purchases/              # PurchaseManager (StoreKit 2)
│   │   ├── Premium/                # PremiumGate
│   │   ├── Reminders/              # ReminderManager (UNUserNotificationCenter)
│   │   ├── Persistence/            # SettingsStore, PresetsStore (UserDefaults)
│   │   └── Analytics/              # AnalyticsService abstraction
│   ├── Features/
│   │   ├── Bedtime/                # BedtimeView (wake → bedtime + caffeine card)
│   │   ├── WakeTime/               # WakeTimeView ("sleep now")
│   │   ├── Naps/                   # NapsView
│   │   ├── Paywall/                # PaywallView
│   │   └── Settings/               # SettingsView (reminders, presets, display, about)
│   ├── Resources/                  # Info.plist, PrivacyInfo.xcprivacy, Configuration.storekit, Assets
│   └── Support/                    # TimeFormatter
└── SleepWindowTests/               # XCTest — calculator, gates, presets, formatters
```

## Monetization model

- **Free** — Bedtime calculator unlimited. Wake-time calculator limited to 3/day. One reminder. Two saved presets. Nap planner and caffeine cutoff are locked.
- **Lifetime $7.99** — Everything unlocked. No subscription, no recurring charges.

Paywall is triggered contextually (tap a gated feature) — never on first launch.

## Backward compatibility notes

- Deployment target: **iOS 16.0**. StoreKit 2, `NavigationStack`, and `UNUserNotificationCenter` async APIs all work without availability guards.
- No `#Preview` macros (Xcode 15+ only) are used — keeps Xcode 15.0 buildable.
- `onChange(of:)` uses the single-parameter variant to stay compatible with iOS 16 (the two-parameter form is iOS 17+).
- No SwiftData, no Observation framework, no iOS 17+ `@Observable`.
- Wheel DatePicker height is bounded so small-screen (iPhone SE 1st gen simulated as 4") layouts don't clip.

If we need to support **iOS 15**: replace `NavigationStack` with `NavigationView`, keep StoreKit 2 (available since 15), and add `@available(iOS 16.0, *)` guards on specific call sites. Testing burden roughly doubles; skipped for v1.

## QA checklist — see `APP_STORE_PLAN.md` section 2 + the in-repo checklist here

See `APP_STORE_PLAN.md` for the full audit prompt and 7-phase submission speed-run.

Additional SleepWindow-specific QA:
- Wake picker with wake time **earlier than current time** — bedtime should roll to the previous day.
- Sleep-now button at **23:30** — wake options must be next-day morning.
- Free-tier **wake-calc daily limit** — third tap shows the paywall alert; tap 4 on the same day still blocked.
- Settings → bedtime reminder toggle on / off → re-launch app → toggle state matches scheduled notifications.
- Airplane mode: app loads; paywall shows the fallback price and a friendly error.
- Dark mode + light mode — every screen.
- iPhone SE / 13-mini sizes — no clipped date pickers or truncated buttons.

## Privacy

- No network calls except StoreKit for in-app purchase.
- No analytics SDK shipped in v1 (only a console-logging stub behind a protocol).
- No tracking. No `IDFA`. No data collection.
- Privacy manifest declares only `UserDefaults` API-access reason (`CA92.1` — store or access user-preferred settings).

## License

Copyright © 2026. All rights reserved.
