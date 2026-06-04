# Dark Corridor — Architecture Map & Foundation Spec
 
> **Companion to the design and art docs.** This is the high-level system map plus a settled spec for the foundation layer. It is *not* per-system implementation detail — those are separate PRDs, written one at a time as systems get built. This pass exists to nail the interfaces and dependencies before any single system is spec'd in depth.
 
**Engine:** Godot 4.
**Date:** 2026-06-03 (revised 2026-06-04). Pre-prototype.
 
---
 
## Principles (apply across all systems)
 
- **Autoloads hold systems and rules, never per-entity state.** `StatusManager` and `Save` are autoload singletons. Anything with per-instance lifetime — actors, items, boards, statuses, Deliveries, and the **per-combat `Timekeeper`** (created and owned by the `Combat manager`) — is instantiated, not autoloaded.
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
- **`Save`** (autoload) — persists a run snapshot it's *handed* on encounter entry, and returns it on load; the `Run manager` gathers it and rehydrates. **Push, not pull** — `Save` reads no live state and writes none back. No migration (`CLAUDE.md`).
### Content → Foundation
 
- **`Item`** → `StatusManager` (apply / read statuses); reads its owner `Actor` (self-target, board membership). It declares a target-*shape*; the `Combat manager` resolves it and lands the Delivery — no direct `Item → Actor` damage call.
- **`Enchantment`** → modifies its host `Item`.
- **`Relic`** → `StatusManager` and/or direct `Actor` modification. A relic rides the shared accrual engine like everything else — a *triggered* relic owns an event-push Ticker (Combat PRD), a *timed* effect can be applied as a status — so it needs no special `Timekeeper` handling.
- **`Consumable`** → shares Item's *resolution* surface (spawns a Delivery) but carries no Ticker — manually activated.
- **`Enemy`** → not a class — an `Actor` built from an authored *enemy definition* (HP + an authored board of enemy-pool Items + tier + optional boss signature), spawned by `Encounter`. No enemy AI; no special arrows. See [enemy_prd.md](enemy_prd.md).
(Item / Relic / Consumable share the **Draftable** base — see design doc.)
 
### Run structure → Content + Foundation
 
- **`Draft`** → produces Draftables; *pulls* from a pool. Reads run state for weighting.
- **`Encounter`** → spawns the enemy `Actor`s for a fight and hands them to a `Combat manager`; drives non-combat events; → `Draft` on reward.
- **`Combat manager`** (instanced, one per fight) → owns the live fight: the player + enemy `Actor`s and their left-to-right ordering, the **component registry**, the in-flight Deliveries, win/loss detection, and the runtime targeting authority (answers "leftmost living enemy" for the Combat PRD's rule). Owns the `Timekeeper` (the combat clock) and the **fixed-step tick** — its `_physics_process` runs `steps_due` sim-steps; each step advances every registered component, then orchestrates fire/land/events/win-loss. Registers/deregisters components as items fire and effects resolve. Created by `Encounter`; signals its result back up. It *orchestrates* — no combat decisions (boards auto-fire on their Tickers).
- **`Run manager`** → drives the encounter sequence, owns the game-state machine + act/boss/rest placement and run lifecycle, calls `Save`. Does **not** touch the `Timekeeper` — it hands a fight to the `Combat manager` and waits for the result.
- **`Corridor/advance`** → driven by the `Run manager`.
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
  - *(Test hook: an **autotest driver** emits these same intents headlessly — the input layer is the seam the harness drives. See [testing/autotest.md](../testing/autotest.md).)*
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
- **Does not:** resolve its own target or Deliveries (`Combat manager` + combat_prd); tick itself (`Timekeeper`); own status rules (`StatusManager`); draw (presentation reads its panel/cooldown). Shares the `Draftable` base with `Relic` / `Consumable`.
 
### `Save` — PRD: [save_prd.md](save_prd.md)
 
- **Exposes:** `write(snapshot)` (persist the run snapshot, atomic), `read() → snapshot?` (the saved run, or none), `clear()` (drop the run save on death/win). Stateless service — holds no live state.
- **Inbound:** the `Run manager` → `write` on encounter entry, `read` on launch, `clear` on death.
- **Outbound:** none — `Save` never writes back into live systems; on load it *returns* the snapshot and the `Run manager` rehydrates.
- **Does not:** decide *when* to save (`Run manager`); read live state itself (push, not pull); persist combat state (ephemeral) or meta-progression (a separate dataset — Meta PRD); migrate saves (`CLAUDE.md` — incompatible → fresh run).
 
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
 
## Prototype scope for this layer
 
- **Full VFX *path*, minimal VFX *content*.** Build the driver and the wall (the clock's `render_time` → driver computes positions → renderer draws handed state) and prove them on a few effects: one projectile type, one fire-emote, travelling damage numbers, a screen pulse. This validates the cleanest architectural decision on the map at the cheapest moment.
- **Not** the palette pipeline, pixel-snapping shader, banded falloff, or per-effect-family particle variety — that's content/polish on a driver that already works, and the easiest place to lose weeks. Full *path*, few *effects*.
- Including VFX now is justified by feel ("I want to see how it feels") *and* by testing the wall while the system is small enough to fix cheaply if the boundary is wrong.
---
 
## What this pass deliberately leaves to per-system PRDs
 
Timescale override replace-vs-multiply; the full draft/encounter/relic/meta/character internals; VFX content and palette. PRD the foundation (this doc's spine), build, then PRD the next layer up with real information from the prototype. Don't write all the PRDs up front.
