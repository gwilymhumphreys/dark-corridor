# Dark Corridor — Handoff (for a fresh agent)

> **Start here if you're picking up the work.** This is the orientation: what the
> game is, what's built, how to work, what's settled, and what's next. It points to
> the canonical docs rather than duplicating them — read this, then the linked docs.
>
> **Last updated:** 2026-06-06 — end of **Phase 4 (real UI / the run screen)**.
> 126 GUT tests green on Godot 4.6; the run is now watchable end-to-end.

---

## What the game is

**Dark Corridor** — a draft-heavy auto-combat dungeon descent (Slay-the-Spire ×
Bazaar lineage). You descend a single linear corridor of beats; each fight auto-
resolves on a fixed-step clock while you draft items between fights to build a
synergistic board. The prototype target is a **playable itch.io build**.

Whole-game pitch + core loop: [`design.md`](design.md). The system map + the
**Interface contracts (boundary hub)** every PRD links to: [`architecture.md`](architecture.md).

## Read in this order

1. **[`CLAUDE.md`](../../CLAUDE.md)** (repo root, auto-loaded) — code standards
   (single quotes, static typing, 2-space indent, `snake_case` filenames,
   `class_name` PascalCase, autoloads `<Name>Autoload` registered `<Name>`, **no
   self-attribution in git messages**). These OVERRIDE defaults.
2. **[`decision-log.md`](decision-log.md)** — the canonical record: every decision
   (numbered #1–#26), the build status, and the next steps. **Read the "Build
   status" + "Next steps" first.**
3. **[`architecture.md`](architecture.md)** — system map, the combat spine, the
   **Scene tree & node model**, and the boundary hub.
4. The **phase plans**: [`phase1_plan.md`](phase1_plan.md) (combat spine),
   [`phase3_plan.md`](phase3_plan.md) (run loop). Both BUILT.
5. The per-system **PRDs** as needed (each system has one in `docs/project/`).
6. **[`../testing/autotest.md`](../testing/autotest.md)** — the headless harness you'll
   use to drive + test everything.

## Where things stand (what's built)

**Phases 1–4 are complete, committed, 126 GUT tests green, feel gate passed.** See
`git log` (each step is its own green commit).

- **Phase 1 — combat spine** (`src/combat/`): `Ticker` · `Timekeeper` (fixed-step
  clock) · `Actor` · `Item` (+ fire pipeline) · `Delivery`/`Payload` · `EventBus` ·
  `CombatManager` (the one tick) + `StatusManager` autoload. Minimal **opaque** VFX
  wall (`src/vfx/`) + a watchable host `src/scenes/combat_sandbox.tscn`.
- **Phase 2 — autotest harness** (`src/autotest/`): `AutoTestMode` (+ scene
  `autotest.tscn`) · stub `AutoTestDriver` · `AutoTestStuckDetector` ·
  `AutoTestLogger`. Drives fights headless + deterministic.
- **Phase 3 — the run loop**: `Save` · `Game` · `RunManager` (`src/run/`) ·
  `Encounter` (`src/run/`) · `Draft`, content catalogs in `src/content/` (GDScript
  defs, decision #23). The autotest's `run_full` drives a **whole descent** (draft
  → fight → advance → win) headless, deterministic by `--seed`, with quit/resume.
- **Content** (`src/content/`): all three categories — **Relic** (Stone Ward,
  combat-start block), **Enchant** (Whetstone, scale-a-value, saved on the board),
  **Consumable** (Healing Draught, thrown self-heal). Each proves its path end-to-end.
- **Phase 4 — real UI / the run screen** (`src/scenes/main.tscn` + `main_controller.gd`,
  `src/scenes/screens/`, `src/scenes/combat/`): the watchable run — title → **framed
  run** (corridor + thorn-demon occupant top-right, player left, boards/HP/potions, the
  VFX wall) → **approach** (the enemy scales from depth) → fight (slow-mo-on-hover) →
  **draft overlay** → advance along a **map strip** → win/death screens. The run screen
  drives `CombatManager.tick` each frame; the logic tree stays out of the scene tree
  (the autotest path is unchanged). Full doc: [`../ui/run_screen.md`](../ui/run_screen.md).

**What does NOT exist yet:** the ~30-encounter pool, elite/boss tiers, events with
prose, multi-act maps, meta-progression, characters, the `tune` skill. Two
written-but-unwired Phase-4 gaps (not bugs): the **potion-throw UI** (the player can't
throw the Healing Draught yet) and the **localization POT pipeline**
(`tools/extract_pot.gd`, `locale/` — strings are written extractable, but the tooling
CLAUDE.md references isn't set up).

## The architecture in one picture

Lifetime tiers: **`Game` (session) → `Run` (descent) → `Encounter` (beat) → `Combat`
(fight)**. Combat/run logic is plain `RefCounted`; only the three orchestrators
(`RunManager` / `Encounter` / `CombatManager`) are `Node`s, and **only
`CombatManager` runs `_physics_process`** (the one fixed-step tick).

**Autoloads (6, in `project.godot`):** `SfxManager`, `MusicManager`, `StatusManager`
(stateless rules), `Save` (JSON snapshot service), `Draft` (stateless reward draw),
`Game` (session singleton — phase machine + run lifecycle).

**The driving seam — important.** In Phase 3 the run-logic Nodes are kept **out of
the scene tree** and driven by explicit calls: the autotest steps
`CombatManager.sim_step()` directly (no `_physics_process`, no real time → bit-
reproducible), supplies draft picks via the Driver, and calls `run.advance()`. This
is the **same intent seam the UI will drive** — Phase 4 mounts the tree and turns on
real-time play. The harness is currently the only client of the run.

## How to work (the rhythm)

- **Godot exe:** `C:\projects\godot\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe`
- **Run the GUT suite:**
  `<exe> --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gexit`
- **GOTCHA:** after adding any new `class_name` script, run
  `<exe> --headless --path . --import --exit` FIRST or GUT won't see the new global.
- **Drive a whole run headless** (the product loop):
  `<exe> --headless --path . res://src/autotest/autotest.tscn -- --autotest --seed 1`
  → prints a summary, writes a log + markdown report to `autotest_results/`
  (git-ignored), exit `0` = resolved / `1` = stuck-or-timeout. `--single-fight` runs
  one fight; `--encounters N` caps; flags in [`autotest.md`](../testing/autotest.md).
- **Watch combat visually** (the only watchable thing pre-Phase-4 — a fixed sandbox
  fight, not the run): `<exe> --path . res://src/scenes/combat_sandbox.tscn`
  (hover an item to slow-mo, R to restart; `--shot` screenshots).
- **Discipline:** test-first; drive logic via `sim_step()` / intents in GUT (no
  `_physics_process` in tests). **Each step green headless before the next. Commit
  each green step; NO self-attribution / Co-Authored-By** (CLAUDE.md overrides).
- **Docs:** if you change behaviour a doc describes, update that doc in the same
  change. Docs describe *systems/intent, not numbers* — point to `Balance`
  (`src/data/balance.gd`) / catalogs for tunables.

## Settled decisions & lessons (don't re-litigate)

- **Statuses are combat-scoped (decision #26).** Created in a fight, cleared at
  teardown, **never saved**. Run persistence is **Relics / Enchantments** (a relic
  may carry a counter and re-apply a fresh combat-scoped status each fight — Stone
  Ward does this). The run snapshot never serializes status instances. Statuses live
  *on* their targets (`Actor.statuses` / `Item.statuses`) only to keep
  `StatusManager` stateless + `Actor.take_damage` self-contained — not for persistence.
- **`Actor` ↔ `Item` is a RefCounted cycle** (`board` ↔ `owner`). Broken with
  **`Actor.dissolve()`** at discard: enemies in `CombatManager.teardown()`, the
  player in `RunManager.teardown()` (run end only — its board persists between
  fights). Teardowns are idempotent. Verified by weakref leak tests.
- **Fixed timestep + one dial** (decision #9): the `Timekeeper` is the combat clock;
  the `CombatManager` advances every component each `sim_step`. `--speed`/the dial is
  steps-per-real-second; the headless loop ignores it (steps directly).
- **Triggers are accrual-only / loop-proof** (the Bazaar lesson, decision #12): an
  event pushes a Ticker; it fires on the *next* step — one link per step.
- **Within-step order is deterministic** (decision #24, realized as fixed
  type-ordered passes: item cooldowns → statuses (actor + item) → Delivery travel).
- **Save = JSON, atomic, no migration** (decision #11): RNG `seed`/`state` stored as
  **strings** (JSON doubles can't hold a 64-bit value). Absent/corrupt/old → `{}` →
  fresh run.
- **Content = GDScript def objects + static catalogs** (decision #23), keyed by int
  id; localized via `tr(def.name_key)`.
- **Exit codes** (autotest): `0` = the sim reached a clean conclusion (win OR die OR
  cap), `1` = it didn't (stuck / timeout) — not who wins (that's `tune`'s job later).
- **VFX = opaque placeholders only** (no alpha — ask before adding opacity; user
  preference + CLAUDE.md).
- **Benign at-exit noise:** "N resources still in use" / "ObjectDB leaked" =
  the static catalog `_defs` caches + GDScript Script resources, NOT a game leak
  (the real Actor/Item leak was fixed — see `Actor.dissolve()`).

A project memory also banks the status-lifetime + cycle gotchas (auto-surfaced).

## Your task: Phase 5 — scale content + `tune`

Phase 4 is built — the run is watchable end-to-end ([`phase4_plan.md`](phase4_plan.md)
· [`../ui/run_screen.md`](../ui/run_screen.md)). The design's next step (decision-log
*Next steps* → 2.5): **scale the item / enemy / encounter pools and stand up `tune`** —
turn the 1-enemy, 4-beat prototype into a real run worth balancing.

- **Content** (`src/content/`): more items (the draft pool is 4), enemies, and beats
  (the map is a fixed 4); the elite/boss tiers + events-with-prose the PRDs sketch.
  Author in GDScript catalogs (decision #23); keep every name/tooltip `tr()`-able.
- **`tune`**: bring the combat/draft tuning loop up on the autotest (the `tune` skill +
  `tune-run` agent scaffolding exist) — so picks/enemies/encounters are balanced by
  data, not feel.
- **Two small Phase-4 follow-ups worth closing first:** wire the **potion-throw UI**
  (clickable potion → `run.throw_potion`) and set up the **localization POT pipeline**
  (the tooling CLAUDE.md assumes — `tools/extract_pot.gd`, `locale/`; strings are
  already written extractable).

Build incrementally, test-first, committing each green step; the headless autotest is
the regression backstop, and the framed run screen is now watchable for feel
(`<exe> --path . res://src/scenes/main.tscn` → Start Run; `--autostart --shot
[--shot-delay s]` to capture a frame).

## Quick file map

`src/combat/` (spine) · `src/run/` (run_manager · encounter) · `src/content/` (all
defs + catalogs) · `src/autoloads/` (status_manager · save · draft · game_manager ·
sfx · music) · `src/autotest/` (the harness) · `src/vfx/` · `src/scenes/` (sandbox +
corridors) · `src/data/balance.gd` (tunables) · `tests/` (combat · content · run ·
autotest · smoke · utils) · `addons/gut/` (vendored).
