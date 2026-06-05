# Dark Corridor — Architecture Map & Foundation Spec
 
> **Companion to the design and art docs.** This is the high-level system map plus a settled spec for the foundation layer. It is *not* per-system implementation detail — those are separate PRDs, written one at a time as systems get built. This pass exists to nail the interfaces and dependencies before any single system is spec'd in depth.
 
**Engine:** Godot 4.
**Date:** 2026-06-03 (revised 2026-06-05). Pre-prototype.
 
---
 
## Principles (apply across all systems)
 
- **Autoloads are session-or-global singletons; per-instance state is instantiated.** `StatusManager` (rules), `Save` (service), and `Draft` (the reward draw) are stateless autoloads; the **`Game manager`** is a *session-lifetime* singleton autoload (registered `Game`) holding the game-state machine + a reference to the live run. The rule it respects: anything with **shorter, instance lifetime** — actors, items, boards, statuses, Deliveries, the per-combat `Timekeeper`, and the **per-run `Run manager`** — is instantiated, not autoloaded (it must be *fresh* each fight/run). A session singleton holding session state is consistent (the lifetimes match); per-run/per-fight state never migrates up into it.
- **No `_ready` / `_process` outside pure-visual leaf scenes.** Logic advances off explicit ticks/calls — in combat, the `Combat manager`'s fixed-step tick — not per-node process functions. Self-animation is only allowed for purely cosmetic motion that never needs to honour slow-mo (ambient/background).
- **One clock, fixed timestep.** Combat runs in fixed steps. The `Timekeeper` (one per fight) is the combat clock — the time source + the one speed dial + the step cadence; the `Combat manager` advances every component on each step. Slow-mo / pause / fast-test / battle-speed are all *the same dial* — and the dial controls *how many fixed steps run per real second*, not a per-step delta. (Fixed steps → deterministic, reproducible, bit-identical autotest.)
- **Output is a pure function of handed state.** The renderer / VFX / audio layer never tracks animation state or holds its own clock. Every position / frame / sound it produces is computed from data (state + elapsed time on the clock) and handed to it. It **writes no game state**; its only coupling upward is *reading* the clock (`render_time`). Player **input** is a separate inbound layer — see *Presentation & input*.
- **Symmetric actors.** Player and enemies are the same `Actor` type; the only asymmetry is how a board is *assembled* (the player drafts; enemy boards are authored), which happens before the fight — in combat both sides auto-fire identically. We should be able to put characters-with-items on either side. This is a constraint on the abstraction (don't bake in side-specific assumptions), not a feature we intend to use.
---
 
## System map
 
Layers depend *downward* only for **structural** ownership (who creates / holds / knows whom). Completion **signals** travelling back up — a `Combat manager` telling its `Encounter` the fight is won — are normal events, not dependencies, and aren't counted here. The boundary held strict is **output → logic**: the renderer / VFX / audio layer writes no game state (it only reads, including the clock). Player **input** is a separate inbound layer — the `UI` emits *intents* that logic interprets, never mutating state directly. Both are detailed under *Presentation & input*.
 
### Foundation (depends on nothing above)
 
- **`Timekeeper`** (instanced — one per fight, owned by the `Combat manager`) — the combat **clock**: a stepped `sim_time` + a continuous `render_time` (for the visual wall) + the one speed dial + the fixed-step cadence (`steps_due`: real time × dial → whole steps, capped, backlog dropped). It does **not** hold the component registry or advance components — the `Combat manager` does, on the clock's step. Fixed timestep → deterministic and reproducible (the autotest runs K steps). Built at combat start, torn down at end.
- **`StatusManager`** (autoload) — **stateless** rules for statuses: `(target, count/stacks, behaviour)`, where target is an actor *or* an item. Status *instances* live on their targets (Actor / Item), not here; the `Combat manager` advances their Tickers each step (on the `Timekeeper`'s clock). Called by items, relics, consumables, enemy abilities to apply/read. Depends on nothing — a global rulebook holding no per-fight state.
- **`Actor`** (instanced) — HP, a board of items, a status list. Knows nothing about which side it's on.
- **`Save`** (autoload) — persists a run snapshot it's *handed* on encounter entry, and returns it on load; the `Run manager` writes it, the `Game manager` reads it back on launch, the `Run manager` rehydrates. **Push, not pull** — `Save` reads no live state and writes none back. No migration (`CLAUDE.md`).
### Content → Foundation
 
- **`Item`** → `StatusManager` (apply / read statuses); reads its owner `Actor` (self-target, board membership). It declares a target-*shape*; the `Combat manager` resolves it and lands the Delivery — no direct `Item → Actor` damage call.
- **`Enchantment`** (a `Draftable`) → modifies its host `Item`; drafted/inspected like the others, but applied to a chosen item on pick (no slot of its own).
- **`Relic`** → `StatusManager` and/or direct `Actor` modification. A relic rides the shared accrual engine like everything else — a *triggered* relic owns an event-push Ticker (Combat PRD), a *timed* effect can be applied as a status — so it needs no special `Timekeeper` handling.
- **`Consumable`** → shares Item's *resolution* surface (spawns a Delivery) but carries no Ticker — manually activated.
- **`Enemy`** → not a class — an `Actor` built from an authored *enemy definition* (HP + an authored board of enemy-pool Items + tier + optional boss signature), spawned by `Encounter`. No enemy AI; no special arrows. See [enemy_prd.md](enemy_prd.md).
(Item / Relic / Enchantment / Consumable share the **Draftable** base — see design doc; Relic / Enchantment / Consumable internals: [content_prd.md](content_prd.md).)
 
### Session (top of the tree) → Run

- **`Game manager`** (autoload, registered `Game`) — the session singleton: the **game-state machine** (title → run → death → meta), the **run lifecycle** (start fresh / resume from `Save` / end on death-win — creates & holds the `Run manager`), and the **save-lifecycle** calls (`read` on launch, `clear` on death/win, the meta-save). Reachable everywhere (`Game.*`) for scene transitions, quit-to-menu, pause. Holds session state + a reference to the live run (null between runs) — never per-run state itself (that's the `Run manager`'s).

### Run structure → Content + Foundation
 
- **`Draft`** (stateless service, autoload) → produces the 1-of-3 reward offer; *pulls* from the pool (`Meta`'s contents), **weighting by depth only** (no hidden build/archetype weighting — design), seeded by the run RNG. The `Run manager` holds the offer + applies the pick.
- **`Encounter`** (instanced, one per beat, created by the `Run manager`) → the per-beat orchestrator: a **fight** (spawns the enemy `Actor`s in left-to-right order + creates the `Combat manager`, awaits win/loss), a **non-combat event** (prose + a binary choice), or an in-act **rest** (partial heal). Reports its outcome + reward-kind up; the `Run manager` fulfills the reward (drives `Draft` / grants a relic). It resolves a beat — it does **not** assemble the choice-layer options (`Run manager`).
- **`Combat manager`** (instanced, one per fight) → owns the live fight: the player + enemy `Actor`s and their left-to-right ordering, the **component registry**, the in-flight Deliveries, win/loss detection, and the runtime targeting authority (answers "leftmost living enemy" for the Combat PRD's rule). Owns the `Timekeeper` (the combat clock) and the **fixed-step tick** — its `_physics_process` runs `steps_due` sim-steps; each step advances every registered component, then orchestrates fire/land/events/win-loss. Registers/deregisters components as items fire and effects resolve. Created by `Encounter`; signals its result back up. It *orchestrates* — no combat decisions (boards auto-fire on their Tickers).
- **`Run manager`** (instanced, one per run, created/owned by the `Game manager`) → owns the **map** (act/boss/rest placement + the 1D progress track), **encounter sequencing** + the corridor advance, the **player run-state** (Actor + relics + potions + position + run RNG), and **HP-economy policy** (between-act full heal, rests, max-HP growth). **Writes** the run snapshot to `Save` on encounter entry; **rehydrates** on resume. Does **not** own the game-state machine (`Game manager`) or touch the `Timekeeper` (`Combat manager`) — it **assembles the choice-layer candidates** (a pool-draw under act constraints + RNG), instantiates the picked `Encounter`, awaits its result, and **fulfills its reward** (drives `Draft` / grants the relic).
- **`Corridor/advance`** → driven by the `Run manager`; the advance **doubles as the next encounter's approach** — the `Encounter` is created after the reward and its enemies scale up from depth into full view, resolution beginning on arrival.
### Meta → Run
 
- **`Meta-progression`** → owns the *contents* of the draft pool (unlocks). `Draft` pulls from the pool; meta does not reach into draft internals. Dependency points down.
- **`Characters`** → seeds the run's starting actor board + relic.
### Presentation & input
 
Two layers the downward rule treats differently:
 
- **Output — `renderer / VFX driver / audio`** → a pure function of handed state. Reads actor / item / status / Delivery state to draw and sound; **writes no game state**. Its one read-up is the clock (`render_time`): the `VFX driver` samples it together with the `Combat manager`'s Delivery set (fire / impact timestamps) to place projectiles and impacts. This is the wall.
- **Input — `UI`** → captures player commands and emits **intents**; logic interprets them, UI never mutates state directly. Normal inbound control flow, not a smell. The intents:
  - **hover / throw** → timescale intent → the `Combat manager` sets its `Timekeeper`'s dial (slow-mo).
  - **throw potion** → fire-consumable intent → the `Combat manager` activates the consumable.
  - **draft pick** → the `Run manager` / `Draft` adds the chosen Draftable to the board / relics / potion slots.
  - **choice-point pick** → the `Run manager` instantiates the chosen candidate `Encounter`.
  - **event-option pick** → the live `Encounter` applies the chosen outcome (via the `Run manager`'s run-state surface).
  - *(Test hook: an **autotest driver** emits these same intents headlessly — the input layer is the seam the harness drives. See [testing/autotest.md](../testing/autotest.md).)*
---
 
## The Draftable contract

`Draftable` is **what a draft can offer** — expressed as **composition, not a parent class** (same instinct as the Ticker and Status: share the engine, keep identities distinct). It is a **definition-level contract**, not a runtime supertype:

- **Shared definition-face.** Every content definition (item / relic / consumable / enchant) carries a common header — `id`, `name`, `icon`, `rarity`, `category`, `tooltip` — by composition (the def *has* it; it doesn't *inherit* it). The `category` set is **open** — a new kind is additive.
- **`Draft` + inspection are category-blind.** They read only that header to offer, rarity/depth-weight, and tooltip — never branching on category to draw or show.
- **Application dispatches on `category`** — the one category switch, owned by the `Run manager`: item → board, relic → relics, consumable → potion slot, enchant → a chosen item.
- **Runtime entities stay distinct types.** `Item` owns a Ticker + board membership; `Relic` is run-state; `Enchantment` lives on an item; `Consumable` is hand-fired. None inherits a `Draftable` runtime class — they share the draft-time *face*, not a runtime base.

---

## Interface contracts (boundary hub)
 
The canonical reference for cross-system **edges**. Per-system PRDs link here for their boundaries instead of re-declaring them — the system map above is the narrative version; this is the concrete public surface each system exposes and the edges it sits on. Entries are added as each system gets PRD'd. **Absence here means "not yet specced," not "no boundary."**
 
### `Timekeeper` — PRD: [timekeeper_prd.md](timekeeper_prd.md)
 
- **Exposes:**
  - *`sim_time`* (stepped) — logic + event timestamps (fire / impact) read it. *`render_time()`* (continuous) — the VFX/audio wall reads it; smooth between steps.
  - *Timescale dial* — the one scalar (battle-speed ×1/×2/×3, hover slow-mo ~×0.05, pause ×0, fast-test ×5+). Set via intent, never by UI directly.
  - *`steps_due(real_delta) → int`* — accumulate `real_delta × dial`, drain whole `STEP`s (cap `MAX_STEPS`, drop backlog) → how many sim-steps to run; *`advance()`* — `sim_time += STEP`.
- **Inbound (who calls the `Timekeeper`):**
  - `Combat manager` → creates it at combat start; each `_physics_process` calls `steps_due` then `advance` per sim-step; sets `timescale` (from a UI intent it interprets); tears it down at exit. (The `Run manager` never touches it.)
  - `UI` → a timescale *intent* (hover slow-mo, throw) reaches the `Combat manager`, which sets this instance's dial; UI never writes it directly. *(Input intent — see Presentation & input.)*
- **Outbound:** none — a passive clock. Read by logic (`sim_time`) and the VFX/audio wall (`render_time()`).
- **Does not:** hold the component registry or advance components (the `Combat manager` does); run a loop / `_physics_process`; own the game-state machine, the targeting rule, or game state.
 
### `Combat manager` — PRD: [combat_manager_prd.md](combat_manager_prd.md)
 
- **Exposes:** the live fight — the actor pair + left-to-right ordering, the in-flight Delivery set, the **leftmost-living-enemy** query and **random enemy-item** selection (runtime authority for the Combat PRD's targeting rules), and a *resolved (win/loss)* signal.
- **Inbound:** `Encounter` creates it with the player + spawned enemy `Actor`s. `UI` → input-intents during the fight (timescale: hover slow-mo / throw; throw-potion), which it interprets — never a direct state write.
- **Outbound:** **creates and owns** the `Timekeeper` (the combat clock) and the **component registry**; runs the **fixed-step tick** (`_physics_process` → `steps_due` sim-steps; each advances every registered component, then fires/lands/routes/win-loss); registers components returned from a component's step / `StatusManager.apply()` and deregisters resolved ones; reads/writes `Actor`s (apply damage, check death); resolves each fired payload's target-shape into a Delivery; runs the trigger **event bus** (routes fires / applications / damage to push trigger items); applies the Combat PRD's resolution + targeting rules. (Headless autotest drives `sim_step()` directly.)
- **Lifetime:** one per fight. Keeps resolved-but-still-animating Deliveries until their visual's max duration elapses, then drops them — so the `VFX driver` can read `now − impact_time` after the damage has already landed. Torn down at combat end.
- **Does not:** make combat *decisions* (boards auto-fire on their Tickers); sequence the run (`Run manager`); persist (`Save`).
 
### `Actor` — PRD: [actor_prd.md](actor_prd.md)
 
- **Exposes:** `hp` (current / max) + `is_alive()` + a `died` signal; the **board** (its item instances — their Tickers are what the `Combat manager` registers and advances each step); the **status list** (actor-targeted statuses); a small mutation surface — `take_damage` / `heal`, add/remove item, add/remove status.
- **Inbound (who acts on it):** Deliveries / `Item` (damage / heal on arrival); `StatusManager` (apply/read statuses); `Relic` (direct modification); `Characters` / `Run manager` (create + seed the player Actor, max-HP growth, full heal between acts); `Combat manager` (reads the board to register Tickers, reads `is_alive` for win/loss).
- **Outbound:** only a sideways call to `StatusManager` (resolve damage-modifier statuses in `take_damage`); otherwise none. Emits `died`; the `Combat manager` reads it.
- **Does not:** know its side; order itself or do targeting (`Combat manager`); own item *behaviour* (it stores items; the `Combat manager` advances their Tickers each step) or status *rules* (`StatusManager`).
 
### `StatusManager` — PRD: [status_manager_prd.md](status_manager_prd.md)
 
- **Exposes:** `apply(target, type, count, source?) → instance` (resolves source-side application modifiers, applies the stacking policy, returns the instance for the `Combat manager` to register, emits an on-apply event); `resolve_incoming_damage(target, raw, flags) → net` (amplifiers then absorbers — block); read helpers (`type → icon/colour/name`, query a target's statuses). **Stateless** — holds no instances.
- **Inbound:** `Item` / `Relic` / `Consumable` / `Enemy` abilities → `apply` / read; `Actor.take_damage` → `resolve_incoming_damage`.
- **Outbound:** none — a rulebook. Status *instances* live on targets; their Tickers are advanced by the `Combat manager` each step (registered from `apply`'s return).
- **Does not:** hold instances or per-fight state; advance components (the `Combat manager` does, on the `Timekeeper`'s clock); author effect content; deliver triggers (the Combat/Item PRD's accrual-push).
 
### `Item` — PRD: [item_prd.md](item_prd.md)
 
- **Exposes:** a data-configured board participant owning a `Ticker` (combat_prd). On fire it produces **payload(s)** — `(kind, value)` — each with a *relative* target-shape (self / opponent-leftmost / all-opponents / opponent-item-random / all-opponent-items), **not** a resolved target; the `Combat manager` turns each into a **Delivery**. Declares trigger conditions + emits events (on-fire, …). One enchant slot; holds item-targeted statuses. Every item is active (its accumulator fills as the clock steps); triggers are an additional event-push input on the *same* accumulator (it still ticks), not a separate type — and there is no passive item type (passive effects are statuses).
- **Calls down to:** `StatusManager` (apply statuses on resolve; read its own gate/value statuses). **Reads** its owner `Actor` (self-target, board membership).
- **Driven by (above):** the `Combat manager` — registers the item's Ticker in its registry, collects fired payloads (resolves shape → target, spawns the Delivery), routes events to push trigger items. The item returns / emits; it never calls up.
- **Does not:** resolve its own target or Deliveries (`Combat manager` + combat_prd); tick itself (`Timekeeper`); own status rules (`StatusManager`); draw (presentation reads its panel/cooldown). Shares the `Draftable` base with `Relic` / `Enchantment` / `Consumable`.
 
### `Save` — PRD: [save_prd.md](save_prd.md)
 
- **Exposes:** `write(snapshot)` (persist the run snapshot, atomic), `read() → snapshot?` (the saved run, or none), `clear()` (drop the run save on death/win). Stateless service — holds no live state.
- **Inbound:** the `Run manager` → `write` on encounter entry; the `Game manager` → `read` on launch, `clear` on death/win, and the meta-save.
- **Outbound:** none — `Save` never writes back into live systems; on load it *returns* the snapshot, the `Game manager` reads it back, and the `Run manager` rehydrates.
- **Does not:** decide *when* to save (the `Run manager` writes per-encounter; the `Game manager` owns load/clear timing); read live state itself (push, not pull); persist combat state (ephemeral) or meta-progression (a separate dataset — Meta PRD); migrate saves (`CLAUDE.md` — incompatible → fresh run).

### `Game manager` — PRD: [game_manager_prd.md](game_manager_prd.md)

- **Exposes:** the **game-state machine** (current phase/screen + transitions) and the run lifecycle — `start_run(character)`, `resume_run()` (from `Save`), `end_run(outcome)`; a session singleton reachable as `Game.*` (scene transitions, quit-to-menu, pause). Holds a reference to the live `Run manager` (null between runs).
- **Inbound:** app launch (boot → title / resume); the `Run manager` signals **run-ended (died / won)**; `UI` → menu / title / restart intents.
- **Outbound:** creates & tears down the `Run manager` (seeds fresh via `Characters`, or rehydrates from a snapshot); `Save.read()` on launch + `Save.clear()` on death/win + the meta-save; drives screen transitions.
- **Does not:** own per-run state (the `Run manager` does); sequence encounters or touch the map (`Run manager`); touch the `Timekeeper` or combat (`Combat manager`).

### `Run manager` — PRD: [run_manager_prd.md](run_manager_prd.md)

- **Exposes:** the live **run** — the map (act/beat structure + the 1D progress track), the current position, and the **player run-state** (`{ actor, relics, potions, position, rng }`); a **run-ended (died / won)** signal up to the `Game manager`. Builds the `Save` snapshot and rehydrates from one.
- **Inbound:** the `Game manager` creates it (fresh-seeded or rehydrated) and reads its run-ended signal; `Encounter` signals each beat's result back up; `UI` → draft-pick / advance intents.
- **Outbound:** sequences `Encounter`s along the map (each fight `Encounter` creates a `Combat manager`); drives the corridor advance; applies HP-economy policy to the player `Actor`; `Save.write(snapshot)` on encounter entry; fulfills the `Encounter`'s reward (drives `Draft` / grants the relic); reads `Characters` for the starting board/relic.
- **Does not:** own the game-state machine or the save-lifecycle *timing* (`Game manager`); touch the `Timekeeper` or run the combat tick (`Combat manager`); decide combat outcomes (it awaits them).

### `Encounter` — PRD: [encounter_prd.md](encounter_prd.md)

- **Exposes:** one resolved **beat** — its type (fight / event / rest), its telegraph, and a **result** (died / won / resolved) + reward-kind, signalled up to the `Run manager`. A fight Encounter creates and owns its `Combat manager`.
- **Inbound:** the `Run manager` instantiates it from a picked candidate definition with context (player `Actor` + run-state accessors + RNG + position); `Combat manager` signals win/loss back up; `UI` → event-option pick intent.
- **Outbound:** spawns enemy `Actor`s (from enemy definitions) in left-to-right order and creates the `Combat manager` (fight); applies event/rest outcomes via the `Run manager`'s run-state surface; reports outcome + reward up (the `Run manager` drives `Draft` / grants the relic).
- **Does not:** assemble the choice-layer candidates (`Run manager`); own the map / run-state / game-state; run the combat tick (`Combat manager` / `Timekeeper`).

### `Draft` — PRD: [draft_prd.md](draft_prd.md)

- **Exposes:** `draw(pool, run_state, rng) → candidates` — the 1-of-3 reward offer (slot composition + depth-weighting + seeded pull). Stateless — holds no offer.
- **Inbound:** the `Run manager` → `draw` on a reward; reads the draft **pool** (`Meta-progression`'s contents) + run-state depth + the run RNG (handed in).
- **Outbound:** none — returns candidates. The `Run manager` holds the pending offer and applies the pick (board / potion / enchant-target / relic).
- **Does not:** own the pool contents (`Meta-progression`); hold the offer or apply the pick (`Run manager`); weight by build/archetype (depth/rarity only — design's no-hidden-weighting); present (`UI`).

### `UI` — PRD: [ui_layout_prd.md](ui_layout_prd.md)

- **Exposes:** the screen — the corridor/combat scene, the item boards (player + enemy), potions, portrait + HP, and the choice / draft / 1D-map screens; emits player **intents**.
- **Inbound:** *reads* actor / board / item / status / potion + run-state to draw (composes over the corridor renderer + the `VFX driver` wall).
- **Outbound (intents only):** timescale + throw-potion → `Combat manager`; draft-pick + choice-point pick → `Run manager`; event-option pick → the live `Encounter`. **Never mutates game state directly.**
- **Does not:** decide outcomes (logic interprets intents); render the combat wall (`VFX driver`); hold game state.

### `VFX driver` — PRD: [vfx_driver_prd.md](vfx_driver_prd.md)

- **Exposes:** nothing to logic — it's the **wall**: each frame it computes projectile / impact / number / pulse positions and fires SFX one-shots, all as pure functions of stored timestamps.
- **Inbound:** none writes to it; it *reads* the `Combat manager`'s in-flight Delivery set (fire / impact timestamps + payload colour) + actor / item / status state, and the `Timekeeper`'s `render_time()`.
- **Outbound:** none — **writes no game state** (renders; the renderer paints what it computes).
- **Does not:** decide outcomes or timing (`Combat manager`); hold a clock (`Timekeeper`); cause damage (the Delivery's landing does); render the corridor (`docs/corridors/`).

### `Content` (Relic · Enchantment · Consumable) — PRD: [content_prd.md](content_prd.md)

- **Exposes:** three run-level categories, data-defined and thin: a **`Relic`** (persistent modifier — combat-start status / triggered Ticker / direct mod), an **`Enchantment`** (one-per-item modifier hooking the host `Item`'s fire/resolve), a **`Consumable`** (manually-fired reserve — a Delivery on throw, no Ticker).
- **Inbound:** the `Run manager` holds them in run-state, applies a drafted pick (relic → relics, enchant → chosen item, potion → slot) and grants relics on reward; `Draft` offers them; `Save` persists them; the `Combat manager` activates a thrown consumable (throw-potion intent).
- **Outbound:** `StatusManager.apply` (relic/enchant statuses); the `Combat manager`'s event bus (a triggered relic's Ticker; a consumable's Delivery); the host `Item`'s pipeline (enchant hooks); direct `Actor` mods (relics).
- **Does not:** introduce new combat mechanics (all route through existing systems); act as a board `Item`; own the draft draw or the reward grant (`Draft` / `Run manager`). Relic, Enchantment + Consumable share the `Draftable` base with `Item` (Enchantment differs only in application — it attaches to a chosen item).
 
---
 
## The combat spine (settled)
 
This is the core that everything else hangs off. Specified here because the prototype is built directly on it.
 
### The tick
 
The `Combat manager` runs the combat loop on a **fixed timestep**; the `Timekeeper` is the clock it advances. The loop lives in `_physics_process`: the `Timekeeper`'s `steps_due` turns real time × the dial into a whole number of fixed **sim-steps**, and the manager runs that many. Each **sim-step**:
 
1. Advance the clock one `STEP` and advance every registered component one step (cooldowns, statuses, Delivery travel); collect the crossings. A component's step may **return newly-spawned components** (a firing item → a Delivery); the manager registers those — content never reaches *up*.
2. Fire the crossed items / statuses, land completed Deliveries, route events (a push fires *next* step — one link per step), check win/loss.
No entity has its own `_process`. Fixed steps make the cascade deterministic and reproducible (the autotest runs K steps); speed is the dial = steps-per-real-second, not a per-step delta.
 
### Timescale as one dial
 
A single scalar drives all of: slow-mo-on-hover (~×0.05), pause (×0), fast-test (×5+), and a player-facing battle-speed setting (×1 / ×2 / ×3). They are not separate features — the dial sets *how many fixed sim-steps run per real second* (not a per-step delta).
 
- There is a **base speed** (player setting) and a **momentary override** (hover slow-mo). Hover overrides the base while active and returns *to the base*, not to ×1. The "what does the scalar return to" logic is a small combat-PRD detail — flag, not solve. *(TBD: override replaces vs. multiplies.)*
### Effect resolution — pointer
 
How items resolve (the Ticker accrual primitive, fire / Delivery, travel timing, trigger model) is the combat system's model and is now settled — see the **Combat PRD**. The only foundation-level facts the rest of the architecture leans on: Deliveries resolve on the fixed-step tick, and `travel_time` may be zero (instant Deliveries are the zero case, not a special path).
 
### Visuals and time (the wall)
 
The renderer draws only handed state and holds no clock of its own.
 
- **Projectiles**: position is a pure function of `time_since_fire` on the continuous `render_time` clock. The VFX driver computes it; the renderer paints it. Smooth at any speed (slow-mo glides) because `render_time` is continuous even though sim-steps are discrete.
- **Impact visuals** (flash/particle on landing): a pure function of `time_since_impact`. The Delivery stores its `impact_time` (a sim timestamp); any frame samples `render_time − impact_time`. **Nothing tracks or steps animation state** — this is the same stateless pattern as projectiles, applied once more. Impact visuals honour the clock (cheap, and the bind needs the flash to slow with everything else).
- **Audio**: triggered as a one-shot at `impact_time`, then **plays at wall-clock / normal pitch** — slowing audio sounds bad and nobody does it. Rule: *trigger on the sim clock, play unslowed.* Same stored timestamp as the flash, read two ways — one as a continuous function (visual), one as a fire-and-forget event (sound).
**The breach to avoid:** wiring the projectile to *cause* the damage (game logic in the visual layer), or letting the renderer track animation progress (a second clock). Combat decides what happens and when; the driver decides where the pretty thing is while that resolves. They sync by reading the same clock, not by one triggering the other.
 
---
 
## Scene tree & node model

The structural rule that makes the input/output split concrete: **combat logic is plain `RefCounted`; only orchestrators are `Node`s.** That's what lets a headless autotest run the whole sim without instantiating any presentation.

**Logic tree** — under the `Game` autoload; renders nothing; runs headless:

```
Game  (autoload Node, "Game")          session state machine + run lifecycle
└─ Run manager (Node)                   per run: map, sequencing, run-state, run RNG
   └─ Encounter (Node)                  per beat: fight / event / rest
      └─ Combat manager (Node)          per fight: the ONE _physics_process tick + registry
         ├─ Timekeeper          (RefCounted)   the clock (owned, not a child)
         ├─ Actor ×N            (RefCounted)   HP · board · statuses
         ├─ Item / Status / Delivery (RefCounted)  the registry (seq_id-ordered)
         └─ event bus           (RefCounted)
```

`Run manager` / `Encounter` are Nodes but don't `_process` (they advance by explicit call / signal); **only the `Combat manager` runs `_physics_process`** (the one tick). A fight exists only while a `Combat manager` does. Within-step iteration is ascending `seq_id` — a monotonic id stamped at registration (deterministic order).

**Presentation tree** — the main scene; `Game` swaps screens:

```
main.tscn  (Main, Node)                 boots → Game.boot()
└─ ScreenHolder
   ├─ title_screen.tscn
   ├─ run_screen.tscn      reads Game.run (+ the live Combat manager); emits intents
   │   ├─ CorridorLayer     corridor_panel.tscn (mood + the approach-from-depth)
   │   ├─ CombatView         SWAPPABLE: combat_view_framed.tscn | _fullscreen.tscn
   │   │     ├─ VfxDriver        reads the Delivery set + render_time()
   │   │     ├─ Player/EnemyBoardView
   │   │     └─ Portrait · HP · PotionSlots
   │   └─ OverlayLayer       draft / choice / 1D-map
   └─ death_screen.tscn
```

- The presentation tree only **reads** the logic and **emits intents** (view → logic: `Combat manager.request_*`, `Run manager.pick_*`); the autotest driver calls the same methods with no presentation mounted.
- **Corridor advance** stays logic-clean: `Run manager` changes position + emits `advancing(next)`; `run_screen` animates the corridor panel and times board-activation to arrival.
- The **framed-vs-full-screen** open (UI PRD) is isolated to the single swappable `CombatView` sub-scene — nothing else moves when it's decided.

**Directory layout:** `src/combat/` (timekeeper · combat_manager · actor · item · status · delivery · ticker · event_bus), `src/run/` (run_manager · encounter), `src/content/` (def objects + catalogs), `src/vfx/`, `src/scenes/screens/` + `src/scenes/combat/`, alongside the existing `src/autoloads/`, `src/data/` (`balance.gd`), `src/scenes/corridors/`, `src/ui/`. `project.godot`'s `main_scene` flips to `main.tscn` when the spine is built (the corridor testbed stays runnable).

## Prototype scope for this layer
 
- **Full VFX *path*, minimal VFX *content*.** Build the driver and the wall (the clock's `render_time` → driver computes positions → renderer draws handed state) and prove them on a few effects: one projectile type, one fire-emote, travelling damage numbers, a screen pulse. This validates the cleanest architectural decision on the map at the cheapest moment.
- **Not** the palette pipeline, pixel-snapping shader, banded falloff, or per-effect-family particle variety — that's content/polish on a driver that already works, and the easiest place to lose weeks. Full *path*, few *effects*.
- Including VFX now is justified by feel ("I want to see how it feels") *and* by testing the wall while the system is small enough to fix cheaply if the boundary is wrong.
---
 
## What this pass deliberately leaves to per-system PRDs
 
Timescale override replace-vs-multiply; the full meta/character internals; VFX content and palette. PRD the foundation (this doc's spine), build, then PRD the next layer up with real information from the prototype. Don't write all the PRDs up front.
