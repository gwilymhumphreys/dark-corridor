# Plan — Draft Skip → Bank Gold

> **Status: planned, not built (2026-07-08).** Owner chose "Skip + bank gold." Adds a **skip option to
> every item-reward draft**: instead of taking one of the three items, the player banks a small random
> amount of **gold** (40–60). Reverses the no-skip invariant (decision #17) and introduces **gold** as a
> run-state resource. Plans aren't catalogued in the index (transient); this graduates to notes in the
> affected `systems/` docs on ship.

## Why

A slow-weapon synergy build (the Armourer's big-slow-attacks archetype — [`../design/armourer.md`](../design/armourer.md))
shouldn't be *forced* to take a fast weapon that wrecks its synergy. The 1-of-3 draft is currently no-skip
(taking one is always correct). The skip is the escape hatch; gold is a small consolation so skipping isn't
pure feel-bad, and it's the first **source** of a future gold economy.

## Design decisions (owner-approved scope)

1. **Skip is an option on EVERY draft, not a new reward kind.** Do **NOT** add an `EncounterDef.Reward`
   variant. `apply_draft_skip()` is a sibling of `apply_draft_pick()` that resolves the *pending offer*.
   The elite reward (relic + draft) is unaffected — its relic is still granted; only the draft portion is
   skippable.
2. **Gold is banked in run-state, seeded from the run RNG.** `gold += rng.randi_range(40, 60)` — the same
   run RNG that seeds drafts (#20), so resume is deterministic and not save-scummable. A pick draws no RNG;
   a skip draws one — a legitimate player decision that diverges the future (fine, like any choice).
3. **No sink yet.** Gold accumulates and displays; there is **nothing to spend it on** until shops exist.
   That's accepted — this ships the *source* + the plumbing, not the economy. **Explicitly out of scope:**
   shops, any gold spending, gold-generator items, gold as a per-fight resource.
4. **Determinism preserved for the autotest.** The driver defaults to **never skip**, so every existing
   headless run draws the RNG identically → byte-identical baselines. Skip is opt-in per strategy/test.
5. **Player-facing copy is placeholder English** (owner's to finalize): button `'Skip for gold'`, HUD
   `'Gold: {0}'`. Localizable; run the POT pipeline after.

## Touchpoints (all paths verified 2026-07-08)

### Engine — `src/run/run_manager.gd`
- **New field:** `var gold: int = 0` (alongside `position`, ~line 46). Initialize in `start()` (~line 83).
- **New method `apply_draft_skip()`** (sibling of `apply_draft_pick`, ~line 241):
  ```gdscript
  ## Skip the pending draft: bank a small random amount of gold instead of taking an item, then clear
  ## the offer. The escape hatch from an anti-synergy draft (docs decision #33 — reverses #17's no-skip).
  func apply_draft_skip() -> void:
    if _pending_offer.is_empty():
      return
    gold += rng.randi_range(GOLD_SKIP_MIN, GOLD_SKIP_MAX)   # 40..60, run RNG (seeded, resume-stable)
    _pending_offer = []
  ```
  Add `const GOLD_SKIP_MIN := 40` / `const GOLD_SKIP_MAX := 60` (or route to `Balance` — check where the
  other draft/run tunables live and match that home).
- **`apply_draft_pick()`** — **no change** (already clears the offer correctly).
- **`advance()` no-skip guard (~line 324)** — **no change.** The invariant is "an offer must be *consumed*
  before advancing"; skip is a new way to consume it, so the guard still holds. (Update only its comment if
  it says "a pick always resolves.")
- **`snapshot()` (~line 449):** add `'gold': gold,` to the returned dict.
- **`rehydrate()` (~line 502):** add `gold = int(snap.get('gold', 0))` (absent → 0; forward-compatible).
- **`SNAPSHOT_KEYS` (~line 467):** do **NOT** add `'gold'` — it's optional via `.get(...)`; requiring it
  would reject pre-gold snapshots.

### UI — draft overlay + run screen + HUD
- **`src/scenes/screens/draft_overlay.gd`:** add `signal skipped()`; add a **Skip button** child in
  `draft_overlay.tscn` (placeholder text `'Skip for gold'`, theme-styled, add a `UIJuice` node per
  CLAUDE.md) wired to emit `skipped`.
- **`src/scenes/screens/run_screen.gd`** (`_show_draft`, ~line 322): connect
  `_draft.skipped.connect(_on_draft_skipped)`; add `_on_draft_skipped()` mirroring `_on_draft_picked` but
  calling `_run.apply_draft_skip()` then `_advance()` (and refresh the gold HUD).
- **HUD gold counter:** add a minimal localizable gold readout (`'Gold: {0}'.format([...])`) to the run
  HUD (sibling of `MapStrip` / `StatsReadout` in `run_screen.tscn`). Placeholder placement — owner can
  relocate/juice later. Update it on skip and on rehydrate.

### Autotest — `src/autotest/`
- **`auto_test_driver.gd`:** add `func should_skip_draft(_candidates: Array, _board: Array = []) -> bool:
  return false` (default never skip). Update the `choose_draft` docstring (drop "No skip exists").
- **`auto_test_mode.gd`** (the draft branch, ~line 201): check `driver.should_skip_draft(...)` first →
  `run.apply_draft_skip()` + log a `{ 'action': 'skip' }` event; else the existing pick path.

## Tests (`tests/`)
- `tests/run/test_run_manager.gd`:
  - **Add** `test_skip_banks_gold_and_clears_offer` — after a win, `apply_draft_skip()` sets gold in
    [40, 60], clears the offer, board unchanged, run advances.
  - **Add** `test_gold_survives_save_and_resume` — skip → snapshot → rehydrate restores the exact gold.
  - **Add** `test_skip_is_deterministic_for_a_seed` — same seed + same skip → same gold.
  - **Keep** `test_advance_past_an_unconsumed_draft_drops_the_offer` (unchanged — the guard still applies).
- `tests/autotest/`: a test that `should_skip_draft` defaults false, and a full run that skips still
  resolves (exit 0) — or assert the default keeps a known run's gold at 0.

## Docs (update in the same change)
- `docs/decision_log.md`: **new decision #33** — "Draft skip → bank gold; reverses #17's no-skip; gold
  introduced as run-state (source built, **no sink yet**)." Annotate #17's "No skip" line to point to #33.
- `docs/systems/draft.md`: revise the "No skip" section → skip-for-gold.
- `docs/systems/run_manager.md`: gold in run-state + the skip flow.
- `docs/systems/save.md`: `gold: int` in the snapshot schema (optional, defaults 0).
- `docs/systems/run_screen.md` + `docs/systems/ui_layout.md`: the skip button + gold HUD + the skip intent.
- `docs/systems/autotest.md`: `should_skip_draft` (default false).
- `docs/design/character_ideas.md`: the **Gold** resource row — "source built (draft skip), sink TBD."
- `docs/design/game_design.md`: gold as a nascent resource + skip-for-gold (brief).

## After authoring
- No new `class_name` → no `--import` needed for tests. Run the **GUT suite** (must stay green) and the
  **headless autotest** (`--seed 1`, must exit 0). Run the **POT pipeline** for the two new strings, then
  re-import locale.

## Out of scope (do not build)
Shops / any gold sink / gold spending / gold-generator items / a per-fight gold resource. Gold only
accumulates for now.
