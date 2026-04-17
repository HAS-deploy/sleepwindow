# SleepWindow — Adversarial App Store Review Audit (FINAL)

**Run date:** 2026-04-17
**Reviewer persona:** Apple App Store Review
**Target:** `/Users/tony/Developer/sleepwindow` @ current HEAD
**ASC app ID:** 6762465676
**Prior state:** v1.0 rejected under 2.1, reviewer notes + demo video now attached and resubmitted.
**Verdict:** **Two HARD blockers + two SIGNIFICANT** must clear before the reviewer clicks a link.

## HARD

### H1 — 2.1 + 5.1.1 — Privacy policy URL returns 404
- `SettingsView.swift:166` links `https://has-deploy.github.io/sleepwindow/privacy.html` — returns HTTP 404.
- Disk file is `docs/privacy-policy.html` (with suffix), deployed at `/privacy-policy.html` (HTTP 200). The in-app URL doesn't resolve.
- **Fix:** add a `docs/privacy.html` mirror so both URLs resolve (can't change the in-app URL without a new build).

### H2 — 2.1 + 5.1.1 — Placeholder `support@example.com` in live privacy policy + support pages
- `docs/privacy-policy.html:50` and `docs/support.html:40` contain `support@example.com` and "(replace with your real address before publishing)" literal text.
- **Fix:** replace with `tony@custody-compass.com` (same contact as review details), delete the parenthetical.

## SIGNIFICANT

### S1 — 2.3 — Stale `tonym1979.github.io` references in internal audit doc
Old audit doc referenced a different host; risk if it leaked into reviewer notes. Audit doc now being overwritten.

### S2 — 3.1.1 — `Configuration.storekit` ships in Release
`project.yml:27` includes the local StoreKit test config as a Release resource. Remove it from `resources:`.

## MODERATE / SOFT
See `~/Documents/app-store-review-prompt.md` for the standard categories checked.
Key passes: privacy manifest matches code; export compliance correct; DEBUG paths gated; no Sign in with Apple required; no third-party SDKs.

## Prioritized fix list
1. **H1** — add `docs/privacy.html` so the in-app URL resolves.
2. **H2** — replace placeholder emails in both HTML docs.
3. **S1** — overwrite stale audit; done by this file.
4. **S2** — remove `Configuration.storekit` from `project.yml:27` resources.

Approval odds after 1+2: ~75% first-pass; after 1+2+S2: ~90%.
