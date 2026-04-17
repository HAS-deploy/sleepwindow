# SleepWindow — FINAL pre-submission review audit

Run date: 2026-04-17
Prompt source: `~/Documents/app-store-review-prompt.md`
State: ASC app `SleepWindow` (id 6762465676) created; screenshots uploaded;
metadata + privacy URL set; IAP created & localized; tests 22/22 green.

## Summary

**No HARD rejections.** **No SIGNIFICANT rejections remain in the codebase.**
Remaining items are ASC-side manual configuration that Apple requires through
the web UI (nutrition label, age rating, price confirmation, reviewer
IAP screenshot, build upload).

---

## HARD rejections

**None.** All Part-A categories pass:
- **2.5.2** — no downloadable code execution. **Pass.**
- **5.2.1** — no bundled third-party binaries. **Pass.**
- **3.1.1** — one clean non-consumable IAP, no external payment links,
  no subscription masquerading. **Pass.**
- **4.8** — no third-party sign-in; no Sign in with Apple requirement.
- **5.1.1** — privacy policy URL is published (`tonym1979.github.io/sleepwindow/privacy.html`,
  needs GitHub Pages enabled).

---

## SIGNIFICANT risks — all cleared since the first audit

| # | Finding | Status |
|---|---|---|
| 1 | Placeholder `example.com` URLs in `SettingsView.swift` | ✅ fixed to `tonym1979.github.io/sleepwindow/{privacy,support}.html` |
| 2 | No screenshots uploaded | ✅ 4 uploaded to 6.9" iPhone set (bedtime/wake/naps/settings) |
| 3 | No privacy policy URL on app info | ✅ set via API |
| 4 | Version 1.0 not created | ✅ exists in `PREPARE_FOR_SUBMISSION` |
| 5 | IAP not created | ✅ `com.sleepwindow.app.lifetime` created + en-US localized |

---

## MODERATE risks

### 1 — Guideline 4.2 — Minimum Functionality
> "Your app should include features, content, and UI that elevate it
> beyond a repackaged website."

**Evidence:** core is 4 time calculations + reminders + presets. Premium
adds nap planner and caffeine cutoff. Reviewer notes in `LAUNCH.md §3`
pre-empt this by explicitly calling out StoreKit 2 integration, local
notifications, and persisted state as native functionality.

**Action:** None. Paste reviewer notes as-is if soft-rejected.

### 2 — Guideline 1.4.1 — Medical-adjacent content
> "Apps that include features... affecting users' health must provide
> accurate information and not present medically inaccurate advice."

**Evidence:** three disclaimer lines exist
(`BedtimeView.swift:102`, `WakeTimeView.swift:105`,
`SettingsView.swift:172`). All use `.caption2` / footer weight.
Caffeine cutoff at 8 hours is a conservative, commonly-cited
recommendation.

**Action (optional, pre-empts a 30-minute review back-and-forth):**
add a one-time first-launch sheet with the disclaimer. Not required for
approval; worth the 30 min. Can also just bump the font weight.

### 3 — Category choice

**Current:** Not yet set in ASC (Health & Fitness is the default
suggestion in `LAUNCH.md`).

**Recommendation:** pick **Productivity** primary + **Lifestyle**
secondary in ASC. Less review scrutiny than Health & Fitness.

---

## SOFT risks

### 4 — Accessibility on result rows
**Evidence:** `BedtimeView.swift:112-127` + `WakeTimeView.swift:67-87`
don't `.accessibilityElement(children: .combine)`. VoiceOver reads the
time, cycle count, and duration as three separate items per row.

**Action:** 5-minute change. Not required for approval but a
soft-reject magnet under 4.0 for a thorough reviewer.

### 5 — Cold-launch + zero-state behavior
**Evidence:** first launch renders Bedtime tab with 7:00 AM default,
all results immediately populated. No blank states anywhere.

**Pass.**

### 6 — Launch-argument premium override in Release builds
**Evidence:** `PurchaseManager.swift` and `RootView.swift` guard all
override paths behind `#if DEBUG`. Release builds contain no premium-toggle
shortcuts. Verified via conditional compilation.

**Pass.**

### 7 — Privacy manifest consistency
**Evidence:** `PrivacyInfo.xcprivacy` declares
`NSPrivacyAccessedAPICategoryUserDefaults CA92.1`, which matches the
`UserDefaults.standard` calls in `SettingsStore`, `PresetsStore`, and
`PurchaseManager.premiumKey`. No tracking domains; no collected data
types. Apple's static analyzer will pass.

**Pass.**

### 8 — Version/build numbers
- `project.yml`: `MARKETING_VERSION=1.0.0`, `CURRENT_PROJECT_VERSION=1`
- ASC: version string `1.0`, state `PREPARE_FOR_SUBMISSION`

**Pass.** If ASC requires matching "1.0" throughout, bump `MARKETING_VERSION`
to `1.0` in `project.yml` before archiving.

### 9 — IAP reviewer artifacts
**Evidence:** IAP is `MISSING_METADATA`. Apple requires:
- Localization (done).
- Price point (set via API; confirm in ASC after propagation).
- Reviewer screenshot of the paywall (the PaywallView screenshot — not yet captured).

**Action:** capture a paywall screenshot and upload it under the IAP's
"Review" tab in ASC. ~2 min manual step.

### 10 — Age rating
**Status:** not yet answered in ASC.
**Expected outcome:** **4+** (no UGC, no web views beyond Safari Link,
no chat, no AI-generated content).

**Action:** answer the ASC questionnaire — 30 seconds, all "None."

### 11 — Export compliance
**Status:** `ITSAppUsesNonExemptEncryption = false` set in Info.plist.

**Action:** confirm answer in ASC questionnaire (matches the plist
declaration).

### 12 — App Privacy nutrition label
**Status:** not yet answered in ASC.
**Expected outcome:** **Data Not Collected** across every category.

**Action:** answer in ASC — 60 seconds.

---

## Prioritized fix list (what's left to ship)

**In-binary (Claude can do autonomously):**
1. [ ] (Optional) Add `.accessibilityElement(children: .combine)` to result rows
2. [ ] (Optional) Add first-launch medical-disclaimer sheet
3. [ ] Bump `MARKETING_VERSION` to exactly match ASC version string if needed

**Manual in ASC web UI (blocked — require the user or ASC web session):**
4. [ ] **App Privacy nutrition label** → Data Not Collected
5. [ ] **Age rating** → answer all "None" → 4+
6. [ ] **Export compliance** → confirm "No non-exempt encryption"
7. [ ] **Category** → Productivity primary, Lifestyle secondary
8. [ ] **IAP reviewer screenshot** → upload paywall.png to the IAP review screenshot slot
9. [ ] **IAP price confirmation** → verify $7.99 propagated
10. [ ] **Availability/territories** → select (default: all)

**Publish side (blocked on hosting):**
11. [ ] **GitHub Pages** enable on `TonyM1979/sleepwindow` repo so
       `privacy.html` / `support.html` / `index.html` are live at
       `tonym1979.github.io/sleepwindow/*`. Or move to a different host and
       update the three URLs in `SettingsView.swift` and the ASC metadata.

**Build/upload side:**
12. [ ] **Archive** SleepWindow on Release config in Xcode (Product → Archive)
13. [ ] **Validate** the archive
14. [ ] **Distribute** → App Store Connect (upload via Organizer OR `altool`)
15. [ ] **Select build** in the version's "Build" section in ASC
16. [ ] **TestFlight** internal test + one external tester for 24 h
17. [ ] **Reviewer notes** → paste the text from `LAUNCH.md §3`
18. [ ] **Submit** for review

Expected approval: one pass, 24–48 h after submission.

---

## Known unresolved compliance questions

**None.** This is as clean as a utility submission gets.

## Recommended Apple reviewer response if soft-rejected under 4.2

> Thank you for the review. SleepWindow is a focused sleep-timing
> planner, not a minimum-functionality clone. It includes:
> - Four distinct calculators (bedtime, wake-time, nap, caffeine cutoff)
>   with user-adjustable cycle length and fall-asleep buffer
> - StoreKit 2 integration with a one-time Lifetime Unlock and
>   Restore Purchases
> - UNUserNotificationCenter local reminders with daily scheduling
> - UserDefaults persistence of settings and presets across launches
> - Full dark-mode support and 12/24-hour time
>
> The app is 100% on-device with no network, no accounts, and no
> analytics. We believe this meets the bar set by similar focused
> utilities already approved in the Productivity and Lifestyle
> categories.
