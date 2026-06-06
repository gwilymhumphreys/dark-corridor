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
- **Encounter sequencing + the corridor advance** — at a choice point it assembles the 2–3 candidate `Encounter`s and instantiates the picked one; the next beat is **created after the current reward and approaches from depth** (the advance is its approach), resolving on arrival (a fight `Encounter` creates a `Combat manager`). The cycle is detailed below.
- **The player run-state** — `{ actor, allies, relics, potions, position, run RNG }`. The player `Actor` + any run-scoped **`allies`** (persistent player-side bodies — spore_engine Cap 3) are **run-lifetime**, owned here, saved + rehydrated, full-healed between acts, and seeded into each fight; relics and potions live here too (not on the Actor — [Actor PRD](actor_prd.md)).
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

The run-state `{ actor, relics, potions, position, rng }` is what the snapshot persists. The `Run manager` **owns the run RNG** — a single seeded PRNG driving all run-level randomness (draft offers, encounter assembly). Its **full state** (not just the seed) goes in the snapshot, so **reloading a save reproduces the same future outcomes every time** — deterministic resume, and no save-scumming a bad draft by quit-reload ([Save PRD](save_prd.md)). Per-fight combat randomness (e.g. random item-targeting — #14) draws from a **derived per-fight stream** (seeded from the run seed + encounter index), so combat doesn't perturb the run stream and a re-entered fight replays identically.

## Save (snapshot, not timing)

The `Run manager` knows the run-state schema, so it **builds** the snapshot and **writes** it (`Save.write`) on encounter entry, and **rehydrates** from one on resume (the `Game manager` hands it the snapshot read from `Save`). It does **not** decide *when* to load or clear — that timing is the `Game manager`'s. Combat state is never in the snapshot (ephemeral — Save PRD).

---

## Prototype scope

- **BUILT — the multi-act structure (`RunMap`).** A single linear track of `ACTS` × `BEATS_PER_ACT` beats (global `position`; act/beat-within-act derived). Each act ends in a **boss** (the final act's boss wins the run); a guaranteed **midpoint relic** beat and one **rest** beat are fixed; the rest are **CHOICE** beats. PLACEHOLDER numbers + a tiny pool drawn repeatedly — the owner re-contents.
- **BUILT — the choice layer (logic).** A CHOICE beat assembles `CHOICE_COUNT` distinct candidates from the act pool (seeded by the run RNG → deterministic + resume-stable; the drawn set is **saved**, never re-rolled). `has_pending_choice()` / `pending_choice()` / `pick_path(index)` is the choice-point intent — the pick creates the live `Encounter`. The two-tier choice **UI** + **events** are the next stages; the headless autotest drives the pick (`choose_path`).
- **BUILT — HP economy.** Between-act **full heal** on crossing into a new act; the per-act REST partial heal; max-HP growth via the granted relics (`MAX_HP_BONUS`).
- The **player run-state** (Actor + relics/potions + position + RNG); auto-save on encounter entry (and on a choice pick); rehydrate on resume — including the current beat's resolution (the picked/fixed encounter id, or the pending choice candidates).
- Report **run-ended (died / won)** up to the `Game manager`.

**Not** in scope yet: the choice/telegraph **UI** + the act-aware map polish (stage 2), the **event** encounter type (stage 3), boss **signature mechanics** + the real encounter/enemy content (the owner's).

---

## Open / deferred

- **Act / beat placement — BUILT** (`RunMap`, placeholder); the **1D progress-map UI** is extended for acts (the choice-screen UI is stage 2). Real placement/pools are the owner's content.
- **Elite offer count + reward asymmetry — reward asymmetry BUILT** (elite = relic + draft, #2); the **engage/skip** is the choice layer (pick the elite candidate vs another); offer counts are design/tuning.
- **RNG — resolved (#20):** the `Run manager` owns the run RNG; its **full state** is saved (deterministic resume, no save-scum); the per-fight combat stream is derived from the run seed + encounter index.
- **Multi-Actor player side (drafting allies) — deferred (#22):** run-state's `actor` is the player *party* (a roster of 1 today); keep it list-friendly so allies / summoning stay additive — don't hardwire one player actor.
- **Encounter handoff — resolved ([Encounter PRD](encounter_prd.md)):** the `Run manager` instantiates the picked `Encounter` with context (player `Actor` + run-state accessors + RNG + position); a fight `Encounter` spawns its own enemies + ordering and creates the `Combat manager`.
- **Resolved (#15):** the game-state machine is the `Game manager`'s, not here.

## Dependencies

- **Above:** the `Game manager` — creates it (fresh-seeded or rehydrated), reads its **run-ended** signal, owns its lifetime.
- **Calls down to / drives:** `Encounter` (one per beat; fights create a `Combat manager`), `Draft` (on reward), the `Corridor` renderer (advance), `Save` (`write` on encounter entry), `Characters` (read the starting board/relic on a fresh run). Owns + applies HP-economy to the player `Actor`.
- **Does not:** touch the `Timekeeper` / run the combat tick (`Combat manager`); own the game-state machine or save-lifecycle timing (`Game manager`).
