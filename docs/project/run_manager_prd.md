# Dark Corridor — Run Manager PRD

Run PRD. Sits under the [Architecture Map](architecture.md). The `Run manager` owns **one descent**: the map, encounter sequencing, the player run-state, and HP-economy policy. It is **instanced per run**, created and owned by the [Game manager](game_manager_prd.md). It sits between **Game (session)** above and the per-fight **Combat manager** below (reached via `Encounter`).

**Engine:** Godot 4.
**Date:** 2026-06-05. Pre-prototype.
**Naming:** `class_name RunManager`, **instanced** (not an autoload) — one per run, created/torn down by the `Game manager`.

Boundaries live in the hub: [architecture.md → Interface contracts → `Run manager`](architecture.md#interface-contracts-boundary-hub). This PRD specifies the *internals*.

---

## Purpose

The `Run manager` is the descent — it walks the player through one run and holds everything that lives exactly that long. It owns:

- **The map** — the linear act/beat structure and the 1D progress track (boss at each act end, midpoint relic, rests, elites offered, events, basic fights). Forward-visible, single, no branching ([design](design.md)). Counts/placements are design/tuning, not here.
- **Encounter sequencing + the corridor advance** — for each beat it creates an `Encounter` (a fight `Encounter` creates a `Combat manager`; an event runs the choice layer), awaits the result, then drives the corridor forward to the next beat.
- **The player run-state** — `{ actor, relics, potions, position, run RNG }`. The player `Actor` is **run-lifetime** and owned here; relics and potions live here too (not on the Actor — [Actor PRD](actor_prd.md)).
- **HP-economy policy** — applies the design's rules *to* the Actor: HP persists between encounters, between-act full heal, rest partial-heals, max-HP growth (relics / events). The Actor just holds the values; the policy is decided here.
- **The run snapshot** — it **builds** the snapshot and calls `Save.write()` on encounter entry, and **rehydrates** run-state from a snapshot on resume.

What it **is not**:

- **Not the session.** The game-state machine, the run-lifecycle decision (start/resume/end), and the save-*lifecycle* timing are the `Game manager`'s. The `Run manager` is created by it and signals **run-ended** back up.
- **Not the fight.** It never touches the `Timekeeper` or runs the combat tick — it hands a fight to an `Encounter` (which owns the `Combat manager`) and awaits the result.
- **Not the `Encounter` internals** (the choice layer / event content) or the **`Draft`** internals — it drives them.

---

## The map & sequencing

The run is a single linear track of beats. The `Run manager` walks it as a cycle — the **next beat is created right after the current one's reward and approaches from depth** (the walk *is* the next encounter arriving, not dead time):

1. **Resolve** the current `Encounter`: a fight (→ `Combat manager`, await win/loss), a non-combat event (binary choice), or a rest (partial heal).
2. **Fulfil the reward** it reports — drive a `Draft` (item), grant a relic (elite/boss), or none (rest); an event's outcome is applied via the run-state surface. On a **fight loss** → **run-ended (died)**; on the **final-boss win** → **run-ended (won)** (the cycle ends).
3. **Pick the next beat** — at a **choice point**, assemble 2–3 candidate `Encounter` definitions (a pool-draw under act constraints + the run RNG), present them (UI), take the pick; a **fixed beat** (boss, midpoint relic-grant) is next directly. The candidate *assembly* is the `Run manager`'s; the `Encounter` is the resolved unit ([Encounter PRD](encounter_prd.md)).
4. **Create** the next `Encounter` (spawn its actors at the vanishing point) and **auto-save** the run snapshot — encounter entry, the resume point (design).
5. **Advance** the corridor — the encounter **approaches from depth** into full view (the renderer scales it up — `docs/corridors/`; not self-advancing); on **arrival** (front locked at full scale) go to 1 and resolve it.

Act boundaries apply the **between-act full heal** (automatic, not a choice-layer beat — design).

Beat placement (boss telegraph, midpoint relic, elite offers, rests) is the map's content; numbers → design/tuning.

## Player run-state & RNG

The run-state `{ actor, relics, potions, position, rng }` is what the snapshot persists. The **run RNG** is seeded once per run (deterministic offers/beats, not re-rollable by quit-resume — [Save PRD](save_prd.md)); per-fight random draws (e.g. random enemy-item targeting) come from a per-fight stream derived from it, so fights stay bit-reproducible. (The exact seeding split settles with the Draft / Encounter / Save RNG ownership.)

## Save (snapshot, not timing)

The `Run manager` knows the run-state schema, so it **builds** the snapshot and **writes** it (`Save.write`) on encounter entry, and **rehydrates** from one on resume (the `Game manager` hands it the snapshot read from `Save`). It does **not** decide *when* to load or clear — that timing is the `Game manager`'s. Combat state is never in the snapshot (ephemeral — Save PRD).

---

## Prototype scope

- A **minimal linear track** of a few beats; sequence `Encounter`s (one fight + optionally one event/rest), advance between them.
- The **player run-state** (Actor + a couple of relic/potion slots + position + RNG); auto-save on encounter entry; rehydrate on resume.
- Report **run-ended (died / won)** up to the `Game manager`.

**Not** in scope: full act/boss/elite/rest placement, the 1D map UI, the reward-draft economy, multi-act HP-economy tuning.

---

## Open / deferred

- **Act / beat placement + the 1D progress-map UI** — design/tuning + the `Encounter` PRD (composition) and a UI pass.
- **Elite offer count + reward asymmetry** — design / `Encounter` PRD.
- **RNG seeding split** (run stream vs. per-fight stream) — settles with the Draft / Encounter / Save PRDs.
- **Encounter handoff — resolved ([Encounter PRD](encounter_prd.md)):** the `Run manager` instantiates the picked `Encounter` with context (player `Actor` + run-state accessors + RNG + position); a fight `Encounter` spawns its own enemies + ordering and creates the `Combat manager`.
- **Resolved (#15):** the game-state machine is the `Game manager`'s, not here.

## Dependencies

- **Above:** the `Game manager` — creates it (fresh-seeded or rehydrated), reads its **run-ended** signal, owns its lifetime.
- **Calls down to / drives:** `Encounter` (one per beat; fights create a `Combat manager`), `Draft` (on reward), the `Corridor` renderer (advance), `Save` (`write` on encounter entry), `Characters` (read the starting board/relic on a fresh run). Owns + applies HP-economy to the player `Actor`.
- **Does not:** touch the `Timekeeper` / run the combat tick (`Combat manager`); own the game-state machine or save-lifecycle timing (`Game manager`).
