# Dark Corridor — Phase 4 Build Plan (real UI / the run screen)

> **A build plan, not a spec.** The systems are specced in their PRDs
> ([ui_layout](../systems/ui_layout.md) · [vfx_driver](../systems/vfx_driver.md)) on top of the
> [architecture → Scene tree](../systems/architecture.md#scene-tree--node-model); this is the
> ordered, test-first path. Sits under [decision_log.md](../decision_log.md) →
> *Build order* step 2.4, on top of the Phase 1 combat spine + Phase 2 autotest +
> Phase 3 run loop.

**Engine:** Godot 4.6.
**Date:** 2026-06-06.
**Status: BUILT (2026-06-06).** All 8 steps green — the presentation skeleton + the
real-time tick seam, the framed combat view (corridor + thorn-demon occupant, boards,
HP, potions), slow-mo-on-hover, the run-screen FSM (the whole descent in real time),
the draft overlay, the map strip, the corridor approach (the enemy scales from depth),
and the death/win screens. **126 GUT tests green**; the headless autotest still drives
a full run to a win. Presentation: `src/scenes/main.tscn` + `main_controller.gd`,
`src/scenes/screens/`, `src/scenes/combat/` (combat view) — see
[`docs/systems/run_screen.md`](../systems/run_screen.md). **Deviations from the plan below:** the
`RunManager.advancing` signal was unnecessary (the run screen orchestrates the advance
+ approach directly, keeping RunManager presentation-free); the death/win screens are
**one** `outcome_screen.tscn` (parameterized by outcome) rather than two. **Two follow-ups
done (2026-06-06):** the **potion-throw UI** (clickable potion slots →
`RunManager.throw_potion`) and the **localization POT pipeline**
(`tools/extract_pot.gd` → `locale/messages.pot` + `en.po`, registered in
`project.godot` — see [`../systems/localization.md`](../systems/localization.md)).
**Next: Phase 5 — scale content + `tune`.**

---

## Goal

The first **watchable run** (vs. headless + the fixed sandbox): launch the game,
descend the Phase-3 map in real time — **approach → fight (auto-resolving, with
slow-mo-on-hover) → draft → advance × N → win/death** — composed in the **framed**
layout the user picked. The presentation only *reads* the logic and *emits the same
intents the autotest Driver calls*; **the headless autotest stays the regression
backstop** the whole way (it keeps driving `sim_step()` directly).

## Locked layout decisions (this phase)

Resolved with the user 2026-06-06 (the UI PRD's "central open question" + the two
named forks):

- **Framed** combat view (Wizardry / Eye-of-the-Beholder family), not full-screen.
  The other layout is a later feel-compare — isolated to the swappable `CombatView`.
- **Corridor panel sits top-right, resizeable** (a Control rect we can move/resize
  freely later to experiment). The **enemy (thorn-demon) is centered *inside* the
  corridor SubViewport** — clipped by the frame, anchored at the vanishing point, so
  it can scale up from depth on approach. The **player character sits outside the
  corridor, on the left.**
- **Built as `.tscn` scenes, not assembled in code** (CLAUDE.md: scenes over code).
  Static structure lives in the scene files; only the *data-driven* lists (the N
  board items) are instanced at runtime from a per-item scene.
- **Map = visible but simple:** a horizontal line with the beats labelled + a
  position marker (not the polished 1D track — that's a later content pass).
- **Approach:** `assets/sprites/enemies/thorn-demon.png` is the enemy sprite, and it
  is the **only** thing that scales up from the vanishing point on the approach walk.

## Enemy-in-corridor architecture (investigated 2026-06-06)

The corridor (`CorridorScaled`) is a clean perspective law: every tile at
corridor-depth `e` cells is scaled by **`depth_ratio^e`** about the **vanishing point
= the renderer's node origin** (kept at the SubViewport centre by `auto_view_size`).
An object **on the central axis always projects to the vanishing point** — only its
*scale* changes with depth. So the enemy is architected as a **corridor occupant**:

- **The thorn-demon `Sprite2D` is a child of the `CorridorScaled` instance**, at local
  `(0,0)` (the vanishing point), `z_index` high (drawn over the floor). Being inside
  the SubViewport, the `SubViewportContainer` **clips** it to the frame, it composites
  with the walls, and it rides the renderer's `position`/`view_size` so it stays
  centred when the panel is **resized**. Authored in the scene
  (`combat_corridor.tscn`: `SubViewportContainer → SubViewport → CorridorScaled →
  ThornDemon`) — scenes, not code. (The shared `corridor_panel.tscn` is left untouched;
  combat composes its own corridor scene so it can host the occupant.)
- **The perspective law stays on the renderer** (no duplication in presentation):
  add `CorridorScaled.axis_scale(depth_cells: float) -> float { return
  pow(depth_ratio, depth_cells) }`. The combat view sets
  `thorn_demon.scale = full_scale × corridor.axis_scale(z)` and only animates `z`.
- **The approach tweens one scalar:** `z` linearly far→near (~`APPROACH_DEPTH_START`
  ≈ 5 cells → 0) over `APPROACH_DURATION` (~2.5s); linear-in-depth gives the natural
  "looms at the end" growth. On arrival (z≈0) the boards activate / combat begins. The
  enemy depth is an **independent tween** (deterministic arrival), not coupled to the
  treadmill `player_z` (coupling so the walk literally reaches it is a noted future
  option). New `Balance` consts: `APPROACH_DEPTH_START`, `APPROACH_DURATION`,
  `ENEMY_FULL_SCALE`.

## Discipline (unchanged)

Combat/run logic stays `RefCounted` + the Phase-3 orchestrator `Node`s; **the logic
tree stays out of the scene tree** (the Phase-3 invariant) — the run screen drives
the fight by calling the Combat manager's tick each frame, it does **not** mount the
logic Nodes. Each step goes green headless before the next. Commit each green step;
no self-attribution (CLAUDE.md). Every player-facing string `tr()`/POT-extractable
from the first one. If a step changes behaviour a doc describes, update that doc.

## The driving seam (how the run runs in real time)

Phase 3 drives the run by **explicit call + signal** with the logic Nodes kept out
of the tree (the autotest steps `sim_step()`). Phase 4 keeps that invariant and adds
**one real-time client**: the run screen. The Combat manager's per-fight tick (today
the body of `_physics_process`) is exposed as a public **`tick(delta)`**; in
real-time the **run screen calls `active_cm.tick(delta)` each `_physics_process`**
(`steps_due × sim_step` off real time), and headless the **autotest calls
`sim_step()` directly** — both are the one tick, neither mounts the logic tree. The
run screen runs an explicit state machine mirroring `AutoTestMode.run_full`:

```
enter beat → (approach) → begin_current → fight: drive cm.tick until resolved
   → fulfil reward → pending draft? show overlay, await pick → advance → …
   → run_ended(outcome) → death / win screen
```

It emits the **same intents** the Driver calls: `run.apply_draft_pick`,
`run.throw_potion`, `cm.request_slowmo`. The autotest remains the first (headless)
client; the run screen is the second (real-time) one.

## Build order

Each step: build → green headless (full GUT suite + any new tests) → commit. The
first steps get a **live fight on screen** fast; later steps replace placeholders
and layer the loop. `--shot` screenshots are the feel check at each visual step.

### Step 1 — Presentation skeleton + the tick seam

`main.tscn` (root `Main`) → `ScreenHolder`; a `MainController` boots `Game` and swaps
screens on `Game.phase_changed`. A minimal **title screen** (Start / Resume buttons,
themed, `UIJuice`). Extract `CombatManager.tick(delta)` (the run screen's real-time
driver; `_physics_process` calls it so the sandbox still self-drives). A first
**run screen** that, on a started run, drives the active fight's `cm.tick(delta)` each
physics frame — watchable with the **existing placeholder `BoardView` / `VfxDriver`**
as a stopgap (replaced in Step 2). Flip `project.godot` `main_scene` → `main.tscn`
(corridor_testbed + sandbox stay runnable as direct scenes).

- **Files:** `src/scenes/main.tscn` + `src/scenes/main_controller.gd`,
  `src/scenes/screens/title_screen.tscn` + `.gd`, `src/scenes/screens/run_screen.tscn`
  + `.gd`; edit `src/combat/combat_manager.gd`, `project.godot`.
- **Tests:** `tick(delta)` advances a fight to resolution (mirrors `run_headless`);
  a mounted CM still resolves via `_physics_process` (await physics frames); the full
  suite stays green (autotest's direct `sim_step` path untouched).

### Step 2 — The framed combat view (scenes, not code)

`combat_view_framed.tscn` — the locked layout: the **corridor top-right** as
`combat_corridor.tscn` (the resizeable `SubViewportContainer` → `SubViewport` →
`CorridorScaled` → **ThornDemon occupant**, per *Enemy-in-corridor architecture*
above); the **player character block left, outside**; the **two board rows** (player
+ enemy) as scenes; **portrait + HP**; **potion slots**. Add
`CorridorScaled.axis_scale(depth_cells)` (the perspective law for the occupant).
`item_icon.tscn` (colour panel + value + cooldown ring) instanced per board item into
an `HBoxContainer`; `board_view.tscn` composes a portrait/HP + the row. The
`VfxDriver` wall composites over it. Replaces the Step-1 placeholders in the run
screen. Reads live `Actor`/board/CM; writes nothing.

- **Files:** `src/scenes/combat/combat_view_framed.tscn` + `.gd`,
  `src/scenes/combat/combat_corridor.tscn`,
  `src/scenes/combat/item_icon.tscn` (+ port `item_icon.gd`),
  `src/scenes/combat/board_view.tscn` (+ port `board_view.gd`); edit
  `src/scenes/corridors/corridor_scaled.gd` (add `axis_scale`); wire into `run_screen`.
- **Tests:** the view instances headless and binds to a fight without error; the row
  instances one icon per board item; HP text tracks the actor; `axis_scale(0)==1` and
  `axis_scale(1)==depth_ratio`. (Feel: `--shot`.)

### Step 3 — Slow-mo-on-hover (the timescale intent)

Hover any board item / potion / the enemy → the view emits the **timescale intent**
`cm.request_slowmo(true)` (off on exit). One verb; slows both sides proportionally
(the dial). Out of combat there's no clock — inspection is tooltips only.

- **Files:** `run_screen.gd` / `combat_view_framed.gd`.
- **Tests:** hover sets the override (`timekeeper` scale → SLOWMO), exit clears it.

### Step 4 — The run-screen state machine (the loop)

The full real-time cycle: enter beat → `begin_current` → fight (drive `cm.tick`,
await `resolved`) → fulfil reward → if a draft is pending, raise the draft overlay
and await the pick → `advance` → repeat; rests resolve immediately; `run_ended` →
death/win. Explicit state enum + signal connections (no `await` soup). Auto-starts a
seeded run on boot for the prototype (Resume path too).

- **Files:** `run_screen.gd`.
- **Tests:** the state machine reaches **won** when driven with a real run + auto
  picks (logic-only, no overlay) — a headless parity check against `run_full`; a loss
  routes to death. (The autotest stays the broader backstop.)

### Step 5 — Draft overlay

`draft_overlay.tscn` — the 1-of-3 candidates as themed cards (icon/name/tooltip,
`UIJuice`), shown on a pending draft; the pick emits the **draft-pick intent**
(`run.apply_draft_pick`) and resumes the loop. No skip (draft.md). Localized.

- **Files:** `src/scenes/screens/draft_overlay.tscn` + `.gd`; wire into `run_screen`.
- **Tests:** the overlay lists the pending offer; selecting card *i* emits index *i*.

### Step 6 — The map strip

`map_strip.tscn` — a horizontal line of the beats from `RunManager.MAP`, each
labelled by type (fight / rest / boss-finale), with a marker at `run.position`,
updated on advance. Simple, readable, resizeable; shown as a run-screen header/overlay.

- **Files:** `src/scenes/screens/map_strip.tscn` + `.gd`; wire into `run_screen`.
- **Tests:** it renders one node per beat and the marker tracks `position`.

### Step 7 — The corridor approach (thorn-demon scales from depth)

After a draft/advance, the next fight's **thorn-demon starts small at the corridor
vanishing point and scales up to full over ~2–3s** — tween depth `z` from
`APPROACH_DEPTH_START`→0, setting `thorn_demon.scale = ENEMY_FULL_SCALE ×
corridor.axis_scale(z)` (the occupant law from Step 2), with the corridor optionally
gliding via `set_forward_held` for parallax; **boards activate on arrival** (combat
begins when it locks at full scale). The advance stays logic-clean: `RunManager`
changes position + (new) emits `advancing(next)`; the run screen animates and times
board activation to arrival. Only the thorn-demon scales.

- **Files:** `run_screen.gd` / `combat_view_framed.gd`; add `advancing` to
  `run_manager.gd` (presentation signal only — no logic change).
- **Tests:** `advancing` fires on advance with the next beat; the approach tween
  reaches full scale then begins the fight (headless: the timing hook resolves).

### Step 8 — Death / win screens + localization + docs

`death_screen.tscn` + `win_screen.tscn` (outcome readout, **New Run** → `start_run`,
**Title** → reset). Full **localization audit** (every player-facing string
`tr()`/in-`.tscn`-auto-translated; run the POT extractor). Docs: update
`docs/index.md`, `handoff.md`, `decision_log.md` (build status), and add a
`docs/systems/run_screen.md` describing the framed composition + the real-time seam.

- **Files:** `src/scenes/screens/death_screen.tscn` + `win_screen.tscn` (+ scripts),
  POT regen, docs.
- **Tests:** death/win route from `run_ended`; the suite stays green; the autotest
  still passes (the run is still headless-drivable end to end).

---

## Interfaces to lock at the start (so steps don't drift)

```
CombatManager:  tick(delta:float)->void          # the run screen's real-time driver
                (request_slowmo / throw_consumable / deliveries / resolved — unchanged)
RunManager:     advancing(next_def:EncounterDef)  # NEW signal — presentation approach cue
                (begin_current / combat_manager / has_pending_draft / pending_draft /
                 apply_draft_pick / throw_potion / advance / is_ended — unchanged)
CorridorScaled: axis_scale(depth_cells:float)->float  # NEW — central-axis occupant scale (pow(depth_ratio, z))
MainController: boots Game; swaps ScreenHolder children on Game.phase_changed
RunScreen:      reads Game.run (+ active cm); emits intents only; owns the FSM
```

## Phase-4 micro-decisions (pre-flagged)

- **The logic tree stays out of the scene tree.** Real-time is driven by the run
  screen calling `cm.tick(delta)` — not by mounting the Combat manager. Keeps the
  Phase-3 invariant + the autotest byte-identical; `_physics_process` is retained on
  the CM only so the existing sandbox (which *does* `add_child` its CM) still works.
- **Framed only** this phase; the swappable `CombatView` seam exists so full-screen
  is an additive later compare (the architecture isolates it there).
- **Auto-start a seeded run on boot** for the prototype (a real character-select is
  post-prototype); the title screen offers Start (fresh seed) + Resume (`Save`).
- **Approach scales only the thorn-demon** (one sprite at the vanishing point) — the
  general "spawn enemies at depth" is a one-enemy case for now (multi-enemy board
  scaling is out of prototype scope, UI PRD).

## Explicitly NOT in Phase 4

The full-screen layout (later feel-compare), the final theme/palette pass, the
polished 1D-map, enchant/potion draft sub-choice UIs, multi-enemy board scaling, the
event-prose screen, characters/meta. Those follow the prototype loop (decision-log
Next steps → step 2.5, scale content + `tune`).
