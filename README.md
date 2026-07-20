# 🍰 Sweet Treat

A cozy 2D cafe simulation built in **Godot 4.7**. Race the clock, tap ingredients on a chopping-board grid, and assemble recipes to fulfill dish orders — no visible customers, just tight ingredient logistics and satisfying recipe assembly.

![Godot](https://img.shields.io/badge/Godot-4.7-478cbf?logo=godotengine&logoColor=white)
![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20Android-lightgrey)
![Status](https://img.shields.io/badge/status-in%20development-yellow)

---

## Gameplay

- Dish orders appear as image-based **dish cards**; tapping one opens a **Recipe Frame** revealing its exact ingredient list.
- Tap matching ingredients directly on the chopping board to add them to a shared selection pool.
- An order completes the instant its full ingredient list is present in the current selection — extra selected ingredients don't block it, and multiple orders can chain-complete off one tap.
- Boards auto-refill and are guaranteed satisfiable (with a force-placement fallback if a re-roll can't find a valid layout).
- Progression is linear and forward-only — levels escalate through more simultaneous orders, tighter timers, larger recipe pools, and 2x batch multipliers.

## Current status

| | |
|---|---|
| Levels implemented | 8 (of a planned 50) |
| Recipes | 10 |
| Ingredients | 12 |
| Ads (AdMob) | Not yet integrated |

See [`docs/Sweet_Treat_Design_Doc.md`](docs/Sweet_Treat_Design_Doc.md) for the full design doc, level-tier breakdown, and implementation status.

## Beta testing

The 8-level build is going through a beta test with community testers before further content work. Process and results: [`docs/beta_testing/BETA_TEST_PLAN.md`](docs/beta_testing/BETA_TEST_PLAN.md) · [`docs/beta_testing/BETA_RESULTS.md`](docs/beta_testing/BETA_RESULTS.md).

## Getting started

1. Install [Godot 4.7](https://godotengine.org/download) (or `brew install --cask godot` on macOS).
2. Clone the repo and open `project.godot` in the Godot editor.
3. Press **Play** to run the default scene.

```bash
git clone https://github.com/Krisha052/sweet-treat.git
```

### Debug reset (debug builds only)

`Ctrl+Shift+R` in any scene wipes save progress and returns to the title screen. No-op in release builds.

## Project structure

```
assets/textures/ingredients/   ingredient sprites
assets/textures/dishes/        dish icons for Recipe cards
assets/textures/backgrounds/   cafe, chopping board, recipe card art
assets/textures/buttons/       UI button art
assets/fonts/                  Quaver (project UI font)
autoload/                      GameManager, SaveManager, AdManager
scripts/gameplay/               core loop: ingredient, level controller, order logic
scripts/ui/                     menus, HUD, recipe frame
data/ingredients/, data/recipes/, data/levels/   .tres resource data
scenes/                         Godot scenes
docs/                           design doc
```

## Tech

- **Engine:** Godot 4.7 (GDScript)
- **Target platforms:** iOS + Android (mobile-first); desktop planned later
- **Monetization:** AdMob (banner/interstitial/rewarded) — planned, not yet wired up

## License

No license specified yet — all rights reserved by default.
