# SleepWindow — adversarial App Store review audit

Run date: 2026-04-17
Prompt source: `~/Documents/app-store-review-prompt.md`
Codebase: `/Users/tony/Developer/sleepwindow` @ pre-submission

## Summary

**No HARD rejections.** Two SIGNIFICANT blockers (both content, not code):
placeholder privacy / terms URLs and missing App Store screenshots. Nothing
in the binary itself should fail review.

---

## HARD rejections

**None identified.** SleepWindow has:
- No network calls except StoreKit (no 5.1.1 data-collection risk)
- No account, no sign-in (no 4.8 Sign in with Apple requirement)
- No bundled code execution / JS runtime (no 2.5.2 issue)
- No bundled third-party redistributable binaries (no 5.2.1)
- One clean non-consumable IAP; no subscriptions, no external-payment
  links (no 3.1.1 / 3.1.3 risk)
- `ITSAppUsesNonExemptEncryption = false`, no CryptoKit use at all in
  this app (no export-compliance surprise)

---

## SIGNIFICANT risks (will cause rejection unless fixed)

### 1 — Guideline 5.1.1 (i) — Data Collection and Storage, "developer's information"
> "Apps that collect user or usage data must... include a link to their
> privacy policy in the App Store Connect metadata field."

**Evidence:** `SleepWindow/Features/Settings/SettingsView.swift:166-167`
— the in-app Privacy Policy and Terms links both point at
`https://example.com/sleepwindow/privacy` / `/terms`, which 404. Reviewer
will click and fail. Also the App Store Connect "Privacy Policy URL" field
is currently empty in our pre-submission state.

**Minimum change:** Publish `docs/privacy-policy.html` (already drafted)
to a real URL (GitHub Pages, Netlify, or a subdomain), then:
- Update `SettingsView.swift:166-167` to point at the live URL.
- Enter the same URL in App Store Connect → App Information → Privacy Policy URL.
- Either publish a Terms page or remove the Terms link (not required by Apple).

### 2 — Guideline 2.3.3 — Accurate metadata / screenshots
> "Screenshots should show the app in use, and not merely the title art,
> log-in page, or splash screen."

**Evidence:** no screenshots exist in the repo or ASC yet. App Store
Connect will reject the submission until 3+ screenshots at the required
sizes (6.9" iPhone Pro Max and 13" iPad) are uploaded.

**Minimum change:** capture 4 screenshots per device class (Bedtime,
Wake, Naps — unlocked premium build, and Settings). Reuse the
`xcrun simctl io booted screenshot` flow we already have working.

---

## MODERATE risks (reviewer questions, not auto-reject)

### 3 — Guideline 4.2 — Minimum Functionality
> "Your app should include features, content, and UI that elevate it
> beyond a repackaged website."

**Evidence:** the app's core is four time calculations (bedtime, wake,
nap, caffeine). A skeptical reviewer could call it thin. Mitigating
factors: reminders with local notifications, preset persistence, a real
paywall with StoreKit 2, and state that survives relaunch. This is
well above "repackaged website" but below rich apps like sleep trackers.

**Minimum change:** none required. If soft-rejected, respond pointing to
StoreKit integration, local notifications scheduling, and persisted
settings/presets as proof of native functionality. `CLAUDE.md`-style
reviewer notes already drafted in `LAUNCH.md` cover this.

### 4 — Guideline 1.4.1 — Physical Harm / medical-adjacent content
> "Apps that include features... affecting users' health must provide
> accurate information and not present medically inaccurate advice."

**Evidence:** the caffeine-cutoff feature (default 8 h before bed) is
health-adjacent. The copy at `BedtimeView.swift:76-77` says "Aim to stop
caffeine by this time…" Disclaimers at `BedtimeView.swift:102`,
`WakeTimeView.swift:105`, and `SettingsView.swift:172` are in place but
small (caption2 / footer). Apple sometimes asks for a more prominent
disclaimer on first launch for apps touching health topics.

**Minimum change:** add a one-time first-launch "About SleepWindow"
sheet that states: "SleepWindow is a timing planner. It is not a medical
device and does not diagnose or treat any condition. Results are
estimates." Dismissible, shown once. This costs ~30 min and pre-empts
the reviewer asking.

### 5 — Category choice

**Evidence:** `LAUNCH.md` suggests Health & Fitness primary. That category
invites closer 1.4/5.1 scrutiny.

**Minimum change:** choose **Productivity** primary + **Lifestyle**
secondary. Slightly less discoverability, materially faster review.

---

## SOFT risks (edge cases, low probability)

### 6 — Guideline 4.0 — Design / Accessibility

**Evidence:** no explicit VoiceOver labels on the bedtime / wake result
cards. The `DatePicker` is fine (native accessibility), but the custom
result rows in `BedtimeView.swift:112-127` and `WakeTimeView.swift:67-87`
don't add `.accessibilityLabel()` composing the time + cycle count +
duration in one VoiceOver read.

**Minimum change:** add `.accessibilityElement(children: .combine)` to
the result row containers so VoiceOver reads "9:45 PM, 6 cycles,
9 hours of sleep" as one item. Five-minute change.

### 7 — Guideline 2.1 — App Completeness / cold launch

**Evidence:** first launch shows Bedtime tab with wake time defaulted to
7:00 AM. Results render immediately. No broken state.
`BedtimeView.swift:15-17` uses a static 7 AM default; harmless.

**Pass.**

### 8 — Version / build numbers

**Evidence:** `project.yml` has `MARKETING_VERSION = 1.0.0`,
`CURRENT_PROJECT_VERSION = 1`. Correct for first submission.

**Pass.**

### 9 — Privacy manifest alignment

**Evidence:** `SleepWindow/Resources/PrivacyInfo.xcprivacy` declares:
- `NSPrivacyTracking = false`
- `NSPrivacyCollectedDataTypes = []`
- One API-access reason: `NSPrivacyAccessedAPICategoryUserDefaults CA92.1`

Code does use `UserDefaults` (all of `SettingsStore`, `PresetsStore`,
`PurchaseManager.premiumKey`). `NotificationService` uses
`UNUserNotificationCenter`, which is not on the required-reasons list.
No tracking SDKs.

**Pass.**

### 10 — Permission strings

**Evidence:** no `NS*UsageDescription` strings are declared, and none
are needed. The only permission requested is notification authorization
(via `UNUserNotificationCenter.requestAuthorization`, which ships its own
copy) — that does not require an Info.plist string. No camera, photo
library, location, microphone, contacts, etc.

**Pass.**

### 11 — Age rating

**Evidence:** no UGC, no web views beyond the privacy-policy Link (which
opens in Safari, not in-app), no chat, no AI-generated content.

**Pass at 4+.**

---

## Prioritized fix list (ship before submission)

1. [ ] **Publish `docs/privacy-policy.html`** to a real URL and update
   `SettingsView.swift:166-167` + App Store Connect Privacy Policy URL.
   Either publish Terms or remove the Terms link (lines 167).
2. [ ] **Capture screenshots**: 4 each on 6.9" iPhone (already have sim)
   and 13" iPad. Use the running simulator and `xcrun simctl io`.
3. [ ] **Add first-launch medical-disclaimer sheet** (30 min) — or at
   minimum bump the three existing disclaimer lines from `.caption2` to
   `.caption` / `.footnote` so they're actually legible.
4. [ ] **Pick Productivity** as primary ASC category (change in ASC after
   app record is created).
5. [ ] **Accessibility labels** on result rows
   (`.accessibilityElement(children: .combine)`).
6. [ ] **Create the app in App Store Connect** (blocked on Issuer ID).
7. [ ] **Create the `com.sleepwindow.app.lifetime` IAP** in ASC.
8. [ ] **Fill out App Privacy nutrition label**: Data Not Collected.
9. [ ] **Export compliance**: exempt, answer No in ASC.
10. [ ] **Reviewer notes**: paste the text from `LAUNCH.md §3` verbatim.
11. [ ] **TestFlight**: at least one external tester for 24 h.

None of items 1–5 are code blockers — they're 30–90 minutes of work each.
Items 6–11 are App Store Connect steps.

---

## Known unresolved compliance questions

None. This is a clean local-first utility submission with a single
non-consumable IAP. Expected approval on first submission after the
fix list above is green.
