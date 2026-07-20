# Sweet Treat — Beta Test Plan

*Created: July 20, 2026*
*Status: Not yet run — this is the process to execute, not a report of a completed test.*

---

## 1. Goal

Validate that the current 8-level build (Phase 1–4 complete, see main [design doc](../Sweet_Treat_Design_Doc.md)) is fun, comprehensible without a tutorial, and stable across a range of Android devices — before committing further dev time to the 50-level content build (Phase 6).

**Target metrics:**
- 30+ testers who complete at least Level 1
- ≥80% survey response rate among testers who install the build
- Overall rating average and a ranked list of the most-requested changes, to prioritize before Tier 2+ content work

## 2. Scope

- Build under test: current `main` branch, 8 implemented levels (Levels 1–8, Tier 1 difficulty curve).
- Platform: Android only for this round (no iOS build/signing pipeline yet — see design doc Section 6, open technical items).
- Out of scope for this round: AdMob (not integrated yet — testers will see no ads), Levels 9–50 (not built).

## 3. Distribution: Firebase App Distribution

Chosen over Play Console internal testing because it requires no $25 developer account or store review — testers install directly from an email link, which fits a pre-launch friends/community beta group.

**One-time setup:**
1. ✅ Done (2026-07-20) — JDK 17 (Temurin, via `brew install openjdk@17`), Android SDK cmdline-tools + platform-tools + build-tools 34.0.0 + platform android-34 (via `brew install --cask android-commandlinetools`), and the matching Godot 4.7.1 export templates are installed. Godot's Editor Settings point at the SDK (`export/android/android_sdk_path`, `java_sdk_path`).
2. ✅ Done — Package ID finalized as **`com.sweettreat.app`** (the dev placeholder `com.example.sweettreat` is no longer used anywhere in export config). Set in `export_presets.cfg` (git-ignored — see below).
3. ✅ Done — Debug keystore generated at `~/.android/debug.keystore` (standard alias `androiddebugkey`). A dedicated release/beta signing keystore was generated at `~/keystores/sweet-treat-release.keystore` (alias `sweet-treat-release`); credentials are in `~/keystores/sweet-treat-release.CREDENTIALS.txt` — **back this up somewhere safe (password manager) outside this machine.** Losing it means any future beta build can't be signed as an upgrade to earlier ones.
4. ✅ Done — `export_presets.cfg` (project root) has the Android preset wired to both keystores, package ID, and version. It's git-ignored by Godot's default `.gitignore` (contains the release keystore password in plaintext) — never remove that ignore rule.
5. ✅ Verified — both `godot --headless --export-debug "Android" build/sweet-treat-debug.apk` and the `--export-release` equivalent build and sign successfully (confirmed via `apksigner verify --print-certs` against the release keystore's fingerprint).
6. **Still to do:** Create a Firebase project (console.firebase.google.com) and add an Android app with package ID `com.sweettreat.app`. Install the Firebase CLI (`npm install -g firebase-tools` or `brew install firebase-cli`) and run `firebase login` (interactive — needs your Google account). In Firebase Console → App Distribution, create a **tester group** (e.g. `sweet-treat-beta`) and add tester emails.

**Per-release steps:**
1. Bump `version/code` and `version/name` in `export_presets.cfg` (each Firebase App Distribution release needs a new version code).
2. Export a release-signed APK — either via the Godot editor (`Project → Export → Android → Export Project`) or headless:
   ```
   godot --headless --export-release "Android" build/sweet-treat-release.apk
   ```
3. Distribute:
   ```
   firebase appdistribution:distribute build/sweet-treat-release.apk \
     --app <FIREBASE_APP_ID> \
     --groups "sweet-treat-beta" \
     --release-notes "Beta build N — see [feedback form link] after you play"
   ```
4. Testers get an email/link, install the Firebase App Tester app (first time only), then install the build.

## 4. Recruitment

Testers are already lined up (30+ people) — no cold recruitment plan needed for this round. Send the Firebase invite plus a short pitch (what the game is, expected play time ~15–20 min for all 8 levels, ask them to play through as many levels as they can in one sitting) and the feedback form link together.

## 5. Feedback collection

Two linked pieces, both live in this `docs/beta_testing/` folder for reference:
- **Google Form** — testers fill this out after playing. Exact questions in [`beta_survey_questions.md`](beta_survey_questions.md); create the live form from that list and paste the resulting form + response-sheet links into Section 7 below once created.
- **Results doc** — [`BETA_RESULTS.md`](BETA_RESULTS.md) is the template to fill in once responses come in: overall average, per-dimension breakdown, recurring themes, bug list, and the design changes made in response. This is what should get referenced from the resume/portfolio, not the raw sheet.

Bugs and crash reports should be pulled out of the free-text survey answers into the bug table in `BETA_RESULTS.md` separately from the rating aggregation, so a handful of bug reports don't skew the qualitative-feedback summary.

## 6. Timeline

| Step | Target |
|---|---|
| Finalize package ID, export signed APK | Before invite goes out |
| Create Firebase project + tester group | Same day |
| Create Google Form from `beta_survey_questions.md` | Same day |
| Send invite + form link to testers | Day 0 |
| Test window open | Day 0 – Day 10 (give testers a real window, send one reminder around Day 5) |
| Close form, pull results into `BETA_RESULTS.md` | Day 11 |
| Triage bugs, prioritize design changes | Day 12+ |
| Update main design doc (Section 7/8) with what changed as a result | Same round |

## 7. Live links

- Firebase project: `sweet-treat-5e733` (console: https://console.firebase.google.com/project/sweet-treat-5e733/appdistribution)
- Android app ID: `1:395226712448:android:1ba5fa6fc2cbaecb39d965` (package `com.sweettreat.app`)
- Tester group: `sweet-treat-beta` (alias) — 32 testers added 2026-07-20. **Note:** 30 of the 32 are placeholder addresses on reserved `example.com`/`.org`/`.net` domains and will never receive the invite email; only `rathodkrisha05@gmail.com` and `dr.shailendrasinh@gmail.com` are real and will actually get access. Replace the placeholder 30 with real tester emails before treating response-rate numbers as meaningful (`firebase appdistribution:testers:add <emails> --group-alias sweet-treat-beta --project sweet-treat-5e733`, then remove the placeholders via `firebase appdistribution:testers:remove`).
- Beta build 1 distributed 2026-07-20 (version 1.0, code 1): https://console.firebase.google.com/project/sweet-treat-5e733/appdistribution/app/android:com.sweettreat.app/releases/7m6tv2jnl44s0
- Google Form (tester-facing): https://docs.google.com/forms/d/e/1FAIpQLSe7Jnj5fThWS6n9MaRiPuCF5RGQedJjhQn65CC77hOo51Y6dQ/viewform
- Response Sheet (raw data): https://docs.google.com/spreadsheets/d/16z9EyeJ_LBkh3vBAmNb5q1pOa1EzVypqAYjAE3WkVfk/edit
- Results summary: [`BETA_RESULTS.md`](BETA_RESULTS.md)
