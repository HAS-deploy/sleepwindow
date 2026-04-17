# SleepWindow — launch packet

Everything needed to ship v1. Cross-reference with `APP_STORE_PLAN.md` for
the generic submission playbook.

---

## 1. Test plan

### Automated (XCTest — 22 tests)

Run: `xcodebuild -project SleepWindow.xcodeproj -scheme SleepWindow -destination 'platform=iOS Simulator,name=iPhone 15' test`

- `SleepCalculatorTests` — 8 cases. Bedtime math, wake-time math, midnight
  rollover, nap options, caffeine cutoff, fall-asleep buffer edge cases,
  configurable cycle counts.
- `PremiumGateTests` — 7 cases. Free vs. paid allow lists, daily wake-calc
  limit, preset caps, reminder caps.
- `PresetsStoreTests` — 4 cases. Persistence round-trip, index-based
  deletion, hour/minute clamping, upsert-replaces-existing.
- `TimeFormatterTests` — 3 cases. Duration formatting, `DateByCombining`
  preservation, hour/minute round-trip.

All must pass before submission. Any drift from 22 is a blocker.

### Manual (simulator + device)

Run each on iPhone 15, iPhone SE (3rd gen), and one iPad:

1. **Cold launch** — app opens to Bedtime tab in <1 s. Default wake is 07:00.
2. **Bedtime calc** — change wake picker to 06:30. Results update. Results
   are all before wake. Caffeine card shows an upsell in free, a real time
   in premium.
3. **Wake calc — free tier** — tap "If I fall asleep now" 3×. Fourth tap
   shows the alert with "Unlock" and "Later."
4. **Wake calc — midnight** — set device time to 23:45, tap "Sleep now."
   All wake times are the next morning (AM).
5. **Nap planner** — locked in free; shows 3 options in premium.
6. **Settings → Reminders → Bedtime toggle ON** → permission prompt fires
   → "Allow" → reminder scheduled (verify with `notifications` console).
7. **Reminders → deny permission** → toggle snaps back off; friendly copy
   appears. Re-enable requires Settings → SleepWindow → Notifications.
8. **Settings → Presets → add 3 presets as free user** → third attempt
   shows paywall.
9. **Paywall — purchase (StoreKit config)** — tap unlock, sandbox dialog,
   enter password → premium unlocks, paywall dismisses, previously-locked
   cards now show real content.
10. **Paywall — restore purchases** — wipe container (delete app, reinstall) →
    tap Restore → same Apple ID re-grants premium.
11. **Paywall — airplane mode** — fallback price renders, purchase button
    shows friendly error, app doesn't hang.
12. **Dark mode** — every tab; upsell card + accent color render correctly.
13. **24-hour toggle** — every time display re-renders consistently.
14. **Smallest screen (iPhone SE 1st-gen sim or constrained height)** —
    wheel DatePickers are capped to 140pt; buttons not clipped.
15. **Background → foreground** — reminder toggle state preserved; wake
    calc daily count preserved.

---

## 2. QA checklist (pre-submission)

### Calculation correctness
- [ ] Bedtime for wake=07:00 with 5 cycles, 15-min buffer = 23:15 (previous day).
- [ ] Wake for sleep-start=23:30 with 5 cycles, 15-min buffer = 07:15 (next day).
- [ ] Caffeine cutoff 8 h before 23:00 bedtime = 15:00 same day.
- [ ] No AM/PM swap at the 12:00 boundary (verified by inspection: we never
      manually format AM/PM — `DateFormatter` handles it).
- [ ] Negative cycle counts impossible (`SleepCalculator` init guards).
- [ ] Fall-asleep buffer clamped to 0+ (`SleepCalculator` init guards).

### Premium gating
- [ ] Free users cannot access: nap planner, caffeine cutoff, multiple
      reminders, presets beyond 2, wake calc beyond 3/day.
- [ ] Premium users can access all of the above.
- [ ] `debugTogglePremium` stripped from Release via `#if DEBUG`.
- [ ] `isPremium` cached in `UserDefaults` so UI doesn't flicker on launch.

### Purchase flow
- [ ] Purchase persists across relaunch.
- [ ] Restore purchases succeeds on a fresh install with same Apple ID.
- [ ] Purchase failure shows `lastError` in paywall; doesn't crash.
- [ ] Transaction listener running — revoked purchases downgrade the app.

### Notifications
- [ ] Permission prompt triggered only when user toggles bedtime reminder on.
- [ ] `NSUserNotificationUsageDescription` — not needed; prompt presented
      via `requestAuthorization(options:)` handles all copy.
- [ ] Scheduled reminder survives app restart (inspect via
      `pendingIdentifiers()`).
- [ ] Cancelling reminder in-app removes it from pending queue.
- [ ] Denied state shows informative copy.

### Layout / compatibility
- [ ] Builds against iOS 16 SDK target.
- [ ] No compiler warnings.
- [ ] No `onChange(of:)` two-parameter form (iOS 17+ only).
- [ ] Wheel `DatePicker` has `.frame(maxHeight: 140)` everywhere it appears
      so it doesn't overflow smaller screens.
- [ ] Tested on iPhone SE sim.

### Privacy / metadata
- [ ] `PrivacyInfo.xcprivacy` present with zero data collection, zero
      tracking, only the `UserDefaults CA92.1` reason declared.
- [ ] `ITSAppUsesNonExemptEncryption = false` in `Info.plist`.
- [ ] No `NSAppTransportSecurity` exceptions.
- [ ] No analytics SDK dependencies in `Package.swift` / `Podfile` (none
      exist in the repo).
- [ ] Privacy policy URL populated in App Store Connect before submission.

### Copy review
- [ ] No medical claims anywhere. Search: "diagnose", "treat", "cure",
      "insomnia", "medical" → all absent.
- [ ] Disclaimer card present on Bedtime and Wake tabs.
- [ ] Paywall copy says "one-time purchase", not "subscription".

---

## 3. Release checklist

- [ ] Bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml`.
- [ ] `xcodegen generate` after any `project.yml` change.
- [ ] All 22 tests pass.
- [ ] Manual QA checklist (section 2) fully green.
- [ ] App icon rendered and installed in `AppIcon.appiconset` (replace the
      single 1024×1024 placeholder — see icon direction below).
- [ ] Privacy policy URL published and added to App Store Connect.
- [ ] In-app purchase created in App Store Connect (product ID
      `com.sleepwindow.app.lifetime`, $7.99 or chosen tier, non-consumable).
- [ ] Screenshots captured for 6.9" iPhone + 13" iPad (3–5 each).
- [ ] App description, keywords, promotional text entered (see section 4).
- [ ] Export compliance answered (exempt — no non-exempt encryption).
- [ ] Age rating answered → should land at **4+**.
- [ ] App Privacy nutrition label → **Data Not Collected**.
- [ ] Archive on Release config, validate, upload.
- [ ] TestFlight: 1 internal tester + 1 external tester for 24 h.
- [ ] Submit with reviewer notes (see below).
- [ ] On approval: flip manual release.

### Reviewer notes (paste verbatim into App Review Information)

> SleepWindow is a lightweight sleep-timing planner. It helps users pick
> bedtime or wake-time windows aligned to 90-minute sleep cycles, plan
> naps, and plan a caffeine cutoff. It is NOT a sleep tracker, makes no
> medical claims, and never records audio or video.
>
> Architecture: 100% on-device. No account, no sign-in, no network calls
> except StoreKit for the in-app purchase. All settings and presets live
> in UserDefaults.
>
> Permissions requested:
> - Notifications — only when the user toggles a bedtime reminder on in
>   Settings. Used for local reminders only; no remote push.
>
> In-app purchase: one non-consumable, "Lifetime Unlock"
> (com.sleepwindow.app.lifetime). No subscriptions, no introductory offer
> in v1. Restore Purchases is present on the paywall and in Settings.
>
> Free tier: bedtime calculator, 3 wake-time calculations per day,
> 1 reminder, 2 saved presets. Lifetime unlock removes all caps and
> enables the nap planner, caffeine cutoff, and unlimited presets/reminders.

---

## 4. App Store metadata

### Title (30 chars max)
`SleepWindow`

### Subtitle (30 chars max)
`Sleep cycle bedtime planner`

### Keywords (100 chars, comma-separated, no spaces after commas)
`sleep,bedtime,nap,wake,alarm,sleep cycle,caffeine,reminder,bedtime planner,sleep schedule`

### Promotional text (170 chars, editable post-approval)
`Plan bedtime, wake time, and naps around 90-minute sleep cycles. One-time purchase unlocks everything — no subscriptions.`

### Short description (first 2 lines of long description matter most)
`SleepWindow helps you plan sleep timing around 90-minute sleep cycles. Pick a wake time and see when to go to bed — or tap "sleep now" to see when to set your alarm.`

### Long description (draft)

```
SleepWindow helps you plan sleep timing around 90-minute sleep cycles.

Pick a wake time and see when to go to bed — or tap "sleep now" to see
when to set your alarm. Plan naps that end at the right stage. See a
conservative caffeine cutoff for your target bedtime.

Features
• Bedtime calculator — pick your wake time, get ideal bedtime options
• Wake-time calculator — tap "if I fall asleep now," get wake options
• Nap planner — power nap, short nap, full-cycle nap
• Caffeine cutoff — plan when to stop caffeine based on bedtime
• Bedtime reminders — simple, reliable local reminders
• Saved presets — quick access for workdays and weekends
• 12-hour or 24-hour time, light or dark mode

Privacy-first
• No account, no sign-in
• No cloud sync, no analytics SDKs
• Works fully offline

One-time purchase
• Free: bedtime calculator, limited wake-time calculations, one reminder
• Lifetime unlock: everything, forever — no subscriptions, no recurring
  charges

Results are estimates for planning sleep timing. SleepWindow is not a
medical device and does not diagnose, treat, or monitor any condition.
```

### Categories
- **Primary:** Health & Fitness
- **Secondary:** Lifestyle

(If Health & Fitness feels risky given the no-medical-claims stance, use
**Productivity** as primary and **Lifestyle** as secondary — slightly less
discoverability, slightly easier review.)

### Age rating
**4+.** Answer "None" to everything in the questionnaire.

### Privacy policy
Short single page hosted anywhere. Suggested text:

> SleepWindow does not collect, transmit, or store any personal data off
> your device. All settings and presets are stored locally in your iOS
> device's UserDefaults. Apple processes your in-app purchase via the
> App Store; we never see your payment details. We do not use analytics,
> advertising, or tracking SDKs. Contact: <your-email>.

---

## 5. App icon direction

**Concept:** A crescent moon tucked inside a rounded window/frame — doubles
as the "window" in "SleepWindow" and signals nighttime without being cliché.

**Palette:**
- Background gradient: deep indigo (#1a1a3e) to midnight blue (#0f0f2a)
- Moon: warm cream (#f5e6c8) with a soft glow
- Optional: one or two small stars (off-center, small)

**Design rules:**
- No text on the icon (Apple flags text-heavy icons).
- No alpha, no rounded pre-masking — iOS applies the mask.
- Readable at 40×40 pt — the moon shape must survive heavy downscale.
- Keep the window frame subtle; the moon is the hero.

**Deliverable:** 1024×1024 PNG, sRGB, no alpha. Drop into
`SleepWindow/Resources/Assets.xcassets/AppIcon.appiconset/` and update
`Contents.json` if more slot sizes are needed. The current
`Contents.json` declares only the single universal 1024 slot, which Xcode
will auto-scale.

**Generation:** Generate with any icon tool (Figma, Sketch, Affinity,
Bakery, or an AI image model with the prompt above). Budget ~30 min.

---

## 6. Pricing — where to change it

All pricing lives in **one file**: `SleepWindow/Core/Pricing/PricingConfig.swift`.

| Change | Edit |
|---|---|
| Lifetime price | Update price tier in App Store Connect; the app reads `Product.displayPrice` live |
| Fallback price shown while loading | `fallbackLifetimeDisplayPrice` |
| Paywall title / subtitle | `paywallTitle`, `paywallSubtitle` |
| Benefit bullets | `paywallBenefits` |
| Free wake-calc daily limit | `freeWakeCalculationsPerDay` |
| Free reminder count | `freeReminderSlots` |
| Free preset count | `freePresetSlots` |

### Launch pricing recommendation
- **Week 1–2:** $4.99 introductory tier to reduce friction for early
  reviewers and word-of-mouth. Use an **introductory price** in ASC rather
  than hardcoding — the app already reads live `displayPrice`.
- **Week 3+:** raise to $7.99.
- **Annual sale days** (Black Friday, etc.): $3.99 for 3 days via a new
  price tier in ASC. No code change needed.

### Changing the product ID
If App Store Connect rejects `com.sleepwindow.app.lifetime`, change
`PricingConfig.lifetimeProductID` AND the `productID` in
`Configuration.storekit` — they must match.

---

## 7. Assumptions called out

- **StoreKit 2** — requires iOS 15+. Deployment target is iOS 16 so this
  is comfortable.
- **Sleep-cycle timing is approximate.** Research says cycles average
  ~90 min but individuals range 70–110 min. Users can adjust in Settings.
- **Caffeine half-life** varies widely (genetics, tolerance, source).
  The 8-hour cutoff is a conservative rule-of-thumb. Setting range is 4–12 h.
- **Notification permission is requested contextually** — never on first
  launch. The first request fires the first time the user toggles a
  reminder on.
- **No StoreKit "ask to buy" handling** beyond the standard pending state.
  A child-account pending purchase simply displays a friendly message.
- **No localization yet** — strings are English-only. The architecture is
  localization-ready (`SWIFT_EMIT_LOC_STRINGS=YES`, all user-facing strings
  are literals in SwiftUI `Text`). Add `.strings` files when ready.
- **No widget in v1.** Adding a simple "tonight's bedtime" widget is
  2–4 hours of work. Ship v1 first.
- **Mac support = Designed for iPad.** Not a native Mac app — the iOS
  binary runs on Apple Silicon Macs automatically.
- **No analytics provider integrated.** `AnalyticsService` is a protocol
  with a `ConsoleAnalytics` impl that prints in DEBUG only. Wire up a
  provider post-launch by adding a new `AnalyticsService` conformance.
