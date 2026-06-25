# Sweet Treat — Game Design Document

*Last updated: June 24, 2026*

---

## 1. Overview

**Working Title:** Sweet Treat

**Genre:** Time-management / cooking-puzzle hybrid

**Pitch:** A cozy 3D cafe simulation where players race against the clock to fulfill dish orders, shown as image-based dish cards (tapping a card opens a Recipe Frame revealing its exact ingredient list). Players tap matching ingredients directly off a chopping-board grid to complete each order — ingredients are consumed in place, refilled by new ones rolling down, with each completed order replaced by a new dish drawn from a fixed recipe database based on what's currently on the board. There are no visible customers; the focus stays tight on ingredient logistics and recipe assembly. Progression is linear and strictly forward-only, with no replay of completed levels — players always resume exactly where they left off. Levels escalate via more simultaneous orders, tighter timeframes, and more complex recipes.

**Visual Style:** 3D, cozy architecture, light/pastel color palette, minimal animations — suggests a stylized, simplified aesthetic rather than fully animated characters. Palette confirmed for the title, gameplay, and game-over screens (see Section 4); the broader game-wide scheme is being finalized in a muted, earthy direction anchored to the existing (fixed) asset pack colors, particularly the bakery exterior.

**Platforms:** Mobile (iOS + Android) for initial launch; Desktop (Windows/Mac) planned as a later phase. Built in Godot.

**Business Model:** Free-to-play, supported by ads (banner, interstitial, and rewarded).

**Team:** Solo developer.

---

## 2. Core Gameplay Loop

**Camera:** Fixed/static camera per scene — no player movement controls. This simplifies controls and reduces rendering overhead, which benefits both development time and mobile performance.

**Interaction:** Ingredients are arranged in a grid (multiple columns) on a chopping board asset. Player taps ingredients directly on the board to select them toward completing a dish. There is no separate inventory step — selected ingredients are consumed directly from the board when a dish order is completed. Tapping an ingredient not needed for any current order has no penalty — it is simply ignored, keeping the experience low-stress and forgiving of misclicks. Selected ingredients are visually highlighted in olive green (`#8a8f13`, the same accent used for the Level Complete state — see Section 4) so players can track what they've already picked toward an order. *(Implementation suggestion: tint via the sprite's `modulate` property in Godot — no new art needed, since it recolors the existing ingredient sprite directly; reset to `Color.WHITE` on deselect/consumption. A shared outline shader is a more polished option to layer on later if the tint alone doesn't read clearly enough, without needing per-ingredient highlight art either way.)*

**Order Display:** Dish cards (showing the finished dish's image, not a text ingredient list) are displayed below the chopping board — multiple shown simultaneously. The specific ingredient list required per dish is defined in the Recipe Frame (see UI flow). Players juggle and prioritize across dish cards as needed.

**Recipe Frame:** Tapping a dish card opens the Recipe Frame, a full-screen view showing that dish's exact ingredient list (counts + ingredient images) on a recipe-card asset, with the completed dish pictured at the top. Level indicator and timer remain visible and the timer continues counting down while the Recipe Frame is open — it is not a pause state. Transition in/out uses a fade. Exit is via a dedicated "X" close button in the top-right corner of the recipe card (chosen over tap-outside or tap-the-dish-image for simplest implementation and clearest discoverability, given no tutorial is planned for MVP).

**Board Refill:** When a dish order is completed, its consumed ingredients clear from the board, and new ingredients roll down to fill the vacated slots in random order. A new dish card then appears in place of the completed one — selected by matching the ingredients currently present on the board against the fixed recipe database (the 10–15 dishes defined in Section 6). The system never generates a new recipe on the fly; it only picks an existing database recipe that the current board can produce, guaranteeing every visible order is completable in principle. *(Open item: ingredient rarity/weighting as a future difficulty lever — see Section 3 note.)*

**Fail Condition:** If the level timer runs out before all queued orders are completed, the level is failed and must be retried.

**Loop summary:**
1. One or more receipts appear on-screen, each listing required ingredients for a dish.
2. Player taps ingredients in the scene to fulfill orders, working across multiple receipts as needed.
3. Completed orders are cleared; new orders may appear to take their place within the level's timeframe.
4. The level is won if all orders are completed before time runs out — otherwise, it is failed and can be retried.

---

## 3. Level Structure & Progression

**Progression:** Linear and strictly forward-only — players complete levels in sequence (Level 1 → 2 → 3...) to unlock the next. Once a level is completed, there is no way to revisit or replay it; Start Game always resumes at the player's current (last unfinished) level.

**Difficulty Scaling:** Increases gradually across three combined levers:
- Number of simultaneous orders queued
- Time limit per level
- Recipe complexity (number of ingredients per dish) — proposed approach: scale via a batch multiplier (e.g. x1 → x2 → x3 ingredient counts) while keeping the recipe's ingredient ratio constant, rather than authoring entirely new ratios per difficulty tier

*(Possible future lever, not yet decided: weighting ingredient appearance frequency — common vs. rare ingredients — to add scarcity-based difficulty. To be discussed when designing levels; also interacts with the board-refill rule that new dish cards must be producible from currently available ingredients.)*

**Win/Lose Condition:** Pass/fail only — no star ratings or scoring. A level is won by completing all orders before time runs out; running out of time fails the level.

**Level Complete:** Confirmed flow — on win, the Game Setup Frame itself (chopping board, dish cards, level/timer UI all stay in place) changes its background color to `#8a8f13` for 3 seconds, then an interstitial ad plays, then it transitions to the Next Level Frame. Tapping "Next Level" advances to the next level. The background color shift alone is the intended win signal — confirmed no additional text label (e.g. "Level Complete") is needed; the subtler feedback is a deliberate choice, asymmetric to the bold flashing "Game Over" text on the fail side.

**Retry:** Confirmed flow — on fail, the Game Over Frame shows for 5 seconds (auto-timed, no input needed), then an interstitial ad plays, then it fades into the Restart Game Frame. Tapping "Restart Game" retries the same failed level for free — no cooldown, no rewarded-ad gate.

---

## 4. UI & Art Direction

**Visual Style:** 3D, cozy aesthetic, light/pastel color palette, minimal animations. Final color scheme still to be determined.

**Asset Coverage:** Existing asset packs cover the majority of UI, ingredient/prop models, and environment needs across the project, significantly reducing original art production to gap-filling and customization.

**Remaining Art Needs (to confirm during production):**
- Final color scheme/palette — direction confirmed: muted & earthy, anchored to the existing (fixed) asset pack colors, particularly the bakery exterior. Assets will stay largely as-is; retinting is possible later for variety but isn't a priority. Exact remaining hex values (buttons, ingredient/dish card backgrounds, borders, etc.) still TBD
- Custom branding (logo, app icon, splash screen)
- Receipt/order UI styling
- ~~Level-select UI~~ — no longer needed; see Title Screen note below (Start Game resumes directly into the player's last unfinished level, no level-select step)

**Title Screen (confirmed, in progress):**
- Background color: `#ddab79`
- Logo + "Start Game" button (Quaver Regular font) over a reused bakery building asset
- Start Game button uses a blinking/pulsing animation to read as interactive (also a low-cost touch of motion within the "minimal animations" direction from Section 1/4)

**Game Setup Frame (confirmed, in progress):**
- Background color: `#544541` (inverse of Title Screen, signaling the shift into gameplay)
- Level indicator, top-left: text color `#ddab79`, static (no movement/animation)
- Timer, top-right: rounded-rectangle pill background `#ddab79`, text color `#544541`
- Chopping board asset holds the ingredient grid (multiple columns); exact grid size/organization per difficulty level TBD during level design
- Dish cards (target dish images) displayed below the board, multiple at once
- Ingredient roll-down refill animation plays when a dish order is completed (see Section 2, Board Refill)

**Recipe Frame (confirmed, in progress):**
- Background color: `#544541` (matches Game Setup Frame)
- Opened by tapping a dish card; level indicator and timer stay visible/unchanged in their corners, timer keeps running
- Recipe card asset (existing project asset) centered on screen, with the completed dish image at top-center
- Below the dish image: two-column list — ingredient count (e.g. x1, x2) on the left, corresponding ingredient image on the right, one row per required ingredient
- Dedicated "X" close button, top-right corner of the recipe card, returns to the Game Setup Frame
- Transition: fade in/out

**Game Over Frame (confirmed, in progress):**
- Background color: `#ef5241`
- "Game Over" text flashes between black and white
- No logo; bakery building asset retained (same layout as Title Screen, minus logo)
- Displays for 5 seconds automatically, then an interstitial ad plays, then it fades into the Restart Game Frame — no player input required to advance

**Restart Game Frame (confirmed, in progress):**
- Visually identical to the Title Screen (`#ddab79` background, bakery building asset) but with logo replaced by "Restart Game" button text
- Tapping "Restart Game" retries the same failed level for free

**Game Setup Frame — Level Complete state (confirmed, in progress):**
- Same frame as gameplay (chopping board, dish cards, level indicator, timer all remain in place) — only the background color changes, from `#544541` to `#8a8f13`
- Holds for 3 seconds (auto-timed), then an interstitial ad plays, then transitions to the Next Level Frame

**Next Level Frame (confirmed, in progress):**
- Visually identical to the Title Screen / Restart Game Frame (`#ddab79` background, bakery building asset) but with text reading "Next Level"
- Tapping "Next Level" advances to the next level

**Screen Flow (confirmed):**
```
Title Screen (#ddab79)
  -> tap "Start Game" -> Game Setup Frame (resumes last unfinished level)

Game Setup Frame (#544541) <-> Recipe Frame (#544541, modal, fade transition)
  tap dish card -> Recipe Frame; tap "X" -> back to Game Setup Frame

Game Setup Frame -> [all orders completed before time runs out]
  -> bg shifts to #8a8f13 for 3s -> interstitial ad -> Next Level Frame (#ddab79)
  -> tap "Next Level" -> Game Setup Frame (next level)

Game Setup Frame -> [timer runs out before orders completed]
  -> Game Over Frame (#ef5241, flashing text) for 5s -> interstitial ad -> Restart Game Frame (#ddab79)
  -> tap "Restart Game" -> Game Setup Frame (same level, retried)
```

**Accent Colors:**
- Olive green (`#8a8f13`) — confirmed use #1: Game Setup Frame background during the Level Complete state (see Section 3). Confirmed use #2: highlight color for ingredients the player has selected on the chopping board (see Section 2, Interaction), tinted via `modulate` rather than separate highlight art. Originally proposed as a general "success" accent pulled from the green-tea cup ingredient asset's lid.

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

**Save Data:** Local save file tracking level progress (linear unlock state) — no backend/server required for MVP. Tapping "Start Game" on the title screen takes the player directly into the level they last left off at (no intervening level-select step).

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
- Procedural recipe generation — MVP uses a fixed recipe database only (see Section 2, Board Refill); generating novel recipes on the fly is a possible direction worth exploring post-MVP

---

## 7. Risks & Open Questions

| Risk / Open Item | Notes |
|---|---|
| Color scheme — direction set, hex values pending | Confirmed direction: muted & earthy, anchored to existing fixed asset colors (bakery exterior etc.); still need exact values for remaining UI (buttons, card backgrounds, borders) before finalizing UI assets |
| No tutorial in MVP | First-time players may need to learn the tap-to-collect + receipt mechanic by trial; consider a simple guided first level even without a formal tutorial system |
| iOS build/signing requires a Mac | Needed for App Store submission — confirm access before launch |
| App Store / Play Store review timelines | First submissions can take longer than expected; budget extra time before the target launch date |
| Solo dev bandwidth | Art is largely covered by existing assets, but level/recipe balancing, ad integration, and cross-device QA all fall on one person — build in a realistic timeline buffer |
| Recipe/ingredient balancing | 10–15 recipes across 5–10 levels with scaling difficulty will need playtesting to ensure fairness as orders queue up |
| Retry flow confirmed | Game Over (5s, auto) → interstitial ad → Restart Game (tap to retry, free, no cooldown) is fully locked in |
| Quaver Regular legibility on phone screens | Pixel font used for "Start Game" button (and possibly other UI) — verify readability at actual on-device button size before finalizing |
| Recipe-match selection logic undecided | When multiple database recipes are producible from the current board ingredients, decide whether the next dish card is chosen fully at random among valid matches, or weighted (e.g. to avoid recently-seen dishes repeating) — to be addressed during backend/level-design work |

---

## Document History

| Date | Change |
|---|---|
| June 23, 2026 | Initial design doc created |
| June 24, 2026 | Walked through title, game setup, recipe, game over, and restart frames; updated gameplay loop, UI details, and resolved several open items along the way |
