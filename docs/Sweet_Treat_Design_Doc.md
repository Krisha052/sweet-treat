# Sweet Treat — Game Design Document

*Last updated: June 23, 2026*

---

## 1. Overview

**Working Title:** Sweet Treat

**Genre:** Time-management / cooking-puzzle hybrid

**Pitch:** A cozy 3D cafe simulation where players race against the clock to collect ingredients and assemble dishes matching customer orders. Orders arrive as printed receipts rather than visible customers, keeping the focus tight on ingredient logistics and recipe assembly. Players progress through escalating levels with tighter timeframes and more complex recipes.

**Visual Style:** 3D, cozy architecture, light/pastel color palette (color scheme TBD), minimal animations — suggests a stylized, simplified aesthetic rather than fully animated characters.

**Platforms:** Mobile (iOS + Android) for initial launch; Desktop (Windows/Mac) planned as a later phase. Built in Godot.

**Business Model:** Free-to-play, supported by ads (banner, interstitial, and rewarded).

**Team:** Solo developer.

---

## 2. Core Gameplay Loop

**Camera:** Fixed/static camera per scene — no player movement controls. This simplifies controls and reduces rendering overhead, which benefits both development time and mobile performance.

**Interaction:** Player taps/clicks ingredients directly in the 3D scene to collect them. Tapping the wrong ingredient has no penalty — it is simply ignored, keeping the experience low-stress and forgiving of misclicks.

**Order Display:** Multiple order receipts are queued and visible on-screen simultaneously, each listing its required ingredients. Players must juggle and prioritize across orders as they arrive.

**Inventory:** No carrying limit — ingredients can be collected freely without managing inventory space.

**Fail Condition:** If the level timer runs out before all queued orders are completed, the level is failed and must be retried.

**Loop summary:**
1. One or more receipts appear on-screen, each listing required ingredients for a dish.
2. Player taps ingredients in the scene to fulfill orders, working across multiple receipts as needed.
3. Completed orders are cleared; new orders may appear to take their place within the level's timeframe.
4. The level is won if all orders are completed before time runs out — otherwise, it is failed and can be retried.

---

## 3. Level Structure & Progression

**Progression:** Linear — players complete levels in sequence (Level 1 → 2 → 3...) to unlock the next.

**Difficulty Scaling:** Increases gradually across three combined levers:
- Number of simultaneous orders queued
- Time limit per level
- Recipe complexity (number of ingredients per dish)

**Win/Lose Condition:** Pass/fail only — no star ratings or scoring. A level is won by completing all orders before time runs out; running out of time fails the level.

**Retry:** Failed levels can be retried immediately. *(Open item: consider whether a retry should be free, gated by a short cooldown, or offer a rewarded-ad option to retry instantly — see Section 7.)*

---

## 4. UI & Art Direction

**Visual Style:** 3D, cozy aesthetic, light/pastel color palette, minimal animations. Final color scheme still to be determined.

**Asset Coverage:** Existing asset packs cover the majority of UI, ingredient/prop models, and environment needs across the project, significantly reducing original art production to gap-filling and customization.

**Remaining Art Needs (to confirm during production):**
- Final color scheme/palette
- Custom branding (logo, app icon, splash screen)
- Receipt/order UI styling
- Level-select UI (simple list, since progression is linear)

**Monetization & Ad Placement:**
- **Banner ads** — persistent, low-intrusion placement (likely during gameplay or menus)
- **Interstitial ads** — shown between levels (after a level ends, win or lose)
- **Rewarded ads** — optional, player-initiated (e.g. "watch an ad to retry instantly" or "watch an ad for a bonus")

---

## 5. Platform & Technical Approach

**Engine:** Godot 4.x

**Launch Platforms:** Mobile first (iOS + Android); Windows/Mac desktop export planned as a later phase.

**Ad Integration:** `godot-sdk-integrations/godot-admob` plugin — unified GDScript interface for AdMob on Android/iOS, supporting banner, interstitial, and rewarded ad formats, with built-in GDPR/UMP consent flow handling for App Store and Play Store compliance.

**Camera/Rendering:** Fixed-camera 3D scenes — lighter rendering overhead than free-roam camera/movement, important for mobile device performance.

**Save Data:** Local save file tracking level progress (linear unlock state) — no backend/server required for MVP.

**Open technical items to confirm during development:**
- Target frame rate and minimum supported device specs
- Apple Developer account + Google Play Console account setup
- iOS build/signing pipeline (requires access to a Mac)

---

## 6. Scope & MVP

**Levels:** 5–10 levels for initial launch.

**Recipes:** 10–15 dishes, reused and recombined across levels with increasing complexity as defined in Section 3.

**Included in MVP:**
- Core gameplay loop (tap-to-collect, persistent receipt display, multi-order queue, level timer)
- Linear level progression with pass/fail
- Banner, interstitial, and rewarded ad integration
- Mobile launch (iOS + Android)

**Explicitly excluded from MVP (candidates for post-launch updates):**
- Settings menu (sound/music toggles, etc.)
- Tutorial/onboarding flow
- Desktop builds
- Star ratings or scoring systems
- Stats tracking / achievements

---

## 7. Risks & Open Questions

| Risk / Open Item | Notes |
|---|---|
| Color scheme not finalized | Should be locked before building final UI assets to avoid rework |
| No tutorial in MVP | First-time players may need to learn the tap-to-collect + receipt mechanic by trial; consider a simple guided first level even without a formal tutorial system |
| iOS build/signing requires a Mac | Needed for App Store submission — confirm access before launch |
| App Store / Play Store review timelines | First submissions can take longer than expected; budget extra time before the target launch date |
| Solo dev bandwidth | Art is largely covered by existing assets, but level/recipe balancing, ad integration, and cross-device QA all fall on one person — build in a realistic timeline buffer |
| Recipe/ingredient balancing | 10–15 recipes across 5–10 levels with scaling difficulty will need playtesting to ensure fairness as orders queue up |
| Retry cost/flow undecided | Decide whether failed-level retries are free, cooldown-gated, or tied to a rewarded ad |

---

## Document History

| Date | Change |
|---|---|
| June 23, 2026 | Initial design doc created |
