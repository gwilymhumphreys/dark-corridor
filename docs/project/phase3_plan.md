# Dark Corridor — Phase 3 Build Plan (the run loop)

> **A build plan, not a spec.** The systems are specced in their PRDs
> ([save](save_prd.md) · [game_manager](game_manager_prd.md) ·
> [run_manager](run_manager_prd.md) · [encounter](encounter_prd.md) ·
> [draft](draft_prd.md) · [content](content_prd.md)); this is the ordered,
> test-first path. Sits under [decision-log.md](decision-log.md) → *Build order*
> step 2.3, on top of the Phase 1 combat spine + Phase 2 autotest.

**Engine:** Godot 4.6.
**Date:** 2026-06-05.
**Status: BUILT (2026-06-05).** All seven steps green — Save · Relic · Draft ·
Encounter · Run · Game + the autotest run extension. The autotest drives the
whole descent headless to a win, deterministically by seed, with quit/resume.
Next: Phase 4 (real UI / the run screen).

---

## Goal

A short, deterministic, **headless-drivable** run: **draft → fight → advance × N →
win**, with **quit/resume**. `Game → Run → Encounter → Combat` wired end to end;
**one relic** proves the run-state→combat content seam (relic-only this pass —
enchant + consumable are a tagged fast-follow). Verified by the **extended
autotest** (the Driver now picks drafts) + GUT units.

## Why this shape

Phase 1 built the fight, Phase 2 proved we can drive one headlessly. Phase 3 is the
product loop the design's prototype calls for — "one corridor segment, draft, repeat
× N; watch whether the cascade is satisfying." It's the first build where a *run*
exists to be saved, resumed, and balanced.

## Discipline (unchanged)

Combat/run logic is `RefCounted`; only the orchestrators (`Run` / `Encounter` /
`Combat`) are `Node`s; **only `CombatManager` runs `_physics_process`**. Each step
goes green headless before the next. Commit each green step; no self-attribution.

## The driving seam (how a run runs without a UI)

The `Run manager` advances by explicit **call + signal**, never `_process`. A fight
beat creates a `CombatManager` whose **clock is supplied externally** — the autotest
steps `sim_step()` (later the run screen's `_physics_process`). When the CM emits
`resolved`, the `Run manager` fulfils the reward (draft → a *pending offer*; relic
grant; none) and checks run-end. A **draft pick is an intent** the driver supplies
(`Driver.choose_draft → run.apply_draft_pick`). Rest beats resolve immediately
(heal). This is the **same intent seam the UI emits later** — the autotest is just
the first client of it.

## Build order

### Step 1 — Save (foundation)

`SaveAutoload` (registered `Save`): build / read / clear a **JSON** run snapshot,
written **atomically** (temp → rename) to `user://`. RNG `seed` + `state` stored as
**strings** (a JSON double can't hold a 64-bit RNG state exactly). **No migration**
— absent / unreadable / version-incompatible → `null` → fresh run.

- **Files:** `src/autoloads/save.gd`.
- **Tests:** snapshot round-trips (write → read equal); `clear()` removes it;
  corrupt / absent → `null`; a stored 64-bit RNG state survives exactly.

### Step 2 — Content: Relic (minimal)

`RelicDef` + `RelicCatalog` — one relic, a **combat-start status applier** (the
simplest shape: start each fight with N block). A `Relic` instance carries its def.

- **Files:** `src/content/relic_def.gd` + `relic_catalog.gd`, `src/content/relic.gd`.
- **Tests:** catalog builds lazily; the def carries `(status_type, count)`.

### Step 3 — Draft (the draw)

`DraftAutoload` (registered `Draft`): `draw(pool, depth, rng) → 3` item candidates,
**seeded from the run RNG**, minimal depth-weighting. A small draft **pool** (item
ids).

- **Files:** `src/autoloads/draft.gd`, the pool in `src/content/` (a const list).
- **Tests:** same RNG state ⇒ same offer (no save-scum); returns 3 distinct-ish
  candidates; advancing the RNG changes the offer.

### Step 4 — Encounter (the beat)

`EncounterDef` + `EncounterCatalog` (a few fights + one rest). `Encounter` (Node):
a **fight** spawns enemy `Actor`s from `EnemyCatalog` in left-to-right order and, on
`begin()`, creates the `CombatManager` and relays its `resolved` + a **reward-kind**;
a **rest** applies a partial heal on `begin()` and resolves immediately.

- **Files:** `src/content/encounter_def.gd` + `encounter_catalog.gd`,
  `src/run/encounter.gd`.
- **Tests:** a fight resolves when its CM is stepped to a verdict; a rest heals; the
  reward-kind (draft / none) is reported.

### Step 5 — Run manager (the descent)

`RunManager` (Node): a small **linear map** (a list of `EncounterDef` ids), the
**run-state** `{ actor, relics, potions, position, rng }`, the **sequencing cycle**
(enter beat → save → begin/resolve → fulfil reward → advance), **HP-economy** (rest
heal; HP persists between beats), **relic combat-start application** at fight begin,
**snapshot build / rehydrate**, and a `run_ended(outcome)` signal.

- **Files:** `src/run/run_manager.gd`.
- **Tests:** a full short run reaches **won**; a fight loss → **died**; a drafted
  item lands on the board; **save mid-run + rehydrate** reproduces the same
  continuation (deterministic resume).

### Step 6 — Game manager (session)

`GameManagerAutoload` (registered `Game`): the **phase machine**
Boot → Title → Run → (Death | Win); `start_run(seed)` / `resume_run()` /
`end_run(outcome)`; `Save.read()` on launch, `Save.clear()` on death/win;
create / hold / tear down the `RunManager`; receive `run_ended`. Added to
`TestCleanup.reset_all_managers()`.

- **Files:** `src/autoloads/game_manager.gd`.
- **Tests:** start → run → death **clears** the save; **resume** rebuilds a run from
  a snapshot and continues.

### Step 7 — Autotest: drive a run

`AutoTestMode.run_full()`: `Game.start_run(seed)` then the headless run loop (step
each fight's CM with the per-step damage observation, `Driver.choose_draft` on
offers, `advance`). New flags: **`--encounters N`** (cap), **`--single-fight`** (keep
the Phase-2 path). **`--seed` is now live** (seeds the run RNG). Logger gains
encounter / draft / run-end events + a **run summary** (beats cleared, outcome, final
HP, damage-by-family across the run). A **resume smoke** (save mid-run, reload,
finish). Exit `0` = the run ended cleanly (won or died), `1` = stuck / timeout.

- **Files:** extend `src/autotest/auto_test_mode.gd`, `auto_test_driver.gd`,
  `auto_test_logger.gd`.
- **Tests:** `run_full` reaches a verdict deterministically; `--seed` determinism;
  a resume reproduces the continuation.

---

## Interfaces to lock at the start (so steps don't drift)

```
Save:        write(snapshot:Dictionary)->void · read()->Dictionary (empty = none) · clear()->void
Draft:       draw(pool:Array, depth:int, rng:RandomNumberGenerator)->Array  # 3 Draftable defs
Encounter:   is_fight()->bool · begin()->void · combat_manager()->CombatManager ·
             signal resolved(outcome:int, reward_kind:int)
RunManager:  start()->void · current_encounter()->Encounter · combat_manager()->CombatManager ·
             begin_current()->void · has_pending_draft()->bool · pending_draft()->Array ·
             apply_draft_pick(i:int)->void · advance()->void · is_ended()->bool ·
             snapshot()->Dictionary · rehydrate(s:Dictionary)->void · signal run_ended(outcome:int)
Game:        start_run(seed:int)->void · resume_run()->bool · end_run(outcome:int)->void ·
             phase:int · run:RunManager · signal phase_changed(phase:int)
```

## Phase-3 micro-decisions (pre-flagged)

- **Save format = JSON**, RNG `seed`/`state` as strings (64-bit exactness); atomic
  temp→rename; `user://`. Format may change freely (no migration — `CLAUDE.md`).
- **Map** = a fixed short list of beats (fights + one rest), the final beat's win →
  `run_ended(won)`. Counts are tuning, not design.
- **Relic statuses** are re-applied each fight start (combat-scoped; `teardown`
  clears them) — run-persistent actor statuses don't exist yet (relic-only scope).
- **Player side = a party (roster of 1)** — keep run-state list-friendly (#22); don't
  hardwire one actor.

## Explicitly NOT in Phase 3

Enchant + consumable (tagged fast-follow); the ~30-encounter pool, elite/boss tiers,
events-with-prose, the 1D-map + draft UIs, multi-act HP tuning, meta / characters.
Real UI is Phase 4.
