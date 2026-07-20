# Sweet Treat — Game Design Document

*Last updated: June 28, 2026*

---

## 1. Overview

**Working Title:** Sweet Treat

**Genre:** Time-management / cooking-puzzle hybrid

**Pitch:** A cozy 2D cafe simulation where players race against the clock to fulfill dish orders, shown as image-based dish cards (tapping a card opens a Recipe Frame revealing its exact ingredient list). Players tap matching ingredients directly on a chopping-board grid to select them toward any active order; a recipe completes the moment its full ingredient list is present within the current selection, regardless of what else is also selected. There are no visible customers; the focus stays tight on ingredient logistics and recipe assembly. Progression is linear and strictly forward-only — players always resume exactly where they left off. Levels escalate via more simultaneous orders, tighter timeframes, and 2x batch multipliers on existing recipes.

**Visual Style:** 2D, cozy aesthetic, light/pastel color palette, minimal animations — sprite-based (Sprite2D/TextureRect), no 3D models anywhere in the project. *(Note: the project was originally scoped as 3D and was converted to 2D early in Phase 4. This doc reflects the current state.)* Palette confirmed for the title, gameplay, and game-over screens (see Section 4); the broader game-wide scheme is muted/earthy, anchored to the existing (fixed) asset pack colors, particularly the bakery exterior (`cafe.png`).

**Platforms:** Mobile (iOS + Android) for initial launch; Desktop (Windows/Mac) planned as a later phase. Built in Godot 4.7.

**Business Model:** Free-to-play, supported by ads (banner, interstitial, and rewarded). *(Not yet implemented — see Section 5, Phase 5 status.)*

**Target release scope:** 50 levels. *(Currently 8 levels implemented — see Section 6.)*

**Team:** Solo developer.

---

## 2. Core Gameplay Loop

**Camera:** Static 2D scenes — no camera movement, no player movement controls.

**Board:** A grid on the chopping-board asset, filled independently at random from the current level's eligible ingredient set (the union of ingredients across that level's `recipe_pool`). Duplicate ingredients across slots are allowed and expected.

Board dimensions vary by level tier:
- **Tiers 1–4 (Levels 1–42):** 6×6 grid (36 slots)
- **Tier 5 / Endgame (Levels 43–50):** 8×6 grid (48 slots, wider not taller)

`BOARD_ROWS`/`BOARD_COLS` are per-level fields on `LevelConfig` (defaulting to 6/6), not hardcoded constants. The entire layout chain (board origin, ChoppingBoard positioning, hit-targets, card-row) derives from these values at runtime so changing board size per level requires no additional layout work.

**Selection model:** Tapping an ingredient toggles its selected state (olive-green tint `#8a8f13` via `modulate`, applied to the `Sprite2D` child only — the `CollisionShape2D` is a sibling and its scale is unaffected). Selected ingredients go into a shared `_selected_pool` (tracked by object identity). Tapping a selected ingredient again deselects it and removes it from the pool. No ingredient is ever committed to a specific order at tap time.

**Order completion:** After every select action, the system checks all active orders (oldest-first) using a subset/containment check: does `_selected_pool` contain at least the required count of every ingredient type that order needs? Extra selected ingredients beyond what an order needs do not block it. The first order whose full requirement is found in the pool completes immediately — consuming only the specific slots it needed. Remaining selected ingredients stay selected, still available toward other orders. Deselecting never triggers a completion check (removing items can only shrink the pool, never newly satisfy an order).

Tie-break (multiple orders simultaneously satisfied by a single tap): complete oldest first, then re-check the now-smaller pool for further completions before returning — cascading until stable.

**Joint-demand satisfiability (Bug A fix):** When assigning a new recipe to an order slot (at initial spawn or after a refill), `_pick_next_recipe()` checks satisfiability against `available = free_board - committed_of_others` — not the raw board in isolation. `committed_of_others` is the sum of all other active orders' full remaining needs. This prevents double-booking: a recipe is only assigned if the board can cover its full requirement on top of what other active orders already need.

**Board Refill & Satisfiability Guarantee:** When an order completes, its consumed slots clear and refill. After every refill — both initial setup and post-completion — the system re-rolls the board (up to 20 attempts) until at least one active order is completable. The completability check uses `free_board + _selected_pool` combined (not just free board), so selected ingredients already in the pool are counted toward satisfiability and don't trigger unnecessary force-placement.

**Force-placement fallback (Bug B fix):** If 20 re-roll attempts all fail, instead of silently accepting an unsatisfiable board, the system force-places the minimum missing ingredients for the single active order with the smallest total deficit. Spill slots (when the deficit needs more slots than were just consumed) exclude both the just-consumed set and any slot currently selected by the player toward another order. If no eligible spill slot exists, `push_warning` fires and the existing worst-case behavior applies (no partial placement).

**Ingredient hit-targets:** `CollisionShape2D` native radius = 81px. Root node scale = 0.80 (affects collision). `Sprite2D` local scale = 0.875 (net visual 0.70, visual-only). Effective hit diameter = 81 × 0.80 × 2 = **130px** at 6×6. At 8×6 (Tier 5), effective hit diameter = **120px** (7.9mm physical, above 7mm minimum comfortable tap threshold). Cell size = 125px at 6×6.

**Dish cards:** Displayed below the chopping board in an `HFlowContainer` supporting two rows (544px total height allocation). Cards are 270×270px; 4 cards fill one row exactly (4×270=1080px). A 5th card wraps to row 2. The dish-card row's position is computed at runtime from the board's actual pixel bounds via `hud.gd`'s `position_card_row()`, with a 150px gap between board bottom and card row top.

**Recipe Frame:** Tapping a dish card opens the Recipe Frame — a full-screen modal. Timer continues running. Dish-card row is explicitly hidden while open, restored on close. Exit via a dedicated "X" close button (top-right of card, 60×69px, anchored 10px inside the card's inner visible border). Ingredient count text (x1, x2) uses `IngredientList.anchor_left = 0.13`. Transition: fade in/out.

**Game Complete Screen:** Shown when a player wins the final available level (currently Level 8, expanding to 50 post-content-build). Fully static — no button, no interaction. Layout: `#ddab79` background, `cafe.png` backdrop, Sweet Treat logo, static label "You completed all levels!" in `quaver.ttf`. Triggered from `_begin_win_sequence()` when no next level file exists, and from `main_menu.gd` when `unlocked_level_index > MAX_LEVEL_INDEX`.

**Fail Condition:** Timer runs out before all orders complete → level failed, must retry.

**Loop summary:**
1. One or more dish cards appear; tapping a card reveals its required ingredients in the Recipe Frame.
2. Player taps ingredients to select them into the shared pool. Any active order whose full requirement is present in the pool immediately completes, consuming only the slots it needed.
3. Completed order's slots clear, board refills (satisfiability guarantee re-applied), new dish card appears.
4. Level won if all orders complete before time runs out; otherwise failed and retried.

---

## 3. Level Structure & Progression

**Progression:** Linear, forward-only. `Start Game` resumes at the player's last unfinished level. No level-select in the shipped flow (`level_select.tscn` is dev/testing-only).

**Multiplier ceiling:** 2x maximum. 3x multipliers have been dropped — at 3x, individual orders statistically exceed the board's expected supply for their ingredient type in nearly every tested scenario, making force-placement fire before the player can even attempt to complete the order.

**Difficulty levers (in order of introduction across 50 levels):**
1. Number of simultaneous orders queued
2. Time limit per level (tighter as levels increase)
3. Recipe pool size per level (more variety = more ingredient types on board = lower per-type supply)
4. 2x batch multiplier on select recipes (introduced at Tier 4, Levels 35–42)

**Board capacity constraints (validated — do not propose level configurations that violate these):**

| Condition | Status |
|---|---|
| ≤5 orders, 1x, any K, 6×6 | ✅ Safe |
| 6 orders, 1x, K≤8, 6×6 | ✅ Safe |
| 6 orders, 1x, K≥10, 6×6 | ❌ Flour/egg/bean_med routinely over-committed |
| 2x multiplier, K≤6, 6×6 | ✅ Safe |
| 2x multiplier, K≥8, 6×6 | ❌ Individual 2x orders exceed expected supply |
| 2x multiplier, K≤10, 6×8 (48 slots) | ✅ Safe |
| 2x multiplier, K=12, 6×8 | ⚠️ Borderline — 1 simultaneous 2x order safe; 2 simultaneous 2x flour orders risks force-placement |
| 3x multiplier | ❌ Dropped |

**50-Level Tier Structure:**

**Tier 1 — Onboarding (Levels 1–10):** Existing 8 levels + 2 new. 6×6 board, 1x only.

| Level | Simul. orders | Pool size | K | Time |
|---|---|---|---|---|
| 1 | 1 | 2 | 3 | 90s |
| 2 | 2 | 3 | 4 | 80s |
| 3 | 2 | 3 | 4 | 75s |
| 4 | 3 | 3 | 5 | 70s |
| 5 | 3 | 3 | 5 | 65s |
| 6 | 4 | 4 | 6 | 60s |
| 7 | 4 | 4 | 6 | 55s |
| 8 | 5 | 5 | 7 | 45s |
| 9 | 5 | 5 | 7 | 42s |
| 10 | 5 | 5 | 7 | 40s |

**Tier 2 — Ramping (Levels 11–22):** New recipes introduced. K stays ≤8. 6×6, 1x only.

| Level range | Simul. orders | Pool size | K | Time |
|---|---|---|---|---|
| 11–14 | 5 | 6 | 7–8 | 38–35s |
| 15–18 | 6 | 6 | 7–8 | 35–33s |
| 19–22 | 6 | 7 | 8 | 33–30s |

Note: achieving K≤8 with 6+ recipes requires thematic pools (bakery-only or café-drinks-only). Level design at this tier must validate K per pool explicitly.

**Tier 3 — Sustained Pressure (Levels 23–34):** Full 6 simultaneous orders, 1x only. K must stay ≤8 — binding constraint. 6×6.

| Level range | Simul. orders | Pool size | K | Time |
|---|---|---|---|---|
| 23–26 | 6 | 7 | 7–8 | 30–28s |
| 27–30 | 6 | 8 | 8 | 28–26s |
| 31–34 | 6 | 8 | 8 | 26–24s |

**Tier 4 — 2x Multiplier Introduction (Levels 35–42):** 2x requires K≤6 on 6×6 board. Thematic pools with high ingredient overlap. Time eases slightly vs. Tier 3 to compensate for new mechanic. 6×6.

| Level range | Simul. orders | Pool size | K | Time | 2x orders active |
|---|---|---|---|---|---|
| 35–38 | 5 | 6 | 5–6 | 35–32s | 1 of 5 |
| 39–42 | 5 | 6 | 5–6 | 32–28s | 2 of 5 |

Tier 4 pools will primarily use the original bakery recipes (bread, bun, croissant, cherry_cake, coconut_cake, etc.) rather than the new diverse recipes, since bakery recipes naturally share flour/egg/milk and achieve K≤6 pools. New diverse recipes (matcha, chocolate, etc.) feature in Tiers 2–3 (1x variety) rather than the 2x tier.

**Tier 5 — Endgame (Levels 43–50):** 6×8 board (48 slots). 2x multiplier continues. At K=12, only one 2x order at a time to stay safe; 2x is restricted to non-flour/egg recipes only (matcha_cake, coconut_cream, cherry_cream, etc.) to avoid borderline force-placement scenarios.

| Level range | Simul. orders | Pool size | K | Time | 2x orders active |
|---|---|---|---|---|---|
| 43–46 | 6 | 8–10 | 8–10 | 35–28s | 1–2 of 6 |
| 47–50 | 6 | 10 | 10–12 | 28–22s | 1–2 of 6 (non-flour/egg only) |

Safest L47–50 configuration: pool of 10 recipes, K=10 (not 12), 1–2 orders at 2x targeting non-flour/egg speciality recipes. Gives 48/10=4.8 slots expected vs. 2×max=4 — clear margin.

**Win/Lose Condition:** Pass/fail only — no star ratings. Won = all orders complete before timer. Lost = timer runs out.

**Level Complete flow:** Background shifts `#544541` → `#8a8f13` for 3s → interstitial ad → Next Level Frame → tap "Next Level" → next level (or Game Complete screen if on the last level).

**Retry flow:** Game Over Frame (3s, auto-timed) → interstitial ad → Restart Game Frame → tap "Restart Game" → same level, free retry, no cooldown.

---

## 4. Content

### Current Content (implemented)

**Ingredients (12):** cherry, coconut, bean_dark_roast, egg, flour, foam, bean_light_roast, milk, bean_medium_roast, bean_raw, red_tea, strawberry

**Recipes (10):** bread, bun, cappuccino, cherry_cake, coconut_cake, coffee_cake, croissant, espresso, latte, strawberry_cake

### Planned New Content (pending art sourcing — not yet implemented)

**New Ingredients (6, total will be 18):**

| Ingredient | Role | Bottleneck avoided |
|---|---|---|
| Matcha | Tea/cake base | Avoids flour, egg, bean_medium entirely |
| Chocolate | Drink/cake base | Avoids flour, egg, bean_medium entirely |
| Cream | Dairy alternative to milk | Spreads milk load; no flour/egg |
| Butter | Baking base alternative | Enables pastry recipes without egg |
| Sugar | Confectionery base | Avoids all three bottlenecks |
| Caramel | Coffee/dessert flavoring | Redirects coffee demand away from bean_medium |

**New Recipes (14, total will be 24):**

| Recipe | Ingredients | Flour | Egg | bean_med |
|---|---|---|---|---|
| Matcha Latte | matcha×2, cream×1, foam×1 | — | — | — |
| Matcha Cake | matcha×2, cream×1, sugar×1 | — | — | — |
| Hot Chocolate | chocolate×2, milk×1, cream×1 | — | — | — |
| Chocolate Cake | chocolate×2, cream×1, sugar×1 | — | — | — |
| Caramel Latte | bean_dark_roast×2, caramel×1, cream×1 | — | — | — |
| Caramel Cake | caramel×2, cream×1, sugar×1 | — | — | — |
| Strawberry Cream | strawberry×2, cream×1, sugar×1 | — | — | — |
| Cherry Cream | cherry×2, cream×1, caramel×1 | — | — | — |
| Coconut Cream | coconut×2, cream×1, sugar×1 | — | — | — |
| Honey Tea | red_tea×2, caramel×1, foam×1 | — | — | — |
| Cream Puff | butter×2, cream×1, sugar×1 | — | — | — |
| Butter Biscuit | butter×2, flour×1, sugar×1 | ✓ | — | — |
| Chocolate Croissant | chocolate×1, butter×1, flour×1 | ✓ | — | — |
| Sugar Cake | sugar×2, egg×1, cream×1 | — | ✓ | — |

**Post-addition bottleneck profile (24 total recipes):**

| Ingredient | Old (10 recipes) | New (24 recipes) | Change |
|---|---|---|---|
| flour | 7/10 = 70% | 9/24 = 37.5% | ↓ 32.5 pts |
| egg | 7/10 = 70% | 8/24 = 33.3% | ↓ 36.7 pts |
| bean_medium_roast | 3/10 = 30% | 3/24 = 12.5% | ↓ 17.5 pts |
| cream | 0/10 | 11/24 = 45.8% | new workhorse |

Cream becomes the new most-common ingredient, but it's intentionally distributed across many recipe types so no single level pool concentrates on it the way flour/egg were. The capacity audit constraint logic applies to cream at level-design time — check it against `bean_medium_roast`'s 3-recipe overlap as a reference.

**Status of new content:** Art assets not yet sourced. All 40+ new levels need new ingredient and dish sprites from scratch — zero unused stock exists in the project. Art sourcing/approval is a prerequisite before any new `.tres` data files or level configs are built.

---

## 5. UI & Art Direction

**Visual Style:** 2D, cozy aesthetic, light/pastel color palette, minimal animations.

**Responsive layout:** Base resolution 1080×1920 portrait. Stretch mode: `canvas_items`, aspect: `expand`. On taller phones (18:9 to 21:9 — all current Android flagship/iPhone targets), extra canvas area appears at the bottom; width stays at 1080. All layout-critical elements are derived from live `get_viewport().get_visible_rect().size` values, not hardcoded constants.

**ChoppingBoard positioning (fully runtime-derived, validated at vp.h = 1920/2160/2400/2520):**
- `chop_top = sprite_top_edge - 75` (75px above top sprite row)
- `chop_bottom = sprite_bot_edge + 75 + bezel_height` (75px below bottom sprite row, plus the dark-brown 3D bezel band)
- `bezel_height = wood_height × (24.0 / 234.0)` (derived from actual pixel-level inspection of `choppingBoard.png` — bezel starts at native row 234, 22-row band)
- Stretch mode: `STRETCH_KEEP_ASPECT_COVERED` (fills rect by height, crops width symmetrically — correct for this asset's aspect ratio on the game's range of target devices)
- ChoppingBoard rect: `anchor 0→1, offset_left=0, offset_right=0` (full viewport width, board surface centered within it)
- Both 75px margins hold exactly at all four tested heights by algebraic identity — they're geometry, not calibrated constants.

**Card-row gap:** 150px between board visual bottom and card row top (gap constant in `position_card_row()`). Card row is runtime-positioned from `board_bottom_px`, so it follows any board change automatically.

**Recurring layout rule (project-wide):** Always verify rendered bounds (accounting for asset-internal margins, bezel bands, `KEEP_ASPECT_COVERED` cropping) with an actual screenshot before trusting anchor math. Math has repeatedly been self-consistent while checked against the wrong geometric assumption.

**Title Screen:**
- Background: `#ddab79`
- Logo + "Start Game" button (`quaver.ttf`) over `cafe.png`
- Start Game button: blinking/pulsing animation

**Game Setup Frame:**
- Background: `#544541`
- Level indicator (top-left): `#ddab79` text, `font_size=50`, static
- Timer (top-right): `#ddab79` pill background, `#544541` text
- Chopping board: 6×6 grid (Tiers 1–4) or 8×6 grid (Tier 5); `origin_y = vp.y × 0.22`; `CELL=125`
- Dish cards: below board, two-row `HFlowContainer` (544px height allocation), 4 cards per row at 270×270px

**Recipe Frame:**
- Background: `#544541`
- Recipe card (`recipe_page.png`) centered, 864×1116px canvas units
- Close button: 60×69px, anchored 10px inside inner card border (anchor_left=0.8961, anchor_right=0.9655, anchor_top=0.0412, anchor_bottom=0.1033)
- Ingredient list: `IngredientList.anchor_left=0.13` (count text), `anchor_right=0.90` (icon column)
- Timer/level indicator stay visible; dish-card row hidden while open

**Game Over Frame:**
- Background: `#ef5241`
- `game_over_button.png` with `Color.BLACK`/`Color.WHITE` modulate tween (decorative, not interactive)
- Auto-advances after 3 seconds — no input required

**Restart Game Frame / Next Level Frame:**
- `#ddab79` background, `cafe.png`, logo
- "Restart Game" / "Next Level" button respectively
- Tapping retries same level (Restart) or advances (Next Level)

**Game Complete Screen:**
- `#ddab79` background, `cafe.png`, logo
- Static label: "You completed all levels!" in `quaver.ttf`
- No button, no interaction — fully static

**Screen Flow:**
```
Title Screen (#ddab79)
  → tap "Start Game" → Game Setup Frame (last unfinished level)
                     → Game Complete Screen (if all levels done)

Game Setup Frame (#544541) ↔ Recipe Frame (modal, fade)

Game Setup Frame → [win]
  → bg #8a8f13 for 3s → interstitial → Next Level Frame
  → tap "Next Level" → next Game Setup Frame (or Game Complete Screen)

Game Setup Frame → [lose]
  → Game Over Frame (#ef5241, 3s auto) → interstitial → Restart Game Frame
  → tap "Restart Game" → same level
```

**Accent colors:**
- `#8a8f13` (olive green) — Level Complete background state; ingredient selection highlight (`modulate` on `Sprite2D` child only, not root node)

**Monetization:**
- Banner, interstitial, rewarded ads via `godot-sdk-integrations/godot-admob`
- **Status: Phase 5, not started.** `AdManager` autoload (`autoload/ad_manager.gd`) is currently a stub.

**Remaining art needs:**
- App icon, splash screen
- All new ingredient sprites (×6) and dish sprites (×14) — none sourced yet
- Exact hex values for buttons/card backgrounds/borders still TBD
- Per-level recipe pool curation (40+ levels of explicit K validation)

---

## 6. Platform & Technical Approach

**Engine:** Godot 4.7

**Launch Platforms:** Mobile first (iOS + Android); Desktop planned as a later phase.

**Repository:** `github.com/Krisha052/sweet-treat.git`

**Asset Folder Structure** (already organized, do not reorganize):
```
assets/textures/ingredients/   — ingredient sprites (lowercase snake_case .tres data, PascalCase .png assets)
assets/textures/dishes/        — dish icons for Recipe cards (e.g. CoconutCake.png)
assets/textures/backgrounds/   — cafe.png, choppingBoard.png, recipe_page.png, recipts_card.png (typo is real, on disk)
assets/textures/buttons/       — close_button.png, game_over_button.png, next_level_button.png, restart_game_button.png, start_game_button.png
assets/textures/branding/      — logo.png
assets/fonts/                  — quaver.ttf (Quaver Regular, used project-wide for UI text)
data/ingredients/, data/recipes/, data/levels/ — .tres resources
```

**Save Data:** Local save file (`save.cfg`). `unlocked_level_index` tracks progress. `MAX_LEVEL_INDEX` is a constant in `scripts/ui/main_menu.gd`; update it when the level count changes. (`level_controller.gd`'s own win-sequence check is separate — it looks for the next `level_%02d.tres` file rather than reading this constant, so both places need checking when levels are added.)

**Dev reset (debug builds only):** `Ctrl+Shift+R` in any scene resets `unlocked_level_index=0` and routes to title screen. Gated by `OS.has_feature("debug")` — no-op in release builds. Keyboard-only; not triggerable on device touchscreen. To reset on-device: `adb -s <device> shell run-as com.example.sweettreat rm files/save.cfg` (Debug builds only; confirmed working via Wireless Debugging).

**On-device test setup:** Android, JDK 17 Temurin, standalone Android SDK cmdline-tools, Wireless Debugging. Package name: `com.example.sweettreat`. Pairing and connection ports are always different — use fresh port from phone's Wireless Debugging screen each session. "adb: device offline" fix: `adb disconnect && adb kill-server && adb start-server && adb connect <ip:port>`. See project handoff notes for full setup details.

**Editor-only testing insufficient for:** input bugs (touch/mouse race condition, confirmed via `c4192db`), layout bugs (orientation/resolution), on-device performance profiling. Always verify input and layout changes on actual Android hardware.

**Open technical items:**
- Target frame rate and minimum supported device specs
- Apple Developer account + Google Play Console setup
- iOS build/signing pipeline (requires Mac access)
- AdMob Phase 5 integration

---

## 7. Implementation Status

| Phase | Status |
|---|---|
| 1 — Core gameplay loop | ✅ Done |
| 2 — Navigation, progression, save data | ✅ Done |
| 3 — Content (12 ingredients, 10 recipes, 8 levels) | ✅ Done |
| 4 — UI/art polish, responsive layout | ✅ Done (confirmed working on-device) |
| 4b — Order completion redesign (selection-pool model) | ✅ Done (commit `4569cee`) |
| 4c — Variable board size architecture (per-level `board_cols`/`board_rows`) | ✅ Done (architecture only; no endgame levels built yet) |
| 5 — AdMob integration | ⬜ Not started |
| 6 — Content build (Levels 9–50, new recipes/ingredients) | ⬜ Blocked on art sourcing |

**Key commits for reference:**
- `c4192db` — touch/mouse debounce guard (`ingredient.gd`)
- `e27e38b` — Bug A fix: joint-demand satisfiability in `_pick_next_recipe()`
- `6b45f3c` — Bug B fix: force-placement fallback on satisfiability exhaustion
- `5ff793d` — Type-inference regression sweep (GDScript `:=` on untyped Dicts)
- `f8490e6` — Game Complete screen; `_begin_win_sequence()` branch for last level
- `4569cee` — Order completion redesign: selection-pool model, `_check_completions()`
- `89a52bd` — ChoppingBoard `STRETCH_KEEP_ASPECT_COVERED`
- `c8fa8fa` — ChoppingBoard horizontal recentering (`offset_right: 33 → -33`)

---

## 8. Risks & Open Items

| Item | Notes |
|---|---|
| New art sourcing (6 ingredients, 14 dishes) | Hard blocker for Levels 9–50. Zero unused stock exists — all new art must be sourced/created from scratch. Must be approved before any new `.tres` or level configs are built. |
| Per-level recipe pool curation (Tiers 2–5) | K must be validated per pool at every level — thematic pools required at Tier 2+ to stay within K≤8 on 6×6. Real work, not just a content copy-paste job. |
| Cream as new workhorse ingredient | Appears in 11/24 proposed recipes. Must check cream demand against capacity thresholds at level-design time, same way flour/egg were checked. |
| 2x multiplier restricted to non-flour/egg recipes at Tier 5 | This is a level-design constraint, not an enforced code rule. Must be applied by hand during pool curation — nothing in code prevents a flour-heavy 2x order from being assigned. Consider whether to enforce this in `_pick_next_recipe()` at Tier 5. |
| Dead space below card row on tall phones | 491–584px empty at 21:9. Not a bug — the card row is correctly positioned relative to the board. Worth revisiting post-launch whether to use this space (e.g. slightly taller board on tall phones). |
| Recipe-match selection weighting | When multiple database recipes are completable from the current board, the next dish card is chosen fully at random among valid matches. Weighting to avoid recently-seen dishes repeating is a possible UX improvement — not decided, deferred. |
| No tutorial in shipped game | Players learn tap-to-select + Recipe Frame by trial. Consider a simple guided Level 1 experience post-MVP. Beta test (see [`beta_testing/BETA_TEST_PLAN.md`](beta_testing/BETA_TEST_PLAN.md)) Q4 directly measures this. |
| AdMob integration | Phase 5, not started. `AdManager` is a stub. |
| iOS build/signing | Requires Mac access — confirm before targeting App Store launch. |
| App Store / Play Store review timelines | First submissions take longer than expected — budget extra time. |
| Solo dev bandwidth | Level/recipe balancing, art sourcing, AdMob integration, and cross-device QA all fall on one person. |
| Design doc drift | Keep this doc updated as decisions change — it has fallen out of sync with implementation multiple times. |

---

## 9. Working Conventions

These are established patterns from the project's development history. Continue them in every future session.

**Audit-first for anything risky or stateful.** Before implementing a non-trivial logic change, have Claude Code read the relevant code and restate its understanding back for confirmation before writing any code. This has caught multiple wrong assumptions before they became wasted implementation work — including the Bug A double-booking root cause, the ChoppingBoard aspect-ratio flip, and several UI anchor mismatches.

**Small, scoped prompts over big bundled ones.** This project has repeatedly run out of token budget mid-task on large multi-part prompts, losing uncommitted progress. Break work into rounds that can each finish and commit cleanly. Within a round, it's acceptable to group tightly coupled changes (e.g. two values in the same formula), but avoid bundling unrelated systems.

**Commit and push after every round**, not just at the end of a session. If a session is interrupted mid-task, the next session must audit actual git state first (`git status`, `git log`, diff actual file contents) — never assume partial progress is complete or trust a prior session's summary without re-confirming against disk.

**Verify visually on-device before trusting math.** This project has been burned multiple times by math that was self-consistent but checked against the wrong assumption (wrong resolution, wrong asset dimensions, wrong constraining dimension under `KEEP_ASPECT_CENTERED`/`KEEP_ASPECT_COVERED`, editor-only input behavior). An in-editor screenshot is an acceptable first pass; on-device is required for any input or layout change. Never call a layout round done based on a text description of what a tool output shows.

**Editor-only testing is not sufficient for input or layout bugs.** Two confirmed cases where editor (mouse) testing missed real bugs entirely: (1) the touch/mouse race condition (`c4192db`), which literally cannot be reproduced without real hardware; (2) default landscape orientation, invisible in the editor preview. Any input or layout work must be verified on actual Android hardware.

**Design decisions belong to the developer, not Claude.** Claude's role is to check engineering soundness (math, root causes, whether a proposed fix actually does what it claims) and surface real trade-offs. Anything that is a judgment call — taste, priorities, product direction, content choices — goes back to the developer before implementation. Claude should never quietly resolve an ambiguity or pick a direction without flagging it.

**Always verify the actual rendered edge, not the asset's bounding box.** Assets in this project consistently have meaningful internal structure (bezel bands, transparent corner cutouts, off-center content) that differs from their nominal bounding box. The ChoppingBoard has a dark-brown 3D bezel band starting at native row 234. The recipe card has a transparent staircase corner cutout at the top-right. The close button's visible X sits well inside its asset bounds. Always pixel-inspect an asset before assuming its bounding box equals its visual edge.

---

## Document History

| Date | Change |
|---|---|
| June 23, 2026 | Initial design doc created |
| June 24, 2026 | Walked through title, game setup, recipe, game over, and restart frames; updated gameplay loop, UI details, and resolved several open items |
| June 27, 2026 | Updated to reflect Phase 1–4 implementation: 2D engine, Board Refill mechanic, satisfiability guarantee, Game Over 3s, base resolution locked, asset folder structure, phase status |
| June 28, 2026 | Major update: order completion redesigned (selection-pool/subset model replacing tap-time credit assignment); Bug A/B fixes documented; UI polish round documented (board position, 6×6 grid, two-row card layout, Recipe Frame margins, close button, responsive layout); Game Complete screen added; 50-level scope and tier structure defined; board capacity math and constraints documented; new ingredient/recipe content proposal (6 ingredients, 14 recipes) added pending art approval; variable board size architecture (8×6 Tier 5) documented; multiplier ceiling set at 2x (3x dropped); dev reset shortcut and on-device adb workflow documented |
| July 20, 2026 | Added README.md; confirmed repository URL against `git remote -v`; corrected `MAX_LEVEL_INDEX` location — it lives only in `main_menu.gd` (`level_controller.gd`'s win-sequence check is file-existence based, not constant-based) |
| July 20, 2026 | Added beta test plan, survey question set, and results template under `docs/beta_testing/` ahead of the 8-level Android beta |
