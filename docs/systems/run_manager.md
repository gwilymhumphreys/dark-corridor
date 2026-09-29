# Dark Corridor — Run Manager PRD

Run PRD. Sits under the [Architecture Map](architecture.md). The `Run manager` owns **one descent**: the map, encounter sequencing, the player run-state, and HP-economy policy. It is **instanced per run**, created and owned by the [Game manager](game_manager.md). It sits between **Game (session)** above and the per-fight **Combat manager** below (reached via `Encounter`).

**Engine:** Godot 4.
**Date:** 2026-06-05. Pre-prototype.
**Naming:** `class_name RunManager`, **instanced** (not an autoload) — one per run, created/torn down by the `Game manager`.

Boundaries live in the hub: [architecture.md → Interface contracts → `Run manager`](architecture.md#interface-contracts-boundary-hub). This PRD specifies the *internals*.

---

## Purpose

The `Run manager` is the descent — it walks the player through one run and holds everything that lives exactly that long. It owns:

- **The map** — the linear act/beat structure and the 1D progress track: each act is a row of squares (fights, two elite fights, the boss at the end), each with a choice of encounters straight before it ([below](#the-act-layout)). Forward-visible, single, no branching ([design](../design/game_design.md)). Counts/placements are design/tuning, not here.
- **Encounter sequencing + the corridor advance** — a fight's encounter is fixed by the map or drawn from its pool on the run RNG; at a choice beat the `Run manager` draws three encounters and the player picks one or walks past; the `Run manager` instantiates the encounter; the next beat is **created after the current reward and approaches from depth** (the advance is its approach), resolving on arrival (a fight `Encounter` creates a `Combat manager`). The cycle is detailed below.
- **The player run-state** — the player `Actor`, run-scoped `allies`, `relics`, `potions`, `position`, `gold`, the run `flags` and `times_picked`, and the run RNG (plus the `character` id and the current beat's encounter). **`gold`** is a banked run-state resource (decision #33) — its sources are skipping a draft, walking past a choice, winning a fight, and run effects (`RunEffect.gold`, which an event option can also use as a cost); it is spent in shops. **`flags`** (a flag name to a whole number, read with `flag(name)`) and **`times_picked`** (an encounter id to how often it was picked from a choice and finished, counted when it resolves) let an encounter remember what the player did ([encounter.md → Event options](encounter.md#event-options)). The player `Actor` + any run-scoped **`allies`** (persistent player-side bodies — spore_engine Cap 3) are **run-lifetime**, owned here and seeded into each fight. The player's HP carries (full heal between acts); **allies persist by def id only** — revived to full each fight, so their HP isn't saved. Relics and potions live here too (not on the Actor — [Actor PRD](actor.md)); before each fight `begin_current` builds an `Item` per relic into the player's `Actor.relics` for that fight ([content.md → Relic](content.md#relic)).
- **HP-economy policy** — applies the design's rules *to* the Actor: HP persists between encounters, between-act full heal, rest partial-heals, max-HP growth (relics / events). The Actor just holds the values; the policy is decided here.
- **The choice of encounters** — draws the three encounters offered before each fight (`_draw_choice`), applies the pick (`pick_path`) or the walk past (`skip_choice`, banks `Balance.ENCOUNTER_SKIP_GOLD`) ([below](#the-choice-of-encounters)).
- **The starting kit + the player-action surface** — a fresh run is seeded from the chosen `Characters` def (#27): the starting board, signature relic, starting potions + enchants, and the draft pool (the character's pool + colorless). The starting board is drawn by `CharacterCatalog.starting_board`, which reads the character's type constraints and picks one item of each from its own pool on the run RNG — so the opening varies per run but a seed always opens the same way, and the drawn ids are saved on the board like any other item. Run-state mutations route through here — applying a drafted item (`apply_draft_pick`), a picked item, relic or potion (`apply_draft_pick`) or an enchant (`apply_enchant`) **or skipping the draft to bank gold** (`apply_draft_skip` — the sibling of the pick, decision #33), `throw_potion` to the live fight, `add_ally` (capped at `MAX_ALLIES`), and `pick_event_option` (applies the option's run effects through `_apply_run_effect`, then resolves the event; `available_event_options` lists the options whose conditions hold).
- **The run snapshot** — it **builds** the snapshot and calls `Save.write()` on encounter entry, and **rehydrates** run-state from a snapshot on resume.

What it **is not**:

- **Not the session.** The game-state machine, the run-lifecycle decision (start/resume/end), and the save-*lifecycle* timing are the `Game manager`'s. The `Run manager` is created by it and signals **run-ended** back up.
- **Not the fight.** It never touches the `Timekeeper` or runs the combat tick — it hands a fight to an `Encounter` (which owns the `Combat manager`) and awaits the result.
- **Not the `Encounter` internals** (the fight, the rest heal) or the **`Draft`** internals — it drives them.

---

## The map & sequencing

The run is a single linear track of beats. The `Run manager` walks it as a cycle — the **next beat is created right after the current one's reward and approaches from depth** (the walk *is* the next encounter arriving, not dead time):

1. **Resolve** the current beat: at a choice beat, the player picks an encounter (`pick_path`, which creates it and re-saves) or walks past (`skip_choice`, no encounter); then the `Encounter` resolves — a fight (→ `Combat manager`, await win/loss), an event (the player picks an option, whose effects the `Run manager` applies), a rest or the relic encounter.
2. **Fulfil the reward** it reports — a fight won first gives `Balance.FIGHT_WON_HEAL` health and `Balance.FIGHT_WON_GOLD` gold (recorded in `last_fight_gain` for the draft panel), then its reward: drive a `Draft` (item), grant a relic (elite/boss), offer the goods of a reward encounter, open a shop, or none. A fight's draft and a reward encounter's goods are the same pending offer (`pending_draft`, a mix of item, relic and potion definitions); either can be skipped for gold (`apply_draft_skip`). On a **fight loss** → **run-ended (died)**; on the **final-boss win** → **run-ended (won)** with no fight-won gain (the cycle ends).
3. **Set up the next beat** (`RunMap.beat_spec`) — a **choice** beat draws its three encounters; a **fixed** beat (an elite fight, the boss) names its encounter; a **drawn** beat (a regular fight) draws a def from its pool on the run RNG. The `Encounter` is the resolved unit ([Encounter PRD](encounter.md)).
4. **Create** the next `Encounter` (spawn its actors at the vanishing point), or hold the choice's offer, and **auto-save** the run snapshot — encounter entry, the resume point (design).
5. **Advance** the corridor — the encounter **approaches from depth** into full view (the renderer scales it up — `docs/systems/corridors/`; not self-advancing); on **arrival** (front locked at full scale) go to 1 and resolve it.

Act boundaries apply the **between-act full heal** (automatic — design).

Beat placement (the squares, the event rules, the pools) is the map's content; numbers → design/tuning.

### The act layout

**Location:** `src/run/run_map.gd` (`RunMap`).

- The run is `ACTS` acts (one for now, owner 2026-09-30). Every act is the `SQUARES` in order (fights, two elite fights, the boss last), and every square is a fight.
- Every square has a choice beat straight before it, the first fight included, so an act is `BEATS_PER_ACT` beats: a choice at each even beat in the act, and the square at the odd beat after it. The layout is fixed; `square_at`, `is_choice_beat` and `fight_number` read it.
- The first fights (`EASY_SQUARES_END`) draw from an easy pool. Elite squares are `fight_elite`. Act bosses grant one random relic.
- The fight points target (`target_points`) counts fights (`fight_number`), not beats, so a choice beat takes the target of the fight after it.

### The choice of encounters

**Location:** `RunManager._draw_choice`, the lists in `src/content/encounters/encounter_pools.gd` (`EncounterPools`). Plan and later stages: [`../plans/encounter_choice.md`](../plans/encounter_choice.md).

- `EncounterPools` holds one list of encounter ids per card position, left to right. Each encounter goes in one list. The left list is for shops and is empty until shops exist. An encounter in no list is never offered.
- The draw takes one encounter per position from its own list on the run RNG, weighted by `EncounterDef.offer_weight` (rarity and the rules built from the player's state — [encounter.md](encounter.md#offer-rules)), never offering the same encounter twice and never one whose requirements fail. A position whose list has nothing left takes one from the other lists, so the offer is three whenever three encounters exist; only then is a position left `''`. With nothing to offer, the beat is skipped with a warning.
- `pick_path(index)` makes the picked encounter the beat and re-saves. `skip_choice()` banks `Balance.ENCOUNTER_SKIP_GOLD` and leaves the beat with no encounter, so the caller advances to the fight.
- **The relic pool** (`relic_pool()`) is `RelicCatalog.REWARD_POOL` without the relics the player holds. Boss and elite grants and reward encounters draw from it, so the player never gets the same relic twice. It is worked out from the relics held, so it is not saved.
- The left position holds the shops (the placeholder `shop_pedlar`). An open shop (`has_open_shop`, `shop_goods`, `buy`, `leave_shop`) is described in [encounter.md → Shops](encounter.md#shops).
- A reward encounter (such as the placeholder `relic_cache`, three relics) is one of the encounters offered: no fight, and the player picks one of the goods drawn from its stock in the draft panel ([encounter.md → Reward encounters](encounter.md#reward-encounters)).

## Player run-state & RNG

The run-state the snapshot persists is: the player `Actor` (HP + max-HP + board), run-scoped `allies` (def id only), `relics`, `potions`, `position`, `gold` (banked run-state, decision #33 — optional on read, absent → 0, no migration), `flags` and `times_picked` (optional on read), the `character` id, the current beat (`current_def_id` + `current_enemy_ids`, the generated fight's drawn enemies, or at a choice beat `pending_choice`, the offered encounters — the RNG has already moved past either draw, so a resume cannot redraw them), and the run RNG. The `Run manager` **owns the run RNG** — a single seeded PRNG driving all run-level randomness (draft offers, encounter assembly). Its **full state** (not just the seed) goes in the snapshot, so **reloading a save reproduces the same future outcomes every time** — deterministic resume, and no save-scumming a bad draft by quit-reload ([Save PRD](save.md)). Per-fight combat randomness (e.g. random item-targeting — #14) draws from a **derived per-fight stream** (seeded from the run seed + encounter index), so combat doesn't perturb the run stream and a re-entered fight replays identically.

## Save (snapshot, not timing)

The `Run manager` knows the run-state schema, so it **builds** the snapshot and **writes** it (`Save.write`) on encounter entry, and **rehydrates** from one on resume (the `Game manager` hands it the snapshot read from `Save`). It does **not** decide *when* to load or clear — that timing is the `Game manager`'s. Combat state is never in the snapshot (ephemeral — Save PRD).

---

## Prototype scope

- **BUILT — the map (`RunMap`).** A single linear track of `ACTS` × `BEATS_PER_ACT` beats (global `position`; act/beat-within-act derived), each act laid out as in [The act layout](#the-act-layout). The final act's boss wins the run. PLACEHOLDER pools — the owner re-contents them.
- **BUILT — the choice of encounters before each fight (stages 1 and 2 of [`../plans/encounter_choice.md`](../plans/encounter_choice.md)).** The three positions, the draw weighted by rarity and the rules built from the player's state, the walk past for gold, the fight-won health and gold, and the offer in the snapshot. Stage 3 added the event option effects and conditions, the run flags and the pick counts. Rewards and shops are the later stages.
- **BUILT — HP economy.** Every fight won heals `Balance.FIGHT_WON_HEAL`; between-act **full heal** on crossing into a new act; max-HP growth via relic run triggers (a `PICKED_UP` entry's `RunEffect.max_hp`, applied once on grant — [content.md → Relic](content.md#relic)). The REST encounter (a partial heal) is one of the encounters offered before a fight.
- The **player run-state** (Actor + allies + relics/potions + position + gold + character + RNG); auto-save on encounter entry; rehydrate on resume — including the current beat's encounter id.
- **BUILT — relic run triggers.** `RunEvent` (`PICKED_UP`, `FIGHT_WON`, `DRAFT_SKIPPED`) and `_fire_run_event` apply the relics' `run_triggers` ([content.md → Relic](content.md#relic)). `FIGHT_LOST` is not an event, because a loss ends the run before a relic could act.
- **BUILT — draft skip → bank gold (decision #33).** `apply_draft_skip()` (sibling of `apply_draft_pick()`) resolves the pending offer by banking a fixed amount of `gold` instead of taking a card (no run RNG draw). The amount is `Balance.GOLD_SKIP` (placeholder).
- Report **run-ended (died / won)** up to the `Game manager`.

**Not** in scope yet: the telegraph/map **UI** polish (stage 2), boss **signature mechanics** + the real encounter/enemy content (the owner's).

---

## Open / deferred

- **Act / beat placement — BUILT** (`RunMap`, placeholder); the **1D progress-map UI** (`MapStrip`) shows the act's squares with an icon each, and marks the gap during a choice of encounters and the encounter picked from it ([run_screen.md](run_screen.md#overlays)). Real pools are the owner's content.
- **Elite reward asymmetry — BUILT** (elite = relic + draft, #2); the **elites** are two fixed squares per act (`SQUARES`), not a player engage/skip.
- **RNG — resolved (#20):** the `Run manager` owns the run RNG; its **full state** is saved (deterministic resume, no save-scum); the per-fight combat stream is derived from the run seed + encounter index.
- **Multi-Actor player side (allies) — BUILT (#22):** the player side is a *party* — the player `Actor` + run-scoped **allies** (`register_ally` / `add_ally`, capped at `MAX_ALLIES`; a recruit Event grants one). Allies seed into each fight and are revived to full each fight (HP not saved). Combat-scoped summon tokens are additive on top (spore_engine Cap 3).
- **Encounter handoff — resolved ([Encounter PRD](encounter.md)):** the `Run manager` instantiates the picked `Encounter` with context (player `Actor` + run-state accessors + RNG + position); a fight `Encounter` spawns its own enemies + ordering and creates the `Combat manager`.
- **Resolved (#15):** the game-state machine is the `Game manager`'s, not here.

## Dependencies

- **Above:** the `Game manager` — creates it (fresh-seeded or rehydrated), reads its **run-ended** signal, owns its lifetime.
- **Calls down to / drives:** `Encounter` (one per beat; fights create a `Combat manager`), `Draft` (on reward), the `Corridor` renderer (advance), `Save` (`write` on encounter entry), `Characters` (#27 — seeds the full starting kit on a fresh run: board, signature relic, starting potions + enchants; draft pool = the character's pool + colorless). Owns + applies HP-economy to the player `Actor`.
- **Does not:** touch the `Timekeeper` / run the combat tick (`Combat manager`); own the game-state machine or save-lifecycle timing (`Game manager`).
