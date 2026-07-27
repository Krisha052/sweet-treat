# Sweet Treat — Game Design Document

*Last updated: July 27, 2026*

---

## 1. Overview

**Working Title:** Sweet Treat

**Genre:** Time-management / cooking-puzzle hybrid

**Pitch:** A cozy 2D cafe simulation where players race against the clock to fulfill dish orders, shown as image-based dish cards (tapping a card opens a Recipe Frame revealing its exact ingredient list). Players tap matching ingredients directly on a chopping-board grid to select them toward any active order; a recipe completes the moment its full ingredient list is present within the current selection, regardless of what else is also selected. There are no visible customers; the focus stays tight on ingredient logistics and recipe assembly. Progression is linear and strictly forward-only — players always resume exactly where they left off. Levels escalate via more simultaneous orders, tighter timeframes, and 2x batch multipliers on existing recipes.

**Visual Style:** 2D, cozy aesthetic, light/pastel color palette, minimal animations — sprite-based (Sprite2D/TextureRect), no 3D models anywhere in the project. *(Note: the project was originally scoped as 3D and was converted to 2D early in Phase 4. This doc reflects the current state.)* Palette confirmed for the title, gameplay, and game-over screens (see Section 4); the broader game-wide scheme is muted/earthy, anchored to the existing (fixed) asset pack colors, particularly the bakery exterior (`cafe.png`).

**Platforms:** Mobile (iOS + Android) for initial launch; Desktop (Windows/Mac) planned as a later phase. Built in Godot 4.7.

**Business Model:** Free-to-play, supported by ads (banner, interstitial, and rewarded). *(Not yet implemented — see Section 5, Phase 5 status.)*

**Target release scope:** 50 levels. *(All 50 implemented — see Section 6.)*

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

**Tier 2 — Ramping (Levels 11–22):** New recipes introduced, **at most 2 never-before-seen recipes per level, always mixed into a pool of already-known recipes** (never a new-dish-only pool). K stays ≤8. 6×6, 1x only.

**Tier 3 — Sustained Pressure (Levels 23–34):** Levels 23–27 finish introducing the last few new recipes (same ≤2-per-level, always-mixed rule). Levels 28–34 introduce no new recipes at all — they're pure "mastery" levels that escalate purely via total orders and simultaneous-order count against pools the player already knows. Full 6 simultaneous orders. K must stay ≤8. 6×6.

**Tier 4 — 2x Multiplier (Levels 35–42):** 2x requires K≤6 on 6×6 board. Pools mix old and new recipes (e.g. `bread, bun, croissant, cherry_cake, coconut_cake, raspberry_cake` — 5 old + 1 new, K=6), and the *doubled* recipes specifically are also a mix of old and new dishes (`cherry_cake_x2`, `bread_x2` alongside `raspberry_cake_x2`) rather than only-old. 6×6.

**Tier 5 — Endgame (Levels 43–50):** 6×6 board (not 8×6 — see implementation note below). 2x multiplier continues, still K≤6 (the 8×6 board's looser K≤10 headroom no longer applies), again mixing old and new base recipes and old and new doubled recipes (`bread, waffles, pancakes, berry_pancakes, cream_pancakes` base pool, K=6; `bread_x2` mixed with `waffles_x2`/`pancakes_x2`).

**Implementation status (Levels 9–50):** All 50 levels are built (`data/levels/level_09.tres`–`level_50.tres`). The design actually shipped diverges from the pool-size/K table structure above in a way that matters enough to call out explicitly — it replaced the original numeric tier tables after a developer playtest round (2026-07-27) found the original approach overwhelming:

- **Pool size ("recipe_pool" array length) is not "distinct recipe variety" — it's literally the total number of orders required to win the level** (`OrderManager._total_orders = config.recipe_pool.size()`; see `scripts/gameplay/order_manager.gd`). The original Tier 2–5 tables conflated these two things: escalating "pool size" always meant both *more orders to complete* and *more brand-new dishes at once*, which is what made early Tier 2/3 levels (e.g. the original Level 11, Level 15) feel overwhelming — 5-6 simultaneous orders where every single recipe was one the player had never seen.
- **The fix:** total-orders-to-win now scales via **duplicate entries** of already-known recipes in the pool array (e.g. `[espresso, espresso, espresso, caramel_latte, hot_chocolate]` — 5 total orders, but only 3 *distinct* recipes, 2 of them new). Distinct-recipe-count (and therefore K) grows slowly and separately, capped at 2 newly-introduced recipes per level, always mixed with recipes the player already knows. Levels 28–34 and the back half of Tiers 4–5 introduce zero new recipes and scale difficulty purely through order count and simultaneous-order count against known pools.
- **Tier 5's board reverted to 6×6.** The original plan used an 8×6 (48-slot) board specifically to afford K up to 10–12 for 2x pools. Per-level board-size variation was cut as a design decision (not a technical limitation — `board_cols`/`board_rows` per `LevelConfig` still works) — Tier 5 now uses the same K≤6 2x-safe ceiling as Tier 4, just with a different mixed old+new recipe pool for variety.
- **The 2x batch multiplier still has no engine support** (unchanged from the original build — see below) — it's faked via separate `_x2` `RecipeData` resources with doubled ingredient counts. What's new: each `_x2` recipe now has **its own icon** (base dish art with a composited "×2" badge, e.g. `CherryCakeX2.png`) instead of reusing the base recipe's icon, so a doubled order is visually distinguishable on the dish card without opening the Recipe Frame. Current `_x2` set: `bread_x2`, `cherry_cake_x2`, `raspberry_cake_x2`, `waffles_x2`, `pancakes_x2` (2 old, 1 new, 2 new — deliberately mixed per the Tier 4/5 pool rule above).

**Win/Lose Condition:** Pass/fail only — no star ratings. Won = all orders complete before timer. Lost = timer runs out.

**Level Complete flow:** Background shifts `#544541` → `#8a8f13` for 3s → interstitial ad → Next Level Frame → tap "Next Level" → next level (or Game Complete screen if on the last level).

**Retry flow:** Game Over Frame (3s, auto-timed) → interstitial ad → Restart Game Frame → tap "Restart Game" → same level, free retry, no cooldown.

---

## 4. Content

### Current Content (implemented)

**Ingredients (19):** cherry, coconut, bean_dark_roast, egg, flour, foam, bean_light_roast, milk, bean_medium_roast, bean_raw, red_tea, strawberry, **matcha, chocolate, cream, butter, sugar, caramel, raspberry**

`milk`'s sprite was briefly swapped to new carton art, then **reverted back to the original jug art** after a developer playtest — the jug matched the rest of the game's aesthetic better. `chocolate`'s sprite was swapped a second time to different source art (developer-provided) after the first version didn't read clearly. `caramel`'s sprite (and the `CaramelLatte` dish icon) is flagged by the developer as an aesthetic mismatch pending replacement art — not yet fixed, see Section 8.

**Recipes (33):** bread, bun, cappuccino, cherry_cake, coconut_cake, coffee_cake, croissant, espresso, latte, strawberry_cake (icon replaced with new art), **raspberry_cake, caramel_latte, hot_chocolate, matcha_latte, honey_tea, chocolate_cake, sugar_cake, waffles, berry_waffles, chocolate_waffles, strawberry_waffles, pancakes, berry_pancakes, chocolate_pancakes, cream_pancakes, dorayaki, purin, strawberry_daifuku, bread_x2, cherry_cake_x2, raspberry_cake_x2, waffles_x2, pancakes_x2**

### Content build history

An earlier round of this doc proposed 6 new ingredients (Matcha, Chocolate, Cream, Butter, Sugar, Caramel) and 14 new recipes, pending art sourcing. When art actually arrived (`assets/textures/new ingredients/`, `assets/textures/new dishes/`), it diverged from that plan in two ways worth recording:

- **A 7th ingredient (Raspberry) arrived**, needed for a Raspberry Cake recipe (repurposing the original strawberry_cake dish icon after strawberry_cake got new art — see asset swap note below).
- **Only 6 of the 14 planned recipes had matching art** (Caramel Latte, Chocolate Cake, Honey Tea, Hot Chocolate, Matcha Latte, Sugar Cake). The other 8 (Matcha Cake, Caramel Cake, Strawberry Cream, Cherry Cream, Coconut Cream, Cream Puff, Butter Biscuit, Chocolate Croissant) have no art and were dropped. In their place, **12 new dish images arrived that weren't in the original plan at all** — a waffle/pancake family (Waffles, Berry/Chocolate/Strawberry Waffles, Pancakes, Berry/Chocolate/Cream Pancakes) and a Japanese-dessert family (Dorayaki, Purin, Strawberry Daifuku) — so the recipe set was redesigned around the art that actually exists rather than the original 14.

**Recipe pools (thematic clusters, referenced by Section 3's tier tables):**

| Pool | Recipes | K (distinct ingredient types) | Tier usage |
|---|---|---|---|
| Classic Bakery | bread, bun, croissant, cherry_cake, coconut_cake, coffee_cake, strawberry_cake | 7 (flour, milk, egg, cherry, coconut, bean_medium_roast, strawberry) | Tier 1 (unchanged) |
| Café/Coffee | cappuccino, espresso, latte | 7 (bean_light/medium/dark/raw, milk, foam, red_tea) | Tier 1, Tier 2 intro levels (paired 1:1 with new drinks) |
| Fruit Cakes | strawberry_cake, raspberry_cake | 4 (+raspberry) | Tier 1 (L9–10) — cheapest possible new-ingredient intro |
| Specialty Drinks | caramel_latte, hot_chocolate, matcha_latte, honey_tea | 8 total across the whole cluster, but never mixed together in one pool — introduced 2-at-a-time paired with one old café recipe (K=7–8 per pairing) | Tier 2 (L11–14) |
| Cakes/Confections | chocolate_cake, sugar_cake | introduced 2-at-a-time paired with croissant (K=6) | Tier 2 (L15–16), Tier 3 mastery pool (L31–34, joined by dorayaki/purin/strawberry_daifuku/strawberry_cake, K=8) |
| Waffles & Pancakes | waffles, berry_waffles, chocolate_waffles, strawberry_waffles, pancakes, berry_pancakes, chocolate_pancakes, cream_pancakes | 8 (flour, egg, milk, butter, raspberry, chocolate, strawberry, cream) | Tier 2–3 mastery pool (Levels 28–30) — the best-fitting pool for "6+ recipes at K≤8" |
| Japanese Treats | dorayaki, purin, strawberry_daifuku | 7 (flour, egg, milk, chocolate, sugar, caramel, strawberry) | Tier 2–3 |
| Tier 4 mixed (old+new base) | bread, bun, croissant, cherry_cake, coconut_cake, raspberry_cake | 6 (flour, milk, egg, cherry, coconut, raspberry) | Tier 4 (L35–42), with `cherry_cake_x2`/`bread_x2`/`raspberry_cake_x2` mixed in as the doubled set |
| Tier 5 mixed (old+new base) | bread, waffles, pancakes, berry_pancakes, cream_pancakes | 6 (flour, milk, egg, butter, raspberry, cream) | Tier 5 (L43–50), with `bread_x2`/`waffles_x2`/`pancakes_x2` mixed in as the doubled set |

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
| 4c — Variable board size architecture (per-level `board_cols`/`board_rows`) | ✅ Done (endgame Tier 5 levels now use it, see Phase 6) |
| 5 — AdMob integration | ⬜ Not started |
| 6 — Content build (Levels 9–50, new recipes/ingredients) | ✅ Done (19 ingredients, 33 recipes, 50 levels; see Section 4). 2x multiplier is a data-only fake, not a real engine feature — see Section 3 implementation note. Levels 11–50 reworked 2026-07-27 after developer playtest (see Document History). |

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
| Caramel icon aesthetic mismatch | `caramel.png` and `CaramelLatte.png` flagged by the developer as not matching the rest of the game's art style. No replacement art provided yet — open item, not a code/data problem. |
| flour/egg remain the dominant ingredients across all 33 recipes (69.7%/63.6%) | The art that arrived for the Levels 9–50 content build skewed toward waffle/pancake/bakery dishes rather than the cream-based confections an earlier version of this doc planned around, so flour/egg concentration didn't drop the way that plan intended. Not a violation of any per-level K constraint (every level 9–50 is individually validated — see Section 3), but worth knowing when curating future pools: flour/egg supply is the first thing to check. |
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
| July 26, 2026 | Content build complete: 7 new ingredients (matcha, chocolate, cream, butter, sugar, caramel, raspberry) and 24 new recipes added (19 ingredients / 34 recipes total); Levels 9–50 authored across all 5 tiers; `MAX_LEVEL_INDEX` updated to 49. Recipe set diverged from the earlier 24-recipe plan since only 6 of 14 previously-proposed recipes had matching art — redesigned around a waffle/pancake family and a Japanese-dessert family that arrived instead (see Section 4). 2x batch multiplier implemented as a data-only fake (`_x2` RecipeData resources) since no engine-level multiplier field exists. Asset swaps: strawberry_cake got new icon art, old strawberry-cake art repurposed for new raspberry_cake recipe, milk ingredient got new carton art. |
| July 27, 2026 | Developer playtest round on the 50-level build produced a full Tier 2–5 level-design rework (Levels 11–50 regenerated, now 33 recipes total after removing 4 unused `_x2` resources and adding 3 new ones). Root cause found: `recipe_pool.size()` is literally total-orders-to-win, not just variety, so the original design conflated "more orders" with "more brand-new dishes" — new levels now cap new-recipe introduction at 2/level always mixed with known recipes, and scale difficulty via duplicate-padded order counts instead. Tier 5 board reverted from 8×6 to 6×6 (developer decision); Tier 4/5 2x pools now mix old and new recipes (both as base pool and as the doubled set specifically), each `_x2` recipe got its own "×2"-badged icon. Asset fixes: milk reverted to original jug art, chocolate ingredient swapped to new developer-provided source art, off-center new dish icons (waffle family, hot chocolate) recentered, caramel/CaramelLatte icons flagged for future replacement. |
