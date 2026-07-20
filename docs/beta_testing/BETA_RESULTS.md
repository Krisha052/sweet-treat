# Sweet Treat — Beta Test Results

*Interim pull — the ~10-day test window from [`BETA_TEST_PLAN.md`](BETA_TEST_PLAN.md) Section 6 hasn't closed yet. This reflects the 11 responses in the sheet as of 2026-07-20; re-run this pull and update the numbers below once the window actually closes.*

---

## ⚠️ Data-quality flag — read before citing these numbers anywhere

The Firebase `sweet-treat-beta` group currently has only **3 real tester emails** in it (`rathodkrisha05@gmail.com`, `dr.shailendrasinh@gmail.com`, `alex.chen245623@gmail.com`); the other 29 entries are placeholder `example.com`/`.org`/`.net` addresses that can't receive invites or play the game. But the response sheet already has **11** distinct, substantive responses — more than 3 people could plausibly produce. That means real playtesting happened through a channel this doc isn't tracking (e.g. the APK shared directly, outside the Firebase invite flow).

That's not a problem for using the feedback itself — the answers read as genuine (specific mentions of the recipe system, UI, level-transition flow). It **is** a problem for reporting a tester *count*: right now there's no reliable link between "11 responses" and "N real testers," so don't report a specific tester-count-to-response ratio (e.g. "response rate") until the real distribution channel is reconciled with the tester list. If you want the resume-style "30+ beta testers" figure to be accurate, the tester list needs to reflect wherever these 11 responses actually came from.

---

## Summary

| | |
|---|---|
| Test window | Opened 2026-07-20; still open (interim pull) |
| Testers tracked in Firebase group | 32 total (3 real, 29 placeholder — see flag above) |
| Survey responses so far | 11 |
| **Overall rating average (Q1)** | **4.91 / 5** (10× 5, 1× 4) |
| Build tested | Beta build 1, v1.0 (version code 1) |

## Rating breakdown (Q1, Q3–Q5)

| Dimension | Average (1–5) | Notes |
|---|---|---|
| Overall enjoyment | 4.91 | 10 of 11 responses gave a perfect 5; one gave 4. Very little room to move — treat future drops as signal. |
| Difficulty (1 = too easy, 3 = just right, 5 = too hard) | 2.91 | Centered almost exactly on "just right," slightly toward "easy." Consistent with this build being Tier 1 (Levels 1–8, the onboarding tier) — see design doc Section 3. |
| Clarity without tutorial | 4.36 | Strong overall, but one respondent gave the low outlier (2/5) and separately named "how to move to the next level" as their most confusing moment (see themes below) — the one weak point in an otherwise strong score. |
| Art/visual style | 4.91 | Same near-ceiling pattern as overall enjoyment — 10 fives, one four. |

## Progression (Q2)

| Reached | Respondents | % |
|---|---|---|
| Didn't finish Level 1 | 0 | 0% |
| Finished Levels 1–3 | 1 | 9% |
| Finished Levels 4–6 | 1 | 9% |
| Finished all 8 levels | 9 | 82% |

82% full completion on an untutorialized build is a strong signal the core loop is learnable on its own.

## Recurring themes

- **Level-transition clarity is the one recurring soft spot.** The respondent who gave the lowest clarity score (2/5) also stopped at Levels 1–3 and named "How to move to the next level" as their most confusing moment. Everyone else scored clarity 4–5. This reads as a specific, fixable UX gap (the Next Level Frame / win-flow transition — design doc Section 3/5) rather than a broad comprehension problem, but it's worth a targeted look since it may be why this respondent didn't finish.
- **New recipes/ingredients are landing well.** Two independent free-text mentions call out "the new recipes and ingredients" and "figuring out the new recipes" as a highlight — positive but also flagged as the main point of friction for the respondent who otherwise had no complaints. This matches the design doc's Section 4 content-expansion plan; worth keeping recipe-introduction pacing in mind as Tier 2 content is built.
- **UI/visual polish is explicitly praised**, not just rated highly: "I loved the UI," "The game is very intuitive and enhances the memory."
- **Appetite for more content is confirmed.** One respondent explicitly wished for more levels; all 3 respondents who answered the "would you keep playing" question said yes. Directly supports investing in the Tier 2–5 content build (design doc Section 3/8).
- **Time pressure on later levels flagged once.** The respondent who reached Levels 4–6 (but no further) said "there wasn't enough time to finish the levels" and rated difficulty 4/5 — the hardest rating in the set. Single data point, but worth watching once more Tier 1 responses come in, since Levels 4–8 are exactly where the design doc's timer tightens (90s → 45s across Levels 1–8).
- **Zero crashes or breakage reported** across all 11 responses — good stability signal, though only one respondent specified their device (Android), so this doesn't yet validate the "60 FPS on low-end devices" claim in design doc Section 6 across a real device spread.

## Bugs reported

| # | Description | Level | Device | Severity | Status |
|---|---|---|---|---|---|
| — | No crashes, freezes, or visible breakage reported in any of the 11 responses. | — | — | — | — |

## Device coverage (Q12)

Only one respondent specified a device: **Android** (model/OS not given). The other 10 left it blank. This is too thin to validate the design doc's device-performance and responsive-layout claims (Section 5/6) — worth prompting testers more explicitly for device info in the next round, or following up with the 3 known real testers directly.

## Design changes made in response

*Proposed, not yet implemented — per the project's working conventions (design doc Section 9), content/UX judgment calls go back to you before anything gets built. These are candidates pulled directly from the themes above, not decisions.*

| Candidate change | Motivated by | Status |
|---|---|---|
| Make the win → Next Level Frame transition more discoverable (e.g. a brief prompt/animation cueing "tap to continue") | The one respondent who scored clarity lowest (2/5) and stopped at Levels 1–3 named this specifically as their confusion point | Proposed — needs your call |
| Review Levels 4–8 timer pacing against player pace, not just design-time math | One respondent hit both the hardest difficulty rating (4/5) and a "not enough time" comment on Levels 4–6 | Proposed — low confidence (single data point), revisit once more responses land |
| Prioritize Tier 2+ content build sooner rather than later | Explicit "wish there were more levels" plus 3/3 "would keep playing" on the sub-question | Proposed — supports the existing Section 8 backlog item, not a new idea |

## Raw data

- Response sheet: https://docs.google.com/spreadsheets/d/16z9EyeJ_LBkh3vBAmNb5q1pOa1EzVypqAYjAE3WkVfk/edit
- Form: https://docs.google.com/forms/d/e/1FAIpQLSe7Jnj5fThWS6n9MaRiPuCF5RGQedJjhQn65CC77hOo51Y6dQ/viewform
- Pulled 2026-07-20 via the sheet's CSV export (gid=47598820), 11 rows.
