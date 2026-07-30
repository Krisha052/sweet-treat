# Sweet Treat — Game Design Document

*Last updated: July 30, 2026*

---

## 1. Overview

**Working Title:** Sweet Treat

**Genre:** Time-management / cooking-puzzle hybrid

**Pitch:** A cozy 2D cafe simulation where players race against the clock to fulfill dish orders, shown as image-based dish cards (tapping a card opens a Recipe Frame revealing its exact ingredient list). Players tap matching ingredients directly on a chopping-board grid to select them toward any active order; a recipe completes the moment its full ingredient list is present within the current selection, regardless of what else is also selected. There are no visible customers; the focus stays tight on ingredient logistics and recipe assembly. Progression is linear and strictly forward-only — players always resume exactly where they left off. Levels escalate via more simultaneous orders, tighter timeframes, and 2x batch multipliers on existing recipes.

**Visual Style:** 2D, cozy aesthetic, light/pastel color palette, minimal animations — sprite-based (Sprite2D/TextureRect), no 3D models anywhere in the project. *(Note: the project was originally scoped as 3D and was converted to 2D early in Phase 4. This doc reflects the current state.)* Palette confirmed for the title, gameplay, and game-over screens (see Section 4); the broader game-wide scheme is muted/earthy, anchored to the existing (fixed) asset pack colors, particularly the bakery exterior (`cafe.png`).

**Platforms:** Mobile (iOS + Android) for initial launch; Desktop (Windows/Mac) planned as a later phase. Built in Godot 4.7.

**Business Model:** Free-to-play, supported by ads (banner, interstitial, and rewarded). *(Interstitial fully implemented on Android, including GDPR/UMP consent — but disabled for the initial launch pending a real AdMob account; banner and rewarded not yet built. See Section 5, Phase 5 status.)*

**Target release scope:** 100 levels. *(All 100 implemented — see Section 3.)*

**Team:** Solo developer.

---

## 2. Core Gameplay Loop

**Camera:** Static 2D scenes — no camera movement, no player movement controls.

**Board:** A grid on the chopping-board asset, filled independently at random from the current level's eligible ingredient set (the union of ingredients across that level's `recipe_pool`). Duplicate ingredients across slots are allowed and expected. A small chance (`DECOY_CHANCE = 0.15` in `level_controller.gd`) draws from the *full* ingredient roster instead, purely for board variety on low-K levels that would otherwise skew toward near-single-ingredient monotony — decoys are never required by any recipe, so they don't affect satisfiability.

**Board size:** 6×6 grid (36 slots) for all 100 levels — no per-level size variation in the current content (an earlier design used an 8×6 endgame board; that was reverted, see Section 3).

`BOARD_ROWS`/`BOARD_COLS` are per-level fields on `LevelConfig` (defaulting to 6/6), not hardcoded constants, so per-level board size remains fully supported architecturally even though nothing currently uses a non-default value. The entire layout chain (board origin, ChoppingBoard positioning, hit-targets, card-row) derives from these values at runtime so changing board size per level requires no additional layout work.

**Selection model:** Tapping an ingredient toggles its selected state (olive-green tint `#8a8f13` via `modulate`, applied to the `Sprite2D` child only — the `CollisionShape2D` is a sibling and its scale is unaffected). Selected ingredients go into a shared `_selected_pool` (tracked by object identity). Tapping a selected ingredient again deselects it and removes it from the pool. No ingredient is ever committed to a specific order at tap time.

**Selection cap:** at most 4 simultaneous selections normally, 8 if any active order is a doubled (`_x2`) recipe (`OrderManager._max_selectable()`, checked in `toggle_ingredient()` — deselecting is never blocked). A tap that would exceed the cap is rejected: the tapped ingredient plays `reject_flash()` (a red-tinted shake, `scripts/gameplay/ingredient.gd`) instead of the normal neutral pulse every tap gets, so a blocked selection reads differently from a successful one.

**Order completion:** After every select action, the system checks all active orders (oldest-first) using a subset/containment check: does `_selected_pool` contain at least the required count of every ingredient type that order needs? Extra selected ingredients beyond what an order needs do not block it. The first order whose full requirement is found in the pool completes immediately — consuming only the specific slots it needed. Remaining selected ingredients stay selected, still available toward other orders. Deselecting never triggers a completion check (removing items can only shrink the pool, never newly satisfy an order).

Tie-break (multiple orders simultaneously satisfied by a single tap): complete oldest first, then re-check the now-smaller pool for further completions before returning — cascading until stable.

**Joint-demand satisfiability (Bug A fix):** When assigning a new recipe to an order slot (at initial spawn or after a refill), `_pick_next_recipe()` checks satisfiability against `available = free_board - committed_of_others` — not the raw board in isolation. `committed_of_others` is the sum of all other active orders' full remaining needs. This prevents double-booking: a recipe is only assigned if the board can cover its full requirement on top of what other active orders already need.

**Board Refill & Satisfiability Guarantee:** When an order completes, its consumed slots clear and refill. After every refill — both initial setup and post-completion — the system re-rolls the board (up to 20 attempts) until at least one active order is completable. The completability check uses `free_board + _selected_pool` combined (not just free board), so selected ingredients already in the pool are counted toward satisfiability and don't trigger unnecessary force-placement.

**Force-placement fallback (Bug B fix):** If 20 re-roll attempts all fail, instead of silently accepting an unsatisfiable board, the system force-places the minimum missing ingredients for the single active order with the smallest total deficit. Spill slots (when the deficit needs more slots than were just consumed) exclude both the just-consumed set and any slot currently selected by the player toward another order. If no eligible spill slot exists, `push_warning` fires and the existing worst-case behavior applies (no partial placement).

**Newly-spawned-order guarantee (Bug C fix, 2026-07-30):** `_pick_next_recipe()` has an internal fallback — if nothing in the pool is satisfiable from the currently-uncommitted board, it returns a fully random recipe from the pool with no guarantee the board can supply it. Every *other* order-assignment path (initial board, post-completion refill) already had the re-roll + force-placement safety net; this one didn't, and it's the path used every time a new order is spawned mid-level. Fixed by re-running the same `any_active_order_satisfiable()` / `get_force_deficit()` / `_apply_force_placement()` guarantee immediately after `spawn_order()` in `level_controller.gd`'s `_on_order_completed_cb()`, so a newly-spawned order (including literally the last order of a level) can never ship unfixably stuck. This was the root cause of a developer-reported bug ("the very last order often doesn't have enough ingredients on the board") that got worse at higher levels — higher K and higher total-orders both increase how often the pool's satisfiable-set comes up empty at spawn time.

**Ingredient hit-targets:** `CollisionShape2D` native radius = 81px. Root node scale = 0.80 (affects collision). `Sprite2D` local scale = 0.875 (net visual 0.70, visual-only). Effective hit diameter = 81 × 0.80 × 2 = **130px** at 6×6 (the only board size currently in use). Cell size = 125px at 6×6.

**Dish cards:** Displayed below the chopping board in an `HFlowContainer` supporting two rows (544px total height allocation). Cards are 270×270px; 4 cards fill one row exactly (4×270=1080px). A 5th card wraps to row 2. The dish-card row's position is computed at runtime from the board's actual pixel bounds via `hud.gd`'s `position_card_row()`, with a 190px gap between board bottom and card row top (bumped from 150px per developer feedback for more breathing room).

**Recipe Frame:** Tapping a dish card opens the Recipe Frame — a full-screen modal. Timer continues running. Dish-card row is explicitly hidden while open, restored on close. Exit via a dedicated "X" close button (top-right of card, 60×69px, anchored 10px inside the card's inner visible border). Ingredient count text (x1, x2) uses `IngredientList.anchor_left = 0.13`. Transition: fade in/out.

**Game Complete Screen:** Shown when a player wins the final available level (Level 100). Fully static — no button, no interaction. Layout: `#ddab79` background, `cafe.png` backdrop, Sweet Treat logo, static label "You completed all levels!" in `quaver.ttf`. Triggered from `_begin_win_sequence()` when no next level file exists, and from `main_menu.gd` when `unlocked_level_index > MAX_LEVEL_INDEX`.

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

**Difficulty levers:** primarily **total orders required to win the level** (see the 100-level structure below — this is the dominant lever, by design), plus number of simultaneous orders queued (caps at 6) and 2x batch multiplier on select recipes. Ingredient variety (K) is *not* a difficulty lever — it grows only as fast as new recipes are introduced and is otherwise kept as low as the capacity table allows.

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

**100-Level Structure (superseded the original 50-level/5-tier design on 2026-07-28 — see below):**

**Recipe introduction:** Level 1 starts with 2 recipes (`bread` + `bun` — a free pairing, since `bun` uses the exact same 3 ingredient types as `bread`, so starting with 2 dishes instead of 1 costs zero extra K). One new recipe introduces every 3rd level after that (levels 3, 6, 9, ... 93 — 31 slots for the remaining 31 recipes), landing exactly on all 33 recipes (28 base + 5 `_x2`) by level 93. Levels 94–100 are a pure-mastery finale: no new content, just the hardest scaling against everything already known. New recipes are always introduced clustered by theme (Classic Bakery → Fruit Cakes → Café/Coffee → Specialty Drinks → Cakes/Confections → Waffles & Pancakes → Japanese Treats → the 5 `_x2` doubled recipes, in that order — see Section 4's pool table) and always mixed into a pool with already-known recipes, never alone.

**Timer bands (flat, not gradually tightening):**
- Levels 1–30: 90s
- Levels 31–60: 120s
- Levels 61–100: 180s

**`max_simultaneous_orders`:** ramps 1 (L1–2) → 2 (L3–5) → 3 (L6–9) → 4 (L10–14) → 5 (L15–22) → 6 (L23–100, held for the remaining 78 levels — deliberately capped rather than kept climbing).

**Total orders to win** (`recipe_pool` array length — see implementation note below): linear ramp within each timer band, stepping up at each band boundary since the extra time budget affords it:
- Band 1 (L1–30): 3 → 12
- Band 2 (L31–60): 13 → 20
- Band 3 (L61–100): 22 → 36

Calibrated against the original hand-built levels' own pace (level 8: 5 orders / 45s ≈ 9s/order) — band 1 finishes around 7.5s/order, band 2 around 6s/order, band 3's finale around 5s/order. Tightens gradually without becoming inhuman.

**Implementation status (Levels 1–100):** All 100 levels are built (`data/levels/level_01.tres`–`level_100.tres`), fully replacing the original 50-level/5-tier structure (levels 1–8 included — the original hand-built onboarding levels were rebuilt too, for consistency with the new flat-timer-band + every-3rd-level cadence). Two mechanics carried over unchanged from the 50-level build and are worth restating since they're not obvious from the numbers above:

- **`recipe_pool` array length is not "distinct recipe variety" — it's literally the total number of orders required to win the level** (`OrderManager._total_orders = config.recipe_pool.size()`; see `scripts/gameplay/order_manager.gd`). Total-orders-to-win scales via **duplicate entries** of already-known recipes in the pool array (e.g. `[espresso, espresso, espresso, caramel_latte]` — 4 total orders, 2 distinct recipes). This is *the* difficulty lever by design; distinct-recipe-count (and therefore K) grows only when a new recipe is introduced, capped at exactly 1 per introduction level (2 at level 1), always mixed with already-known recipes.
- **The 2x batch multiplier still has no engine support** — it's faked via separate `_x2` `RecipeData` resources with doubled ingredient counts, each with its own icon (base dish art plus a composited "×2" badge, e.g. `CherryCakeX2.png`) so a doubled order is visually distinguishable from the dish card alone. The 5 `_x2` recipes are introduced like any other recipe in the schedule above (levels 81–93), each paired with a small hand-picked K-safe companion set (e.g. `waffles_x2` pools with `waffles, pancakes, bread` rather than the full 8-recipe Waffles & Pancakes cluster, which would blow past the K≤6 ceiling required for any pool containing an `_x2` recipe) rather than a dedicated late-game "2x tier."
- Board stays 6×6 throughout all 100 levels — no per-level size changes.

**Pool curation algorithm (reworked 2026-07-30 after a full 100-level playtest):** the generator script that produces `data/levels/*.tres` extends the same cluster/introduction-schedule structure above, but the July 28 version had two real gaps a full playthrough surfaced:

- **Newly-introduced recipes could go statistically unseen.** Equal-split weighting meant a level 3's `croissant` (weight 1 of 4 total orders) had a real chance of never being drawn in a short level. Fixed: newly-introduced recipes now get a 2.5× weight multiplier (plus a 1.5× multiplier for any recipe with "cake" in its id, per developer request — the two stack) in the weighted-distribution step (`build_weighted_pool()`), using largest-remainder rounding so the requested total-orders count is still hit as closely as possible.
- **`_x2` recipes vanished from every level after their own single introduction level.** The old fallback cluster-lookup never registered `_x2` ids in `CLUSTERS`, so they silently dropped out the moment the level moved past their introduction. Fixed with `x2_phase_pool()`: for levels 81+, greedily includes as many known `_x2` recipes (+ companions) as fit within K≤6, most-recently-introduced first, so they persist and mix together (e.g. level 93 now pools 10 recipes spanning all 5 `_x2` recipes at K=6, versus 3 recipes/1 `_x2` before).
- **Older recipes barely resurfaced once their own cluster's window closed.** The pre-x2-phase pool logic (levels 1–80) now reaches back through *all* earlier clusters (not just the immediately-previous one), greedily adding whole clusters while K≤8 else individual recipes that fit — so e.g. level 21 now pools `cappuccino` (newly introduced) alongside `strawberry_cake`, `raspberry_cake`, and four Classic Bakery recipes, all at K=8, instead of just 1–2 recipes.

All 100 regenerated levels re-passed the same K/capacity/introduction-cadence validation as every prior round (zero violations).

**Win/Lose Condition:** Pass/fail only — no star ratings. Won = all orders complete before timer. Lost = timer runs out.

**Level Complete flow:** Background shifts `#544541` → `#8a8f13` for 3s → interstitial ad → Next Level Frame → tap "Next Level" → next level (or Game Complete screen if on the last level).

**Retry flow:** Game Over Frame (3s, auto-timed) → interstitial ad → Restart Game Frame → tap "Restart Game" → same level, free retry, no cooldown.

---

## 4. Content

### Current Content (implemented)

**Ingredients (19):** cherry, coconut, bean_dark_roast, egg, flour, foam, bean_light_roast, milk, bean_medium_roast, bean_raw, red_tea, strawberry, **matcha, chocolate, cream, butter, sugar, caramel, raspberry**

`milk`'s sprite was briefly swapped to new carton art, then **reverted back to the original jug art** after a developer playtest — the jug matched the rest of the game's aesthetic better. `chocolate`'s sprite was swapped a second time to different source art (developer-provided) after the first version didn't read clearly. `sugar`'s sprite was swapped from a sugar-bowl icon to a generated two-cube icon (matching the warm-brown-outline, soft-shaded style of the rest of the ingredient pack; scaled to the same 130px content size the bowl art used). `caramel`'s sprite was swapped to developer-provided source art (scaled to the same 144px content size the old jar art used), resolving the earlier aesthetic-mismatch flag for the ingredient icon — the `CaramelLatte` **dish** icon is a separate asset and still has the original mismatch, not yet addressed. `matcha`'s green tones were darkened ~20% (an exact-color remap of the 5 shades in its shading gradient) to feel more muted/earthy against the rest of the palette. `MatchaLatte`'s dish icon was swapped to developer-provided source art (a mug with green matcha foam on a saucer, replacing the original glass mug) on 2026-07-30 — an earlier attempt at this swap had mistakenly applied a plain to-go-cup asset (visually identical to `HotChocolate`'s icon) instead of the intended mug art; corrected once the mismatch was caught during playtest verification. Scaled to the same 252px content size the old icon used.

**Recipes (33):** bread, bun, cappuccino, cherry_cake, coconut_cake, coffee_cake, croissant, espresso, latte, strawberry_cake (icon replaced with new art), **raspberry_cake, caramel_latte, hot_chocolate, matcha_latte, honey_tea, chocolate_cake, sugar_cake, waffles, berry_waffles, chocolate_waffles, strawberry_waffles, pancakes, berry_pancakes, chocolate_pancakes, cream_pancakes, dorayaki, purin, strawberry_daifuku, bread_x2, cherry_cake_x2, raspberry_cake_x2, waffles_x2, pancakes_x2**

### Content build history

An earlier round of this doc proposed 6 new ingredients (Matcha, Chocolate, Cream, Butter, Sugar, Caramel) and 14 new recipes, pending art sourcing. When art actually arrived (`assets/textures/new ingredients/`, `assets/textures/new dishes/`), it diverged from that plan in two ways worth recording:

- **A 7th ingredient (Raspberry) arrived**, needed for a Raspberry Cake recipe (repurposing the original strawberry_cake dish icon after strawberry_cake got new art — see asset swap note below).
- **Only 6 of the 14 planned recipes had matching art** (Caramel Latte, Chocolate Cake, Honey Tea, Hot Chocolate, Matcha Latte, Sugar Cake). The other 8 (Matcha Cake, Caramel Cake, Strawberry Cream, Cherry Cream, Coconut Cream, Cream Puff, Butter Biscuit, Chocolate Croissant) have no art and were dropped. In their place, **12 new dish images arrived that weren't in the original plan at all** — a waffle/pancake family (Waffles, Berry/Chocolate/Strawberry Waffles, Pancakes, Berry/Chocolate/Cream Pancakes) and a Japanese-dessert family (Dorayaki, Purin, Strawberry Daifuku) — so the recipe set was redesigned around the art that actually exists rather than the original 14.

**Recipe pools (thematic clusters, introduced in this order across the 100-level structure in Section 3):**

| Pool | Recipes | K (distinct ingredient types) | Introduced |
|---|---|---|---|
| Classic Bakery | bread, bun, croissant, cherry_cake, coconut_cake, coffee_cake | 6 (flour, milk, egg, cherry, coconut, bean_medium_roast) | Levels 1 (bread+bun), 3, 6, 9, 12 |
| Fruit Cakes | strawberry_cake, raspberry_cake | 4 (+strawberry, raspberry) | Levels 15, 18 |
| Café/Coffee | cappuccino, espresso, latte | 7 (bean_light/medium/dark/raw, milk, foam, red_tea) | Levels 21, 24, 27 |
| Specialty Drinks | caramel_latte, hot_chocolate, matcha_latte, honey_tea | 8 (bean_dark, caramel, cream, chocolate, milk, matcha, foam, red_tea) | Levels 30, 33, 36, 39 |
| Cakes/Confections | chocolate_cake, sugar_cake | 4 (chocolate, cream, sugar, egg) | Levels 42, 45 |
| Waffles & Pancakes | waffles, berry_waffles, chocolate_waffles, strawberry_waffles, pancakes, berry_pancakes, chocolate_pancakes, cream_pancakes | 8 (flour, egg, milk, butter, raspberry, chocolate, strawberry, cream) | Levels 48, 51, 54, 57, 60, 63, 66, 69 |
| Japanese Treats | dorayaki, purin, strawberry_daifuku | 7 (flour, egg, milk, chocolate, sugar, caramel, strawberry) | Levels 72, 75, 78 |
| Doubled (`_x2`) | bread_x2, cherry_cake_x2, raspberry_cake_x2, waffles_x2, pancakes_x2 | Each paired with a small hand-picked K-safe companion set (K≤6), not the full base cluster | Levels 81, 84, 87, 90, 93 |

Levels 94–100 rotate through 3 mastery pools with no new content: the full Waffles & Pancakes cluster (K=8), a Cakes/Japanese combo (chocolate_cake, sugar_cake, dorayaki, purin, strawberry_daifuku, strawberry_cake — K=8), and a mixed old+new doubled combo (bread, bun, cherry_cake, coconut_cake, raspberry_cake, cherry_cake_x2, raspberry_cake_x2 — K=6).

Dorayaki's traditional red-bean filling has no equivalent ingredient in this game (the `bean_*` ingredients are coffee beans, not azuki) — it's built as a chocolate-filled pancake sandwich instead. Strawberry Daifuku uses `flour` as a stand-in for mochi rice flour, consistent with how `flour` is already used generically elsewhere.

**Ingredient usage across all 33 recipes:**

| Ingredient | Recipes using it | % |
|---|---|---|
| flour | 23/33 | 69.7% |
| egg | 21/33 | 63.6% |
| milk | 16/33 | 48.5% |
| cream | 6/33 | 18.2% |
| butter / chocolate | 5/33 each | 15.2% |
| sugar / raspberry | 4/33 each | 12.1% |
| foam / strawberry / caramel / bean_medium_roast | 3/33 each | 9.1% |
| cherry / bean_dark_roast / bean_light_roast / red_tea | 2/33 each | 6.1% |
| matcha / bean_raw / coconut | 1/33 each | 3.0% |

This is a real divergence from the earlier plan's goal (which aimed to shrink flour/egg share via cream-based recipes) — flour and egg stayed dominant because the art that actually arrived skews toward waffle/pancake/bakery dishes rather than the cream-based confections originally envisioned. This is not a violation of the Section 3 capacity constraints, though: those constraints are validated **per level pool**, not against the recipe database as a whole, and every built level (9–50) was checked individually against the K/simultaneous-order limits (see Section 3 implementation note). It's worth knowing about for future recipe/level design, since it means flour/egg supply is the thing to watch first when curating any new pool.

**Asset swaps performed:**
1. `strawberry_cake`'s icon was replaced with new art (`assets/textures/dishes/StrawberryCake.png` now contains the new pink-frosted slice); ingredients unchanged (strawberry×2, flour×1, egg×1).
2. The original strawberry-cake pixel art was preserved as `assets/textures/dishes/RaspberryCake.png` and used for the new `raspberry_cake` recipe (raspberry×2, flour×1, egg×1, mirroring strawberry_cake's structure). Note: this art still visually reads as a strawberry cross-section (pointed shape, seed texture), not a raspberry — a deliberate call to reuse existing art over sourcing new, made by the developer.
3. `milk`'s icon was swapped to new carton art, then reverted back to the original jug art after developer playtest feedback — jug art is final.
4. `chocolate`'s icon was swapped a second time to developer-provided source art after the first version's aesthetic didn't land.
5. All new ingredient/dish icons introduced this content round were normalized to the existing size convention (160×160 ingredients, 320×320 dishes) and recentered where the source art was significantly off-center within its canvas (the waffle family and Hot Chocolate were the worst offenders, up to 55px off).
6. Each `_x2` recipe (`bread_x2`, `cherry_cake_x2`, `raspberry_cake_x2`, `waffles_x2`, `pancakes_x2`) has its own dish icon — base art with a composited "×2" badge (dark-orange circle, bottom-right corner) — rather than reusing the base recipe's icon, so a doubled order reads as doubled from the dish card alone.
7. `sugar`'s sprite was swapped from a sugar-bowl icon to a generated two-cube icon, then swapped again to developer-provided single-cube art in a black-outline pixel style matching the original 12 ingredients.
8. `matcha`'s green tones were darkened ~20% (exact-color remap of the 5 shades in its shading gradient) for a more muted/earthy look. `MatchaLatte`'s dish icon was swapped to developer-provided art, replacing the original glass mug — corrected 2026-07-30 to the intended mug-with-green-foam art after an earlier pass had mistakenly applied a to-go-cup asset identical to `HotChocolate`'s icon.
9. `caramel`'s sprite was swapped a second time to developer-provided art in the same black-outline pixel style as the rest of the original 12 — resolves the ingredient half of the earlier aesthetic-mismatch flag. `cream`'s sprite got the same style swap. `CaramelLatte`'s and `HotChocolate`'s dish icons were swapped to developer-provided art, resolving both remaining long-standing dish-icon aesthetic-mismatch flags from Section 8.
10. `Dorayaki.png` and `StrawberryDaifuku.png` were re-cropped and rescaled (they were only 25%/42% height-fill vs. 65–95% for comparable dishes — never re-centered after their original small-source upscale); `Purin.png` got the same treatment for consistency.

Every asset swap in this list uses the same methodology: crop to the new source's tight content bounding box, scale so its largest dimension matches the *old* icon's content size (or a project-convention target for icons being upscaled for the first time), then center on the same canvas size — so replacing an icon never changes its visual scale relative to the rest of the set.

---

## 5. UI & Art Direction

**Visual Style:** 2D, cozy aesthetic, light/pastel color palette, minimal animations.

**Responsive layout:** Base resolution 1080×1920 portrait. Stretch mode: `canvas_items`, aspect: `expand`. On taller phones (18:9 to 21:9 — all current Android flagship/iPhone targets), extra canvas area appears at the bottom; width stays at 1080. All layout-critical elements are derived from live `get_viewport().get_visible_rect().size` values, not hardcoded constants.

**ChoppingBoard positioning (fully runtime-derived, validated at vp.h = 1920/2160/2400/2520):**
- `chop_top = sprite_top_edge - 75` (75px above top sprite row)
- `chop_bottom = sprite_bot_edge + 75 + bezel_height` (75px below bottom sprite row, plus the dark-brown 3D bezel band)
- `bezel_height = wood_height × (24.0 / 234.0)` (derived from actual pixel-level inspection of `choppingBoard.png` — bezel starts at native row 234, 22-row band)
- Stretch mode: `STRETCH_KEEP_ASPECT_COVERED` (fills rect by height, crops width symmetrically around the *rect's* center — correct for this asset's aspect ratio on the game's range of target devices, but only if the source texture's own content is centered within its canvas; see the left-crop bug below)
- ChoppingBoard rect (`scenes/levels/level_base.tscn`): `anchor 0→1`, `offset_left=48, offset_right=-48` (symmetric inset from full viewport width; bumped from ±33 on 2026-07-30 for a slightly smaller board per developer feedback)
- Both 75px top/bottom margins hold exactly at all four tested heights by algebraic identity — they're geometry, not calibrated constants.
- **Left-crop bug (fixed 2026-07-30):** despite the rect being horizontally symmetric, the board was visibly clipped on the left on-device. Root cause: `choppingBoard.png`'s own content was off-center *within its source canvas* (6px left margin vs. 24px right margin, confirmed by pixel inspection) — `KEEP_ASPECT_COVERED` crops width symmetrically around the canvas center, so the side already tight on margin got cut into the actual artwork first. Fixed by recentering the source PNG's content within its canvas (now 15px/15px) rather than adjusting the rect math — same class of fix as other off-center-asset issues in this project (see the recurring layout rule below).

**Card-row gap:** 190px between board visual bottom and card row top (gap constant in `position_card_row()`; bumped from 150px on 2026-07-30 for more breathing room). Card row is runtime-positioned from `board_bottom_px`, so it follows any board change automatically.

**Recurring layout rule (project-wide):** Always verify rendered bounds (accounting for asset-internal margins, bezel bands, `KEEP_ASPECT_COVERED` cropping) with an actual screenshot before trusting anchor math. Math has repeatedly been self-consistent while checked against the wrong geometric assumption.

**Title Screen:**
- Background: `#ddab79`
- Logo + "Start Game" button (`quaver.ttf`) over `cafe.png`
- Start Game button: blinking/pulsing animation

**Game Setup Frame:**
- Background: `#544541`
- Level indicator (top-left): `#ddab79` text, `font_size=50`, static
- Timer (top-right): `#ddab79` pill background, `#544541` text
- Chopping board: 6×6 grid (all 100 levels); `origin_y = vp.y × 0.22`; `CELL=125`
- Dish cards: below board, two-row `HFlowContainer` (544px height allocation), 4 cards per row at 270×270px

**Recipe Frame:**
- Background: `#544541`
- Recipe card (`recipe_page.png`) centered, 864×1116px canvas units
- Close button: 60×69px, anchored 10px inside inner card border (anchor_left=0.8961, anchor_right=0.9655, anchor_top=0.0412, anchor_bottom=0.1033)
- Dish icon: `DishIcon.anchor_top=0.02` → `anchor_bottom=0.28`
- Recipe name: `RecipeName` label, anchor_top=0.30 → 0.365, Quaver font size 56, centered — inserted below the icon; preserves the original 0.02-anchor icon→content gap on both sides (icon→name and name→ingredients)
- Ingredient list: `IngredientList.anchor_top=0.385` (shifted down to make room for the name label), `anchor_left=0.13` (count text), `anchor_right=0.90` (icon column)
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
- Banner, interstitial, rewarded ads via `godot-sdk-integrations/godot-admob` (plugin v7.0, Godot 4.7-compatible; installed in `addons/AdmobPlugin/`)
- **Status: interstitial + GDPR/UMP consent fully implemented, but disabled for the initial launch** (`ADS_ENABLED := false` in `autoload/ad_manager.gd`, 2026-07-30) since there's no real AdMob account yet — see the account setup note below. Banner and rewarded remain deferred separately (no design decision made — see Section 8).
- `AdManager` (`autoload/ad_manager.tscn` + `ad_manager.gd`) wraps an `Admob` child node and exposes `show_interstitial()` (awaitable — shows a preloaded ad and waits for dismissal, or returns immediately if none is ready so a scene transition never stalls). Wired into both existing interstitial points: Game Over → Restart (`scripts/ui/game_over_screen.gd`) and Level Complete → Next Level (`scripts/gameplay/level_controller.gd`).
- **GDPR/UMP consent flow:** `_ready()` calls `update_consent_info()` before anything else; `is_consent_form_available()` gates `load_consent_form()`, which in turn only calls `show_consent_form()` if `get_consent_status().status == UserConsent.Status.REQUIRED` (the EEA/UK case). Every failure/dismissal path falls through to `_start_ads()` (which calls `_admob.initialize()`) rather than risking a stuck game — consent resolution never blocks gameplay. Verified on-device: outside the EEA/UK the SDK reports `gdprApplies=0`, the form is skipped, and the interstitial loads normally within seconds.
- **`ADS_ENABLED` flag:** when `false` (current state), `_ready()` returns immediately — no consent request, no SDK init, no ad load, confirmed via on-device logcat showing zero ad-related activity beyond the plugin's own unavoidable native registration. `show_interstitial()` also short-circuits as a safety net. Flip the flag back to `true` once real AdMob IDs are in place (see below) to re-enable with no other code changes.
- `show_banner()`/`hide_banner()`/`show_rewarded()` remain no-op stubs — no banner placement or reward mechanic has been decided yet (see Section 8).
- Ad unit IDs live on the `Admob` node in `ad_manager.tscn`: currently `is_real = false` running Google's published test IDs. Real IDs go in `android_real_application_id` / `android_real_interstitial_id` on that same node once an AdMob account exists, then flip `is_real = true` (and `ADS_ENABLED = true` in `ad_manager.gd`).
- Android only — no iOS export preset exists yet (see Section 6 open items).
- Required Custom Gradle Build, previously off: `export_presets.cfg` now has `gradle_build/use_gradle_build=true`, `gradle_build/min_sdk="24"` (this file is gitignored — machine-local, not something a `git diff` will show).

**AdMob account setup process (for when ads are turned back on):**
1. Sign into/create an AdMob account at `admob.google.com` with the Google account that should receive ad revenue. Billing/payment info can be added later — it isn't required just to get IDs and start testing.
2. Apps → Add app → answer "No" to "already listed on Google Play/App Store" (unless there's already a live Play Store listing) → platform **Android** → name it "Sweet Treat". This produces an **App ID** (`ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY`) → goes in `android_real_application_id`.
3. Apps → Sweet Treat → Ad units → Add ad unit → **Interstitial** (name it something like "Level Complete / Game Over Interstitial"). This produces an **Ad unit ID** (`ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ`) → goes in `android_real_interstitial_id`.
4. Paste both IDs into the `Admob` node in `autoload/ad_manager.tscn`, flip `is_real = true`, flip `ADS_ENABLED = true` in `ad_manager.gd`, rebuild, and confirm on-device it doesn't crash. Note: real ads generally won't *serve* on an emulator/unregistered test device even with real IDs — register the device as an AdMob test device first to avoid an invalid-traffic policy risk while verifying.

**Remaining art needs:**
- App icon, splash screen
- Exact hex values for buttons/card backgrounds/borders still TBD
- A few recipe pools (Specialty Drinks, Cakes/Confections, Japanese Treats — see Section 4) are thinner than ideal; more on-theme dish art would let them grow toward the tier tables' pool-size targets

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

**Dev reset (debug builds only):** `Ctrl+Shift+R` in any scene resets `unlocked_level_index=0` and routes to title screen. Gated by `OS.has_feature("debug")` — no-op in release builds. Keyboard-only; not triggerable on device touchscreen. To reset on-device: `adb -s <device> shell run-as com.sweettreat.app rm files/save.cfg` (Debug builds only; confirmed working via Wireless Debugging).

**On-device test setup:** Android, JDK 17 Temurin, standalone Android SDK cmdline-tools, Wireless Debugging. Package name: `com.sweettreat.app`. Pairing and connection ports are always different — use fresh port from phone's Wireless Debugging screen each session. "adb: device offline" fix: `adb disconnect && adb kill-server && adb start-server && adb connect <ip:port>`. See project handoff notes for full setup details.

**Editor-only testing insufficient for:** input bugs (touch/mouse race condition, confirmed via `c4192db`), layout bugs (orientation/resolution), on-device performance profiling. Always verify input and layout changes on actual Android hardware.

**Open technical items:**
- Target frame rate and minimum supported device specs
- Apple Developer account + Google Play Console setup
- iOS build/signing pipeline (requires Mac access) — also blocks iOS AdMob config (Info.plist, SKAdNetwork, App Tracking Transparency prompt), which the plugin otherwise handles automatically at export time
- Real AdMob account + app + ad unit IDs — ads are otherwise launch-ready but disabled (`ADS_ENABLED := false`) until this exists; see the account setup steps in Section 5

---

## 7. Implementation Status

| Phase | Status |
|---|---|
| 1 — Core gameplay loop | ✅ Done |
| 2 — Navigation, progression, save data | ✅ Done |
| 3 — Content (12 ingredients, 10 recipes, 8 levels) | ✅ Done |
| 4 — UI/art polish, responsive layout | ✅ Done (confirmed working on-device) |
| 4b — Order completion redesign (selection-pool model) | ✅ Done (commit `4569cee`) |
| 4c — Variable board size architecture (per-level `board_cols`/`board_rows`) | ✅ Done (architecture only — all 100 shipped levels currently use the 6×6 default) |
| 5 — AdMob integration | 🟨 Partial — interstitial + GDPR/UMP consent fully built (Android), but disabled for launch pending a real AdMob account (`ADS_ENABLED := false`); banner and rewarded deferred, see Section 5/8 |
| 6 — Content build (100 levels, new recipes/ingredients) | ✅ Done (19 ingredients, 33 recipes, 100 levels; see Section 4). 2x multiplier is a data-only fake, not a real engine feature — see Section 3 implementation note. Expanded from 50 to 100 levels on 2026-07-28 with a new every-3rd-level introduction cadence, replacing the prior 5-tier structure (see Document History). All 100 levels regenerated again on 2026-07-30 after a full playtest surfaced pool-curation gaps (new-recipe visibility, `_x2` persistence, older-recipe reach-back, cake weighting) — see Section 3's pool algorithm note and Document History. |
| 6b — Post-100-level playtest fixes (order-spawn safety net, selection cap, board variety) | ✅ Done — see Document History (2026-07-30). |

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
| 2x multiplier is a data-only fake, not a real engine feature | `_x2` RecipeData resources (doubled ingredient counts, own badged icon) stand in for a real batch-multiplier mechanic that was never built (`LevelConfig`/`OrderManager` have no multiplier field). Works fine with existing completion-check/UI logic, but if a proper multiplier system is ever built (dynamic scaling instead of fixed doubled recipes), the 5 `_x2` resources should be revisited. |
| `recipe_pool.size()` doubles as both variety and total-orders-to-win | Non-obvious `OrderManager` behavior (`_total_orders = config.recipe_pool.size()`) that shaped a full level-design rework after a 2026-07-27 playtest — see Section 3's implementation note. Any future level curation should keep treating "total orders" (pool array length, padded with duplicate known-recipe entries) and "how many recipes are new to the player" as separate levers, not one. |
| flour/egg remain the dominant ingredients across all 33 recipes (69.7%/63.6%) | The art that arrived for this content build skewed toward waffle/pancake/bakery dishes rather than the cream-based confections an earlier version of this doc planned around, so flour/egg concentration didn't drop the way that plan intended. Not a violation of any per-level K constraint (every one of the 100 levels is individually validated — see Section 3), but worth knowing when curating future pools: flour/egg supply is the first thing to check. |
| Dead space below card row on tall phones | 491–584px empty at 21:9. Not a bug — the card row is correctly positioned relative to the board. Worth revisiting post-launch whether to use this space (e.g. slightly taller board on tall phones). |
| Recipe-match selection weighting | When multiple database recipes are completable from the current board, the next dish card is chosen fully at random among valid matches. Weighting to avoid recently-seen dishes repeating is a possible UX improvement — not decided, deferred. |
| No tutorial in shipped game | Players learn tap-to-select + Recipe Frame by trial. Consider a simple guided Level 1 experience post-MVP. Beta test (see [`beta_testing/BETA_TEST_PLAN.md`](beta_testing/BETA_TEST_PLAN.md)) Q4 directly measures this. |
| Rewarded-ad mechanic undecided | `AdManager.show_rewarded()` is still a no-op stub. Design doc lists rewarded ads as part of the business model, but no in-game reward (extra time? free retry? skip a level?) has been designed yet — needs a product decision before it can be built. |
| Banner ad placement undecided | `AdManager.show_banner()`/`hide_banner()` are still no-op stubs. No screen has been chosen for a persistent banner. |
| Ads disabled for initial launch | Interstitial + GDPR/UMP consent are fully implemented and verified on-device (see Section 5), but `ADS_ENABLED := false` in `ad_manager.gd` keeps the whole pipeline dormant — no consent request, SDK init, or ad load happens — since there's no real AdMob account yet. Flip the flag (and `is_real`, once real IDs exist) to re-enable; see the account setup steps in Section 5. |
| iOS AdMob config deferred | Blocked on the iOS build/signing pipeline (no export preset exists yet). The plugin auto-configures `Info.plist` (`GADApplicationIdentifier`, SKAdNetwork entries, App Tracking Transparency string) at export time once that pipeline exists — shouldn't need much extra work beyond adding real iOS app/ad-unit IDs to the `Admob` node. |
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
| July 26, 2026 | Content build complete: 7 new ingredients (matcha, chocolate, cream, butter, sugar, caramel, raspberry) and 24 new recipes added (19 ingredients / 34 recipes total); Levels 9–50 authored across all 5 tiers; `MAX_LEVEL_INDEX` updated to 49. Recipe set diverged from the earlier 24-recipe plan since only 6 of 14 previously-proposed recipes had matching art — redesigned around a waffle/pancake family and a Japanese-dessert family that arrived instead (see Section 4). 2x batch multiplier implemented as a data-only fake (`_x2` RecipeData resources) since no engine-level multiplier field exists. Asset swaps: strawberry_cake got new icon art, old strawberry-cake art repurposed for new raspberry_cake recipe, milk ingredient got new carton art. |
| July 27, 2026 | Developer playtest round on the 50-level build produced a full Tier 2–5 level-design rework (Levels 11–50 regenerated, now 33 recipes total after removing 4 unused `_x2` resources and adding 3 new ones). Root cause found: `recipe_pool.size()` is literally total-orders-to-win, not just variety, so the original design conflated "more orders" with "more brand-new dishes" — new levels now cap new-recipe introduction at 2/level always mixed with known recipes, and scale difficulty via duplicate-padded order counts instead. Tier 5 board reverted from 8×6 to 6×6 (developer decision); Tier 4/5 2x pools now mix old and new recipes (both as base pool and as the doubled set specifically), each `_x2` recipe got its own "×2"-badged icon. Asset fixes: milk reverted to original jug art, chocolate ingredient swapped to new developer-provided source art, off-center new dish icons (waffle family, hot chocolate) recentered, caramel/CaramelLatte icons flagged for future replacement. Also fixed stale Android package name (`com.example.sweettreat` → `com.sweettreat.app`) in this doc. |
| July 28, 2026 | Phase 5 (AdMob) partially implemented: interstitial ads wired up on Android using `godot-sdk-integrations/godot-admob` v7.0, running on Google's test ad unit IDs (no live AdMob account yet). `AdManager` converted from a script-only autoload to a scene (`ad_manager.tscn`) wrapping an `Admob` child node; `show_interstitial()` preloads ahead of time, shows only if ready, and always lets scene transitions continue even if no ad is available. Wired into both existing TODO points (Game Over → Restart, Level Complete → Next Level). Required enabling Godot's Custom Gradle Build (`export_presets.cfg`, gitignored/machine-local) since the plugin ships native AAR dependencies. Banner and rewarded ads, real AdMob IDs, GDPR/UMP consent, and iOS config all explicitly deferred — see Section 8. |
| July 28, 2026 | Expanded from 50 to 100 levels for initial launch, replacing the 5-tier structure entirely (levels 1–8 rebuilt too). New rules: exactly 1 new recipe introduced every 3rd level (2 at level 1 — `bread`+`bun` — so the opener isn't a single-dish bore), flat timer bands (90s/120s/180s per 30-level range) instead of gradual tightening, `max_simultaneous_orders` caps at 6 instead of continuing to climb, and total-orders-to-win (the real difficulty lever, per the July 27 finding) ramps linearly within each band from 3 (L1) to 36 (L100). All 33 existing recipes (28 base + 5 `_x2`) fit exactly into the introduction schedule with no new art needed; levels 94–100 are a pure-mastery finale rotating 3 K-safe pools. `MAX_LEVEL_INDEX` updated to 99. Also added a `RecipeName` label to the Recipe Frame (between the dish icon and ingredient list, preserving the original icon-to-ingredients gap on both sides of the new label) so players can see the dish name without guessing from the icon alone. |
| July 30, 2026 | Developer playtest round on the full 100-level build surfaced 3 real bugs, a level-design gap, a new gameplay constraint, and several asset issues. **Bugs fixed:** (1) newly-spawned orders after a completion had no satisfiability guarantee — the sole fallback in `_pick_next_recipe()` could hand back a fully random, unwinnable recipe with no force-placement backup, explaining both "last order missing ingredients" and repeated lv96 retries; fixed by running the same re-roll + force-placement guarantee already used elsewhere. (2) `_x2` recipes silently vanished from every level's pool after their own single introduction level (confirmed: present in `level_81.tres`, absent from `level_82`/`level_83`) because they were never registered in the cluster lookup used by non-introduction levels. (3) newly-introduced recipes could go statistically unseen in short early levels (e.g. `croissant` technically present at level 3 but with only ~1-in-4 draw odds against a 4-order total). **Level-design rework:** the generator now gives newly-introduced recipes a floor weight (~35–40% of that level's orders), keeps `_x2` recipes as persistent weighted candidates once introduced (paired with their K-safe companion sets), reaches back to any earlier-established cluster (not just the immediately-preceding one) so older recipes resurface more, and gives "cake" recipes a ~1.5x popularity weight; all 100 levels regenerated and re-validated against the K/capacity/introduction-cadence rules with zero violations. **New feature:** ingredient selection is now capped at 4 (8 if a `_x2` order is active), with a distinct red-tint shake (`reject_flash()`) when a tap is blocked, so a rejected tap reads differently from a normal one. **Board variety:** `_random_ingredient()` now has a 15% chance to draw from the full ingredient roster instead of just the current level's eligible set, reducing single-ingredient monotony on low-K boards. **UI:** card-row gap increased 150px → 190px; `choppingBoard.png`'s source content was off-center within its own canvas (6px left margin vs. 24px right margin), which combined with `KEEP_ASPECT_COVERED`'s symmetric-crop-around-canvas-center behavior to clip the board's left edge — fixed by recentering the source art, plus the board rect's inset margins were bumped ±33 → ±48 for a slightly smaller board per developer request. **Asset swaps:** `cream`, `caramel` (2nd revision, closer black-outline pixel style), and `sugar` (single-cube pixel art) ingredient icons replaced with developer-provided art; `CaramelLatte` and `HotChocolate` dish icons replaced with developer-provided art, resolving both remaining dish-icon aesthetic-mismatch flags from Section 8; `Dorayaki`/`StrawberryDaifuku`/`Purin` dish icons rescaled in place (they were never re-centered after their original small-source upscale — content fill was 25%/42%/59% vs. 65–95% for comparable dishes). |
| July 30, 2026 | On-device playtest verification of the above round (level 3/6/83/45/36 spot-checks) surfaced one more asset mistake: `MatchaLatte.png`'s icon was visually identical to `HotChocolate.png` — an earlier swap attempt had applied the wrong to-go-cup source art instead of the intended mug-with-green-foam art. Fixed using the correct `hot_matcha_latte.png` source (crop to content bbox, scale to the existing 252px content-max convention, center on the 320×320 canvas); confirmed on-device as visually distinct from both `HotChocolate` and `CaramelLatte`. |
| July 30, 2026 | Completed interstitial ad setup (skipping banner/rewarded for this launch, per developer decision): implemented the GDPR/UMP consent flow in `ad_manager.gd` (`update_consent_info()` → conditional `load_consent_form()`/`show_consent_form()` → `_start_ads()` on every completion/failure path, so consent resolution can never stall the game) using the plugin's built-in UMP support, resolving the Play Store submission blocker from Section 8. Verified on-device: outside the EEA/UK the SDK reports `gdprApplies=0`, skips the form, and loads an interstitial normally. Decided against shipping ads in the initial launch (no real AdMob account yet), so added an `ADS_ENABLED := false` flag that short-circuits the entire pipeline — confirmed via on-device logcat showing zero consent/init/ad-load activity when disabled. Documented the AdMob account + app + interstitial-ad-unit creation steps in Section 5 for when it's time to turn ads back on. |
