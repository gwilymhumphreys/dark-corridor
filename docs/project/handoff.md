# Dark Corridor — Handoff (for a fresh agent)

> **Start here if you're picking up the work.** This is the orientation: what the
> game is, what's built, how to work, what's settled, and what's next. It points to
> the canonical docs rather than duplicating them — read this, then the linked docs.
>
> **Last updated:** 2026-06-06 — Phase 5's tune-machinery bite, **plus two non-content
> backlog items: settings/pause + the ×1/×2/×3 battle-speed dial** (timescale
> replace-vs-multiply resolved → replace) **and DoT per-applier attribution in the tune
> report** (poison now credited to its applier, e.g. Venom Fang, not a generic lump).
> **158 GUT tests green** on Godot 4.6; the run is watchable end-to-end and the autotest
> can play + report builds.
>
> **Content (items / enemies / encounters) is the project owner's domain — do NOT
> author content unless asked.** This handoff is for the *non-content* engineering
> backlog (see "Your task" below).

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
4. The **phase plans** (all BUILT): [`phase1_plan.md`](phase1_plan.md) (combat spine),
   [`phase3_plan.md`](phase3_plan.md) (run loop), [`phase4_plan.md`](phase4_plan.md)
   (real UI / the run screen — read [`../ui/run_screen.md`](../ui/run_screen.md) with
   it), [`phase5_plan.md`](phase5_plan.md) (the `tune` machinery).
5. The per-system **PRDs** as needed (each system has one in `docs/project/`).
6. **[`../testing/autotest.md`](../testing/autotest.md)** — the headless harness +
   draft strategies + the report `tune` reads; you'll use it to drive + test everything.

## Where things stand (what's built)

**Phases 1–4 + Phase 5's tune-machinery bite are complete, committed, 158 GUT tests
green, feel gate passed.** See `git log` (each step is its own green commit). Two
**non-content backlog items are also done — settings/pause + battle-speed, and DoT
per-applier attribution in the tune report** (see the bottom of this section).

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
  VFX wall) → **approach** (the enemy scales from depth) → fight (slow-mo-on-hover, the
  **potion-throw UI**) → **draft overlay** → advance along a **map strip** → win/death
  screens. The run screen drives `CombatManager.tick` each frame; the logic tree stays
  out of the scene tree (the autotest path is unchanged). Full doc:
  [`../ui/run_screen.md`](../ui/run_screen.md). Plus the **localization POT pipeline**
  (`tools/extract_pot.gd` → `locale/`; [`../reference/localization.md`](../reference/localization.md)).
- **Phase 5 (machinery bite) — the `tune` harness** (`src/autotest/`): seeded,
  board-aware **draft strategies** (`--strategy` live) + a **per-encounter / per-item
  report** (durations vs window, HP attrition, item fires + damage + trap-pick flags).
  The autotest can now *play different builds* and *report what each item did* — the two
  things `tune` needed. Doc: [`../testing/autotest.md`](../testing/autotest.md).
- **Settings/pause + battle-speed (non-content backlog #3)** — the **×1/×2/×3 battle-speed
  dial** (a `Game` session preference + an always-visible HUD `speed_button`, applied to
  each fight's `Timekeeper` base scale) + in-run **pause** (`ui_cancel` → `pause_menu`:
  Resume / Quit-to-menu — a run-screen gate, *not* a `Game` phase; the save is preserved
  so Title's Resume re-enters the beat). Resolved the **timescale replace-vs-multiply**
  open → **replace** (absolute slow-mo). Doc: [`../ui/run_screen.md`](../ui/run_screen.md).

**What does NOT exist yet** (most of it is content — the project owner's domain): the
item/enemy/encounter pools beyond the seed (5 items, 1 enemy, a 4-beat map), elite/boss
tiers + signature mechanics, events-with-prose, multi-act maps, characters,
meta-progression, and a real **`tune` pass** (the machinery is ready; it waits on
content). The **non-content** gaps are the backlog in "Your task".

## The architecture in one picture

Lifetime tiers: **`Game` (session) → `Run` (descent) → `Encounter` (beat) → `Combat`
(fight)**. Combat/run logic is plain `RefCounted`; only the three orchestrators
(`RunManager` / `Encounter` / `CombatManager`) are `Node`s, and **only
`CombatManager` runs `_physics_process`** (the one fixed-step tick).

**Autoloads (6, in `project.godot`):** `SfxManager`, `MusicManager`, `StatusManager`
(stateless rules), `Save` (JSON snapshot service), `Draft` (stateless reward draw),
`Game` (session singleton — phase machine + run lifecycle).

**The driving seam — important.** The run-logic Nodes stay **out of the scene tree**
(a Phase-3 invariant Phase 4 preserved — it did *not* mount them). Two clients drive
the same intent seam: the **autotest** steps `CombatManager.sim_step()` directly (no
real time → bit-reproducible), and the **run screen** calls `CombatManager.tick(delta)`
each physics frame (real-time play). Both supply draft picks (the Driver / the draft
overlay) and call `run.advance()` — neither mounts `Run`/`Encounter`/`Combat`.

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
- **Watch the run** (Phase 4): `<exe> --path . res://src/scenes/main.tscn` → Start Run
  (append `-- --autostart` to skip the menu; `--shot [--shot-delay s]` screenshots).
  The fixed **combat sandbox** (one fight, not the run) is still there:
  `<exe> --path . res://src/scenes/combat_sandbox.tscn` (hover to slow-mo, R restarts).
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

## Your task: the non-content engineering backlog

**Content (items / enemies / encounters) is the project owner's job — do NOT author
content unless explicitly asked.** The prototype loop is feature-complete; what's left
for engineering is below, roughly highest-value first. Pick *with the owner*; each is
test-first + its own green commit, with the headless autotest as the regression backstop.

1. **Run structure — multi-act + HP economy + the choice layer — DONE (mechanism;
   placeholder content).** `RunMap` = 3 acts × 15 beats (tunable): boss at each act end
   (final-act boss wins), guaranteed midpoint relic + a per-act rest fixed, the rest are
   **CHOICE** beats. The **choice layer** assembles 2-3 seeded candidates (`has_pending_choice`
   / `pending_choice` / `pick_path`); the **two-tier choice UI** (`choice_overlay` telegraphs
   the candidates) + the **event** type (`event_overlay`, prose + binary outcome, `pick_event_option`)
   are built; the run-screen FSM gained CHOOSING / EVENTING states. **HP economy:** between-act
   full heal, per-act rest, max-HP via relics. Snapshot/resume carry the picked/pending beat.
   **Still the owner's:** the real encounter/enemy/event content + boss **signature mechanics**;
   choice-set tuning (category spread, elite budget). PRDs: [run_manager](run_manager_prd.md) ·
   [encounter](encounter_prd.md).
2. **Reward routing — relics + elites — DONE (mechanism; placeholder content).**
   `RunManager._on_encounter_resolved` now grants a relic on the **RELIC** reward (drawn from
   `RelicCatalog.REWARD_POOL` on the run RNG — deterministic + resume-stable) and a **relic +
   draft** on the new **ELITE** reward (the reward asymmetry). Relics gained a **MAX_HP_BONUS**
   direct-mod shape (applied once on grant, baked into the snapshot). Placeholder reward relics
   (Vital Charm / Iron Idol) + placeholder elite/relic `EncounterDef`s (catalog-only). **Still
   the owner's:** which relics/elites exist, and **elite engage/skip** (that's the choice layer —
   item 1). [content](content_prd.md) · [encounter](encounter_prd.md).
3. **Settings / pause + battle-speed — DONE (2026-06-06).** The ×1/×2/×3 **battle-speed
   dial** (a `Game` session preference + an always-visible HUD toggle) + in-run **pause**
   (a run-screen gate with a Resume / Quit-to-menu menu) are built. Still open *here*: a
   full **settings screen** (audio sliders, persisting preferences to disk) — a larger,
   more content-flavoured pass left for later. [game_manager](game_manager_prd.md) ·
   [ui_layout](ui_layout_prd.md) · [run_screen](../ui/run_screen.md).
4. **Full-screen `CombatView` + the framed-vs-fullscreen feel compare** — the UI PRD's
   central open question, isolated to the swappable `CombatView` (Phase 4 built the
   framed one). Mock the full-screen variant, compare on feel. [ui_layout](ui_layout_prd.md).
5. **Tune-report fidelity — DoT per-applier attribution — DONE (2026-06-06).** Poison
   damage was lumped as "Poison" (Venom Fang read 0 in the contribution table). Now a
   **pre-step status snapshot** credits the DoT remainder to the item that applied it
   (`Status.source`) — Venom Fang reads its real poison damage; a multi-applier remainder
   splits by weight; a source-less DoT keeps the generic channel. In `src/autotest/`
   (logger `attribute_damage` + the mode's per-step observation). [autotest](../testing/autotest.md).
6. **Stat-statuses — SEAMS WIRED (placeholder content).** Both damage-modifier seams are
   built: `outgoing_damage_mult` (applied at fire time in `Item._resolve_effect`) and the
   incoming **amplifier** stage in `resolve_incoming_damage` (before block). `StatusDef`
   carries both as **% multipliers** (cascade-safe — not flat-per-fire). Placeholder statuses
   **Weak** (outgoing −25%) / **Vulnerable** (incoming +50%) + a **Sundering Bolt** applier
   prove the path; the real stat-status content (numbers, per-stack variants, which damage
   types amplify) is the **owner's**. [status_manager](status_manager_prd.md) · [design](design.md).

7. **Spore-engine seams (the first status-identity character) — NEW, spec'd; build with the content.** The Mushroom Druid ([`../design/mushroom_druid.md`](../design/mushroom_druid.md)) needs three engine seams beyond apply/tick/resolve: (1) **status-stack consumption** — `StatusManager.consume(target, type, amount)` to spend spores as fuel (self-fuel resolves in the Item fire pipeline; opponent-fuel in the Combat manager's per-target spawn path); (2) **evasion** — the "acts but misses" fizzle seam for blinding (a blinded source's damage Deliveries fizzle *with a reason*, so VFX shows a whiff — distinct from silence/`gate`, which = inert); (3) the **player-side** consumer of the **mid-fight roster add** (summon tokens + lethal's spawn-on-kill rider) — **deferred with the boss "summons-adds"** work (see "What does NOT exist yet" + [enemy](enemy_prd.md) / #22). Caps 1+2 are contained + buildable when the content calls for them; the spore **appliers (poison / blinding-status / burn / self-regen / self-block) need nothing new** — they're the built apply-status subtype + existing status shapes. Full spec, build order, and open decisions: [spore_engine](spore_engine_prd.md). **This is engineering — yours, not content.**

**Smaller polish:** the **draft overlay overlaps the corridor's left edge** (layout);
**HP as a beaten-up portrait** (design wants damage-state on the portrait, not just a
bar). *(The **timescale replace-vs-multiply** open is now resolved → replace, with the
battle-speed dial — item 3 above.)* Decision-AI: the Driver's **potion / choice / event**
policies stay stubs until those beats exist.

**Run / watch:** `<exe> --path . res://src/scenes/main.tscn` → Start Run; append
`-- --autostart --shot [--shot-delay s]` to capture a frame. **Autotest:** `<exe>
--headless --path . res://src/autotest/autotest.tscn -- --autotest --seed 1 --strategy
greedy-synergy --report autotest_results/r.md`. **Suite:** `<exe> --headless --path .
-s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gexit`.

## Quick file map

`src/combat/` (spine) · `src/run/` (run_manager · encounter) · `src/content/` (all
defs + catalogs) · `src/autoloads/` (status_manager · save · draft · game_manager ·
sfx · music) · `src/autotest/` (the harness + strategies + report) · `src/vfx/` ·
`src/scenes/main.tscn` + `main_controller.gd` (presentation root) · `src/scenes/screens/`
(title · run · outcome · draft_overlay · draft_card · map_strip) · `src/scenes/combat/`
(combat_view_framed · combat_corridor · board_strip · item_cell · potion_slot) ·
`src/scenes/` (sandbox + corridors) · `src/data/balance.gd` (tunables) · `tools/extract_pot.gd`
+ `locale/` (i18n) · `tests/` (combat · content · run · autotest · ui · smoke · utils) ·
`addons/gut/` (vendored).
