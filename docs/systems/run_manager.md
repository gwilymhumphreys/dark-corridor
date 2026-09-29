# Dark Corridor — Run Manager PRD

Run PRD. Sits under the [Architecture Map](architecture.md). The `Run manager` owns **one descent**: the map, encounter sequencing, the player run-state, and HP-economy policy. It is **instanced per run**, created and owned by the [Game manager](game_manager.md). It sits between **Game (session)** above and the per-fight **Combat manager** below (reached via `Encounter`).

**Engine:** Godot 4.
**Date:** 2026-06-05. Pre-prototype.
**Naming:** `class_name RunManager`, **instanced** (not an autoload) — one per run, created/torn down by the `Game manager`.

Boundaries live in the hub: [architecture.md → Interface contracts → `Run manager`](architecture.md#interface-contracts-boundary-hub). This PRD specifies the *internals*.

---

## Purpose

The `Run manager` is the descent — it walks the player through one run and holds everything that lives exactly that long. It owns:

- **The map** — the linear act/beat structure and the 1D progress track: each act is a row of squares (fights, two elite fights, the relic encounter, the boss at the end) with events between them ([below](#the-act-layout)). Forward-visible, single, no branching ([design](../design/game_design.md)). Counts/placements are design/tuning, not here.
- **Encounter sequencing + the corridor advance** — each beat's encounter is fixed by the map or drawn from its pool on the run RNG (no player choice), and the `Run manager` instantiates it; the next beat is **created after the current reward and approaches from depth** (the advance is its approach), resolving on arrival (a fight `Encounter` creates a `Combat manager`). The cycle is detailed below.
- **The player run-state** — the player `Actor`, run-scoped `allies`, `relics`, `potions`, `position`, `gold`, and the run RNG (plus the `character` id and the current beat's encounter). **`gold`** is a banked run-state resource (decision #33) — its sources are **skipping a draft** and relic run triggers (`RunEffect.gold`); there is **no sink yet** (shops are out of scope). The player `Actor` + any run-scoped **`allies`** (persistent player-side bodies — spore_engine Cap 3) are **run-lifetime**, owned here and seeded into each fight. The player's HP carries (full heal between acts); **allies persist by def id only** — revived to full each fight, so their HP isn't saved. Relics and potions live here too (not on the Actor — [Actor PRD](actor.md)); before each fight `begin_current` builds an `Item` per relic into the player's `Actor.relics` for that fight ([content.md → Relic](content.md#relic)).
- **HP-economy policy** — applies the design's rules *to* the Actor: HP persists between encounters, between-act full heal, rest partial-heals, max-HP growth (relics / events). The Actor just holds the values; the policy is decided here.
- **The starting kit + the player-action surface** — a fresh run is seeded from the chosen `Characters` def (#27): the starting board, signature relic, starting potions + enchants, and the draft pool (the character's pool + colorless). The starting board is drawn by `CharacterCatalog.starting_board`, which reads the character's type constraints and picks one item of each from its own pool on the run RNG — so the opening varies per run but a seed always opens the same way, and the drawn ids are saved on the board like any other item. Run-state mutations route through here — applying a drafted item (`apply_draft_pick`), a picked relic (`apply_relic_pick`) or an enchant (`apply_enchant`) **or skipping the draft to bank gold** (`apply_draft_skip` — the sibling of the pick, decision #33), `throw_potion` to the live fight, and `add_ally` (an `Encounter`'s recruit grant, capped at `MAX_ALLIES`).
- **The run snapshot** — it **builds** the snapshot and calls `Save.write()` on encounter entry, and **rehydrates** run-state from a snapshot on resume.

What it **is not**:

- **Not the session.** The game-state machine, the run-lifecycle decision (start/resume/end), and the save-*lifecycle* timing are the `Game manager`'s. The `Run manager` is created by it and signals **run-ended** back up.
- **Not the fight.** It never touches the `Timekeeper` or runs the combat tick — it hands a fight to an `Encounter` (which owns the `Combat manager`) and awaits the result.
- **Not the `Encounter` internals** (the event prose / binary outcome) or the **`Draft`** internals — it drives them.

---

## The map & sequencing

The run is a single linear track of beats. The `Run manager` walks it as a cycle — the **next beat is created right after the current one's reward and approaches from depth** (the walk *is* the next encounter arriving, not dead time):

1. **Resolve** the current `Encounter`: a fight (→ `Combat manager`, await win/loss) or a non-combat event (binary choice).
2. **Fulfil the reward** it reports — drive a `Draft` (item), grant a relic (elite/boss), offer a choice of relics (the relic encounter), or none; an event's outcome is applied via the run-state surface. On a **fight loss** → **run-ended (died)**; on the **final-boss win** → **run-ended (won)** (the cycle ends).
3. **Set up the next beat** (`RunMap.beat_spec`) — a **fixed** beat (an elite fight, the relic encounter, the boss) names its encounter; a **drawn** beat (a regular fight or an event) draws a def from its pool on the run RNG. The `Encounter` is the resolved unit ([Encounter PRD](encounter.md)).
4. **Create** the next `Encounter` (spawn its actors at the vanishing point) and **auto-save** the run snapshot — encounter entry, the resume point (design).
5. **Advance** the corridor — the encounter **approaches from depth** into full view (the renderer scales it up — `docs/systems/corridors/`; not self-advancing); on **arrival** (front locked at full scale) go to 1 and resolve it.

Act boundaries apply the **between-act full heal** (automatic — design).

Beat placement (the squares, the event rules, the pools) is the map's content; numbers → design/tuning.

### The act layout

**Location:** `src/run/run_map.gd` (`RunMap`).

- Every act is `BEATS_PER_ACT` beats: the `SQUARES` in order (the fights, the relic encounter and the two elite fights the map shows, and the boss last), with `EVENTS_PER_ACT` events placed between them.
- An event may only come straight before one of the squares in `EVENT_GAPS`, one per gap. So an act never opens on an event, no event comes straight before an elite fight, the relic encounter or the boss, and two events never come in a row.
- Which gaps the events take is drawn per act from the run seed (`act_layout`), so the layout is not saved and a resumed run gets the same one.
- The first fights (`EASY_SQUARES_END`) draw from an easy pool. Elite squares are `fight_elite`, and the relic square is `relic_cache`: no fight, and the player picks one of up to `RELIC_OFFER_COUNT` relics from `RelicCatalog.REWARD_POOL` (`pending_relic_offer` / `apply_relic_pick`, shown in the draft panel). Act bosses still grant one random relic.

## Player run-state & RNG

The run-state the snapshot persists is: the player `Actor` (HP + max-HP + board), run-scoped `allies` (def id only), `relics`, `potions`, `position`, `gold` (banked run-state, decision #33 — optional on read, absent → 0, no migration), the `character` id, the current beat's encounter (`current_def_id` + `current_enemy_ids`, the generated fight's drawn enemies — the RNG has already moved past the draw, so a resume cannot redraw them), and the run RNG. The `Run manager` **owns the run RNG** — a single seeded PRNG driving all run-level randomness (draft offers, encounter assembly). Its **full state** (not just the seed) goes in the snapshot, so **reloading a save reproduces the same future outcomes every time** — deterministic resume, and no save-scumming a bad draft by quit-reload ([Save PRD](save.md)). Per-fight combat randomness (e.g. random item-targeting — #14) draws from a **derived per-fight stream** (seeded from the run seed + encounter index), so combat doesn't perturb the run stream and a re-entered fight replays identically.

## Save (snapshot, not timing)

The `Run manager` knows the run-state schema, so it **builds** the snapshot and **writes** it (`Save.write`) on encounter entry, and **rehydrates** from one on resume (the `Game manager` hands it the snapshot read from `Save`). It does **not** decide *when* to load or clear — that timing is the `Game manager`'s. Combat state is never in the snapshot (ephemeral — Save PRD).

---

## Prototype scope

- **BUILT — the multi-act structure (`RunMap`).** A single linear track of `ACTS` × `BEATS_PER_ACT` beats (global `position`; act/beat-within-act derived), each act laid out as in [The act layout](#the-act-layout). The final act's boss wins the run. PLACEHOLDER pools — the owner re-contents them. *(The old player-pick choice layer — `has_pending_choice` / `pending_choice` / `pick_path` + `choice_overlay` — is **dormant**, kept inert for a possible future fork-beat.)*
- **BUILT — HP economy.** Between-act **full heal** on crossing into a new act; max-HP growth via relic run triggers (a `PICKED_UP` entry's `RunEffect.max_hp`, applied once on grant — [content.md → Relic](content.md#relic)). *(The REST encounter — a partial heal — still exists as a def but is no longer a fixed map beat; the owner re-places rests via the pools / events.)*
- The **player run-state** (Actor + allies + relics/potions + position + gold + character + RNG); auto-save on encounter entry; rehydrate on resume — including the current beat's encounter id.
- **BUILT — relic run triggers.** `RunEvent` (`PICKED_UP`, `FIGHT_WON`, `DRAFT_SKIPPED`) and `_fire_run_event` apply the relics' `run_triggers` ([content.md → Relic](content.md#relic)). `FIGHT_LOST` is not an event, because a loss ends the run before a relic could act.
- **BUILT — draft skip → bank gold (decision #33).** `apply_draft_skip()` (sibling of `apply_draft_pick()`) resolves the pending offer by banking a fixed amount of `gold` instead of taking a card (no run RNG draw). **Source only — no sink yet** (shops out of scope). The amount is `Balance.GOLD_SKIP` (placeholder).
- Report **run-ended (died / won)** up to the `Game manager`.

**Not** in scope yet: the telegraph/map **UI** polish (stage 2), boss **signature mechanics** + the real encounter/enemy content (the owner's).

---

## Open / deferred

- **Act / beat placement — BUILT** (`RunMap`, placeholder); the **1D progress-map UI** (`MapStrip`) shows the act's squares with an icon each, and marks the gap during an event ([run_screen.md](run_screen.md#overlays)). Real pools are the owner's content.
- **Elite reward asymmetry — BUILT** (elite = relic + draft, #2); the **elites** are two fixed squares per act (`SQUARES`), not a player engage/skip.
- **RNG — resolved (#20):** the `Run manager` owns the run RNG; its **full state** is saved (deterministic resume, no save-scum); the per-fight combat stream is derived from the run seed + encounter index.
- **Multi-Actor player side (allies) — BUILT (#22):** the player side is a *party* — the player `Actor` + run-scoped **allies** (`register_ally` / `add_ally`, capped at `MAX_ALLIES`; a recruit Event grants one). Allies seed into each fight and are revived to full each fight (HP not saved). Combat-scoped summon tokens are additive on top (spore_engine Cap 3).
- **Encounter handoff — resolved ([Encounter PRD](encounter.md)):** the `Run manager` instantiates the picked `Encounter` with context (player `Actor` + run-state accessors + RNG + position); a fight `Encounter` spawns its own enemies + ordering and creates the `Combat manager`.
- **Resolved (#15):** the game-state machine is the `Game manager`'s, not here.

## Dependencies

- **Above:** the `Game manager` — creates it (fresh-seeded or rehydrated), reads its **run-ended** signal, owns its lifetime.
- **Calls down to / drives:** `Encounter` (one per beat; fights create a `Combat manager`), `Draft` (on reward), the `Corridor` renderer (advance), `Save` (`write` on encounter entry), `Characters` (#27 — seeds the full starting kit on a fresh run: board, signature relic, starting potions + enchants; draft pool = the character's pool + colorless). Owns + applies HP-economy to the player `Actor`.
- **Does not:** touch the `Timekeeper` / run the combat tick (`Combat manager`); own the game-state machine or save-lifecycle timing (`Game manager`).
