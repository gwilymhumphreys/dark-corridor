# Dark Corridor — Run Manager PRD

Run PRD. Sits under the [Architecture Map](architecture.md). The `Run manager` owns **one descent**: the map, encounter sequencing, the player run-state, and HP-economy policy. It is **instanced per run**, created and owned by the [Game manager](game_manager.md). It sits between **Game (session)** above and the per-fight **Combat manager** below (reached via `Encounter`).

**Engine:** Godot 4.
**Date:** 2026-06-05. Pre-prototype.
**Naming:** `class_name RunManager`, **instanced** (not an autoload) — one per run, created/torn down by the `Game manager`.

Boundaries live in the hub: [architecture.md → Interface contracts → `Run manager`](architecture.md#interface-contracts-boundary-hub). This PRD specifies the *internals*.

---

## Purpose

The `Run manager` is the descent — it walks the player through one run and holds everything that lives exactly that long. It owns:

- **The map** — the linear act/beat structure and the 1D progress track (boss at each act end, midpoint relic, plus rolled beats: basic fights, elites, events). Forward-visible, single, no branching ([design](../design/game_design.md)). Counts/placements are design/tuning, not here.
- **Encounter sequencing + the corridor advance** — each non-fixed beat **auto-rolls** its content (COMBAT vs EVENT, anti-repeat biased — no player choice) and instantiates the rolled `Encounter`; the next beat is **created after the current reward and approaches from depth** (the advance is its approach), resolving on arrival (a fight `Encounter` creates a `Combat manager`). The cycle is detailed below.
- **The player run-state** — `{ actor, allies, relics, potions, position, run RNG }`. The player `Actor` + any run-scoped **`allies`** (persistent player-side bodies — spore_engine Cap 3) are **run-lifetime**, owned here, saved + rehydrated, full-healed between acts, and seeded into each fight; relics and potions live here too (not on the Actor — [Actor PRD](actor.md)).
- **HP-economy policy** — applies the design's rules *to* the Actor: HP persists between encounters, between-act full heal, rest partial-heals, max-HP growth (relics / events). The Actor just holds the values; the policy is decided here.
- **The run snapshot** — it **builds** the snapshot and calls `Save.write()` on encounter entry, and **rehydrates** run-state from a snapshot on resume.

What it **is not**:

- **Not the session.** The game-state machine, the run-lifecycle decision (start/resume/end), and the save-*lifecycle* timing are the `Game manager`'s. The `Run manager` is created by it and signals **run-ended** back up.
- **Not the fight.** It never touches the `Timekeeper` or runs the combat tick — it hands a fight to an `Encounter` (which owns the `Combat manager`) and awaits the result.
- **Not the `Encounter` internals** (the event prose / binary outcome) or the **`Draft`** internals — it drives them.

---

## The map & sequencing

The run is a single linear track of beats. The `Run manager` walks it as a cycle — the **next beat is created right after the current one's reward and approaches from depth** (the walk *is* the next encounter arriving, not dead time):

1. **Resolve** the current `Encounter`: a fight (→ `Combat manager`, await win/loss) or a non-combat event (binary choice).
2. **Fulfil the reward** it reports — drive a `Draft` (item), grant a relic (elite/boss), or none; an event's outcome is applied via the run-state surface. On a **fight loss** → **run-ended (died)**; on the **final-boss win** → **run-ended (won)** (the cycle ends).
3. **Roll the next beat** — a **ROLL beat** auto-selects COMBAT vs EVENT on the run RNG (anti-repeat biased) and draws a def from the matching pool; a **fixed beat** (boss, midpoint relic-grant) is next directly. The roll is the `Run manager`'s; the `Encounter` is the resolved unit ([Encounter PRD](encounter.md)).
4. **Create** the next `Encounter` (spawn its actors at the vanishing point) and **auto-save** the run snapshot — encounter entry, the resume point (design).
5. **Advance** the corridor — the encounter **approaches from depth** into full view (the renderer scales it up — `docs/systems/corridors/`; not self-advancing); on **arrival** (front locked at full scale) go to 1 and resolve it.

Act boundaries apply the **between-act full heal** (automatic — design).

Beat placement (the band edges, the fixed boss/relic, the per-band pools) is the map's content; numbers → design/tuning.

## Player run-state & RNG

The run-state `{ actor, relics, potions, position, rng }` is what the snapshot persists. The `Run manager` **owns the run RNG** — a single seeded PRNG driving all run-level randomness (draft offers, encounter assembly). Its **full state** (not just the seed) goes in the snapshot, so **reloading a save reproduces the same future outcomes every time** — deterministic resume, and no save-scumming a bad draft by quit-reload ([Save PRD](save.md)). Per-fight combat randomness (e.g. random item-targeting — #14) draws from a **derived per-fight stream** (seeded from the run seed + encounter index), so combat doesn't perturb the run stream and a re-entered fight replays identically.

## Save (snapshot, not timing)

The `Run manager` knows the run-state schema, so it **builds** the snapshot and **writes** it (`Save.write`) on encounter entry, and **rehydrates** from one on resume (the `Game manager` hands it the snapshot read from `Save`). It does **not** decide *when* to load or clear — that timing is the `Game manager`'s. Combat state is never in the snapshot (ephemeral — Save PRD).

---

## Prototype scope

- **BUILT — the multi-act structure (`RunMap`).** A single linear track of `ACTS` × `BEATS_PER_ACT` beats (global `position`; act/beat-within-act derived). Each act ends in a **boss** (the final act's boss wins the run) and has a guaranteed **midpoint relic** beat fixed (`RELIC_BEAT`); every other beat is a **ROLL** beat. An **easy opener** band (`0 .. EASY_BEATS_END`) is forced combat with a draft; from `ELITE_FROM_BEAT` on a rolled combat may be an **elite**. PLACEHOLDER numbers + a tiny pool drawn repeatedly — the owner re-contents (band edges + pools are in `RunMap`).
- **BUILT — the auto-roll (logic).** A ROLL beat **auto-selects its content** — no player choice. The `Run manager` rolls **COMBAT vs EVENT** on the run RNG (deterministic + resume-stable) and draws a def from the matching pool (`combat_pool` / `event_pool`; an empty event pool forces combat). The roll is **anti-repeat biased**: the streaking type's chance is `ROLL_BASE_CHANCE − ROLL_BIAS_STEP × streak` (floored at 0, so a long run is force-broken), reset when the other type lands; the streak is saved so resume reproduces it. *(The old player-pick choice layer — `has_pending_choice` / `pending_choice` / `pick_path` + `choice_overlay` — is **dormant**, kept inert for a possible future fork-beat.)*
- **BUILT — HP economy.** Between-act **full heal** on crossing into a new act; max-HP growth via the granted relics (`MAX_HP_BONUS`). *(The REST encounter — a partial heal — still exists as a def but is no longer a fixed map beat; the owner re-places rests via the pools / events.)*
- The **player run-state** (Actor + relics/potions + position + RNG); auto-save on encounter entry; rehydrate on resume — including the current beat's resolution (the rolled/fixed encounter id + the COMBAT/EVENT streak).
- Report **run-ended (died / won)** up to the `Game manager`.

**Not** in scope yet: the telegraph/map **UI** polish (stage 2), boss **signature mechanics** + the real encounter/enemy content (the owner's).

---

## Open / deferred

- **Act / beat placement — BUILT** (`RunMap`, placeholder); the **1D progress-map UI** (`MapStrip`) shows the track + fixed beats, rolled beats as generic (their type isn't known until arrival). Real band edges/pools are the owner's content.
- **Elite reward asymmetry — BUILT** (elite = relic + draft, #2); an **elite** now appears as a possible rolled-combat outcome from `ELITE_FROM_BEAT` on (it's in the deeper `combat_pool`), not a player engage/skip. Elite frequency/depth is design/tuning (the pool composition).
- **RNG — resolved (#20):** the `Run manager` owns the run RNG; its **full state** is saved (deterministic resume, no save-scum); the per-fight combat stream is derived from the run seed + encounter index.
- **Multi-Actor player side (drafting allies) — deferred (#22):** run-state's `actor` is the player *party* (a roster of 1 today); keep it list-friendly so allies / summoning stay additive — don't hardwire one player actor.
- **Encounter handoff — resolved ([Encounter PRD](encounter.md)):** the `Run manager` instantiates the picked `Encounter` with context (player `Actor` + run-state accessors + RNG + position); a fight `Encounter` spawns its own enemies + ordering and creates the `Combat manager`.
- **Resolved (#15):** the game-state machine is the `Game manager`'s, not here.

## Dependencies

- **Above:** the `Game manager` — creates it (fresh-seeded or rehydrated), reads its **run-ended** signal, owns its lifetime.
- **Calls down to / drives:** `Encounter` (one per beat; fights create a `Combat manager`), `Draft` (on reward), the `Corridor` renderer (advance), `Save` (`write` on encounter entry), `Characters` (read the starting board/relic on a fresh run). Owns + applies HP-economy to the player `Actor`.
- **Does not:** touch the `Timekeeper` / run the combat tick (`Combat manager`); own the game-state machine or save-lifecycle timing (`Game manager`).
