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

**One-time setup (do before first release):**
1. Install Godot's Android export templates (Editor → Manage Export Templates) and configure `Android` in Export Presets, including a debug or dedicated beta-signing keystore. Package ID should be finalized here (currently unset in `project.godot` — decide the real bundle ID, e.g. `com.sweettreat.game`, before the first external build; `com.example.sweettreat` used in dev is a placeholder and should not go out to testers).
2. Create a Firebase project (console.firebase.google.com) and add an Android app with that package ID.
3. Install the Firebase CLI (`npm install -g firebase-tools` or `brew install firebase-cli`) and run `firebase login`.
4. In Firebase Console → App Distribution, create a **tester group** (e.g. `sweet-treat-beta`) and add tester emails.

**Per-release steps:**
1. In Godot: `Project → Export → Android → Export Project` to produce a signed APK.
2. Distribute:
   ```
   firebase appdistribution:distribute build/sweet-treat.apk \
     --app <FIREBASE_APP_ID> \
     --groups "sweet-treat-beta" \
     --release-notes "Beta build N — see [feedback form link] after you play"
   ```
3. Testers get an email/link, install the Firebase App Tester app (first time only), then install the build.

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

*(Fill in once created — keep this doc as the index.)*

- Firebase App Distribution project:
- Google Form (tester-facing):
- Response Sheet (raw data):
- Results summary: [`BETA_RESULTS.md`](BETA_RESULTS.md)
