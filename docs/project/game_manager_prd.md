# Dark Corridor — Game Manager PRD

Session PRD (top of the tree). Sits under the [Architecture Map](architecture.md). The `Game manager` is the **session singleton** — it owns the game-state machine, the run lifecycle, and the save-lifecycle calls, and is the reachable-from-anywhere coordinator. It sits *above* the [Run manager](run_manager_prd.md): **Game (session) → Run (descent) → Combat (fight)**.

**Engine:** Godot 4.
**Date:** 2026-06-05. Pre-prototype.
**Naming:** `class_name GameManagerAutoload`, registered `Game` (autoload convention — access via `Game.*`).

Boundaries live in the hub: [architecture.md → Interface contracts → `Game manager`](architecture.md#interface-contracts-boundary-hub). This PRD specifies the *internals*.

---

## Purpose

The single session-level coordinator. It owns three things and nothing per-run:

- **The game-state machine** — the top-level phase/screen flow (title → run → death → meta/skill-tree → new run) and the transitions between them.
- **The run lifecycle** — start a fresh run, resume a saved one, or end one; it **creates, holds, and tears down** the `Run manager`.
- **The save-lifecycle calls** — `Save.read()` on launch (resume-vs-fresh), `Save.clear()` on death/win, and the separate **meta-save**. (The `Run manager` writes the per-encounter run snapshot itself — see below.)

It is also the **reachable-everywhere singleton** (`Game.*`): scene transitions, quit-to-menu, global pause, debug hooks — the things any layer may need to call without threading a reference through the tree.

What it **is not**:

- **Not the run.** The map, encounter sequencing, and the player run-state live in the `Run manager`. `Game` holds only a *reference* to the live run (null between runs) — never run-state itself.
- **Not combat.** It never touches the `Timekeeper` or the `Combat manager` (two tiers down, reached via the run's `Encounter`s).
- **Not `Save`.** It *calls* the stateless `Save` service; it doesn't serialize.
- **Not meta *content*.** It owns the meta-save *timing*; the unlock tree itself is the Meta PRD's.

---

## Why an autoload (the session singleton)

`Game` is an **autoload by deliberate choice**, not a node in the run scene. The "autoloads never hold per-entity state" principle targets **instance-lifetime** state — things that must be *fresh* each fight/run (the `Timekeeper`, the `Run manager`). `Game`'s own state is **session-lifetime**: it lives exactly as long as the autoload. The lifetimes match, so there is no "fresh" semantics to violate and no leak risk.

**The guardrail:** per-run state stays in the **instanced `Run manager`**. `Game` holds the game-state machine + a *reference* to the live run, nulled between runs — it never absorbs run-state. That line is what keeps the singleton from becoming a junk drawer. (It also slots into the `TestCleanup.reset_all_managers()` pattern like the other autoloads.)

---

## The game-state machine

`Game` owns the phase machine — at minimum **Boot → Title → Run → (Death | Win) → Meta → Title/Run**. Each phase owns its screen; `Game` drives the transitions and the run-lifecycle hooks that hang off them:

- **→ Run (fresh):** seed a new run from the chosen `Characters` definition (starting board + relic), create the `Run manager`.
- **→ Run (resume):** `Save.read()`; if a run save exists, create the `Run manager` and have it **rehydrate** from the snapshot; resume at the saved encounter.
- **Run → Death / Win:** the `Run manager` signals the outcome up; `Game` calls `Save.clear()`, tears down the run, and transitions to the death (loss) or win/credits → meta screen.

The exact phase list and screen content settle as screens are built — flagged, not invented.

---

## Save & meta (lifecycle only)

Push-not-pull is preserved across the split:

- The **`Run manager` writes** its own snapshot to `Save` on encounter entry (it owns the run-state schema).
- **`Game` owns the lifecycle calls** — `Save.read()` on launch, `Save.clear()` on death/win — and the **meta-save** (the cross-run dataset, survives death). On resume, `Game` reads the snapshot and hands it to a new `Run manager`, which rehydrates.

So `Game` decides *whether to resume*; the `Run manager` decides *what the run-state is*.

---

## Prototype scope

- A **thin state machine**: Title → Run → Death → restart (Run). The meta screen + meta-save are deferred (no meta in the prototype).
- Start a fresh run (seed via a stand-in `Characters`), end it on death/win, restart.
- `Save.read()` on launch + `Save.clear()` on death; create / tear down the `Run manager`; receive its run-ended signal.

**Not** in scope: the meta/skill-tree screen + meta-save schema, settings/options, pause UI, title-screen content.

---

## Open / deferred

- **Exact phase list + screen content** (title, death, meta) — settle as screens are built. **Pause is not a phase** (resolved below).
- **Meta-save schema + the meta screen** — Meta PRD (a separate cross-run dataset; uses the same `Save` service).
- **Settings / options ownership — partly resolved:** the **battle-speed** preference (×1/×2/×3) lives on `Game` as a session-level setting (`battle_speed` + `cycle_battle_speed`, never saved) — confirming `Game`-level ownership. A full settings *screen* + persisting preferences to disk is still deferred.
- **Pause semantics — resolved:** pause is a **run-screen presentation gate** (it freezes the screen's tick), **not** a `Game` phase and **not** the combat dial's ×0. Quit-to-menu from pause routes through `Game.return_to_title()` (keeps the save). See [run_screen](../ui/run_screen.md).

## Dependencies

- **Above:** nothing — top of the tree (the autoload root).
- **Creates / owns:** the `Run manager` (fresh-seeded or rehydrated); tears it down on run end.
- **Calls:** `Save` (`read` on launch, `clear` on death/win) + the meta-save; reads `Characters` to seed a fresh run.
- **Signalled by (below):** the `Run manager` → **run-ended (died / won)**.
- **Does not:** touch the `Timekeeper` / `Combat manager`; own per-run state or the map (`Run manager`); serialize (`Save`).
