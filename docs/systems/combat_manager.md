# Dark Corridor — Combat Manager PRD

Orchestrator PRD. Sits under the [Architecture Map](architecture.md). The `Combat manager` is the **per-fight orchestrator** — it turns the [Combat PRD](combat_model.md)'s settled resolution *model* into a running fight. Instanced one-per-fight by `Encounter`. It owns the live context, the [Timekeeper](timekeeper.md) (the combat clock) lifecycle, the component registry, the central fixed-step tick, target-shape resolution, the trigger event bus, and win/loss.

**Engine:** Godot 4.
**Date:** 2026-06-04. Pre-prototype.

Boundaries live in the hub: [architecture.md → Interface contracts → `Combat manager`](architecture.md#interface-contracts-boundary-hub). This PRD specifies the *internals*.

**Naming:** `class_name CombatManager`, **instanced** (not an autoload) — one per fight, created and torn down by `Encounter`.

---

## Purpose

The `Combat manager` runs the machine; it makes no combat *decisions* — boards auto-fire on their Tickers. It holds the live fight (the actor pair + left-to-right ordering, the **component registry**, the in-flight Delivery set), owns the `Timekeeper` (the combat clock) and the central **fixed-step** tick, advances every component each step, resolves item target-shapes, runs the trigger event bus, applies results to actors, and detects win/loss.

What it **is not**:

- Not the resolution *model* — that's `combat_model.md` (Ticker, fire → Delivery, travel, fizzle). The manager *executes* it.
- Not the clock — it owns a `Timekeeper` (the time source + dial + step cadence); the *manager* advances the components each step, on that clock.
- Not run-flow — `Run manager` sequences encounters; `Encounter` creates this; the manager owns only the single fight.
- Not content, not presentation (the VFX driver *reads* its Delivery set + the clock).

---

## Lifecycle

- **Created by `Encounter`** with the player `Actor` + the spawned enemy `Actor`s + their left-to-right ordering.
- **At start:** create the `Timekeeper`; register the boards' item cooldown Tickers in its own registry (**resetting each to zero** — a cooldown is combat-scoped like a status, so the player's persistent board never carries charge between fights, and a resumed save matches continuous play, decisions #20/#26); subscribe each item's declared triggers to the event bus.
- **Runs** the central tick until win/loss.
- **At end:** stop and tear down the `Timekeeper`; drop in-flight effects; signal the **result (win/loss)** up to `Encounter` / `Run manager`; itself torn down.

---

## The central tick (the heart)

The `Combat manager` owns the single combat loop — *the* central tick (no other combat logic runs `_process`). It runs on a **fixed timestep** (see the Timekeeper): the loop lives in `_physics_process`, and the `Timekeeper` converts real time × the dial into a whole number of fixed **sim-steps** to run this frame.

```
_physics_process(physics_delta):                  # physics_delta fixed (1/60), Godot-driven
    for i in timekeeper.steps_due(physics_delta):  # dial → step count, capped, backlog dropped
        sim_step()

sim_step():                                        # ONE combat tick — a fixed STEP of game-time
    timekeeper.advance()                           # sim_time += STEP
    crossed = advance_all_components()             # advance every registered component one step; collect crossings
    fire(crossed); land(); route_events(); check_win_loss()
```

Each **sim-step** (one combat tick):

1. **Advance** — `timekeeper.advance()` (clock += `STEP`); advance every registered component one step (item cooldowns filled by time and/or *last* step's pushes; periodic/timed statuses; Delivery travels). Collect the ones that **cross** — including any Delivery whose travel reaches 0 this step (now "landed").
2. **Fire** — each crossed item fires (combat_model.md): reset its cooldown, emit a fire event, produce its payload(s). The manager resolves each payload's target-shape (below) and spawns a Delivery per target — `travel_time` 0 Deliveries land in step 3 this same step; others register and travel. A crossed *status* applies its tick effect directly inside `on_step` (a DoT damages its holder there); the manager fabricates a pre-landed **visual-only** Delivery so the wall still shows the number. Expired timed statuses are removed (their `on_expire` hook runs).
3. **Land** — landed Deliveries (a prior travel that reached 0 in step 1, plus this step's `travel_time` 0 spawns) apply their result: `Actor.take_damage` (through the `StatusManager` modifier pipeline) / `StatusManager.apply` / heal. Each landing emits events (on-damage, on-status-applied, on-heal).
4. **Route events** — the event bus delivers this step's events (fires + lands) to subscribed trigger items, **pushing** their accumulators. **A push that fills a bar fires on the *next* step, not this one** — a chain advances at most one link per step (combat_model.md's loop-proofness; no recursion within a step).
5. **Win/loss** — if a whole side is dead, signal the result and end (below).

**One fire pass per sim-step**, driven by crossings present at the advance; pushes land in accumulators but fire next step. That single-pass structure is what makes the cascade loop-proof *and* reproducible — the operational form of `combat_model.md`'s accrual-only rule. (Headless autotest calls `sim_step()` directly in a loop — no `_physics_process`, no `steps_due`, no cap — so a run is "K sim-steps," bit-reproducible.)

---

## Target-shape resolution (the runtime targeting authority)

Items declare a *relative* shape (Item PRD); the manager resolves it against the firing item's owner and the live side/ordering — it's the only thing that knows sides + ordering:

- **self** → the owner `Actor`.
- **opponent-leftmost** (single-target) → the leftmost living opponent relative to the owner's side. **Locked at spawn**; if it dies mid-flight the Delivery fizzles — no retarget (combat_model.md).
- **all-opponents** (AOE) → each living opponent at spawn; a target dead at arrival fizzles individually.
- **opponent-item-random** → one *random* item on the living opponents, drawn from the **seeded combat RNG** (deterministic / reproducible). Locked at spawn; if that item leaves the board before arrival the Delivery fizzles. *(Random default — provisional, may become a rule after testing.)*
- **all-opponent-items** → every item on the living opponents at spawn; an item gone at arrival fizzles individually.

**Actor-targeting** never gets smart — leftmost, no lowest-HP / highest-threat (combat_model.md), for player predictability. **Item-targeting**'s single-target case is **random** (seeded) by deliberate choice — variety over predictability, to validate in testing. The *rules* are combat_model.md's; their *runtime authority* (live ordering, the RNG draw) is here.

---

## The trigger event bus

A per-fight pub-sub the manager owns (it holds every participant) — this resolves the "trigger delivery" the StatusManager and Item PRDs deferred:

- **Subscribe** — at start (and whenever an item is added) each item registers its declared trigger conditions (event type → push amount, plus the data + source filters below). **Unsubscribe** — a reaped body's items are dropped from the bus (no zombie pushes); mid-fight item removal would ride the same call.
- **Publish** — during a tick, emitted events (fires, damage, status-applied, heal, …) carry **source identity** — the acting Actor + the acting Item where one exists (`ITEM_FIRED` carries the firing item + its owner; a Delivery's land carries its `source_actor`; a thrown consumable's events carry the thrower with a null item). Matching subscriptions get their accumulator pushed by the declared amount; a push to a **gated** item is dropped (decision #30 — the gate freezes the item's time).
- **Filtering** — a subscription filters on the event's **data** (e.g. STATUS_APPLIED scoped to `'poison'`) and on the **source's side** relative to the subscriber: `OWN_SIDE` ("when MY side does X" — the content default, decision #30) / `ANY` / `OPPONENT_SIDE` (the Avenger shape — opt-in per subscription via `trigger_subs.source_filter`). Side is resolved **at event time** through the manager's side resolver, never cached at subscribe time (rosters mutate — a summon subscribes before its roster insertion). A side filter needs the whole identity chain (resolver + subscriber owner + source actor); a null-identity event only reaches `ANY`.
- **Timing** — pushes take effect for the *next* tick's advance (loop-proof, above).
- **Listeners** — an observation-only channel (`add_listener`): callables receive `(data, source_actor, source_item)` after the pushes and never push a Ticker. The autotest's exact fire counts ride it.
- **Teardown** — the manager's teardown clears the bus (subscriptions hold strong refs to their Items; clearing releases them).

The event catalog and push amounts are content (the Item PRD: item declares; combat_model.md: charges model). "Scales with item count" reads board state at resolve — a computed modifier, not an event.

---

## The component registry (pull-based)

The manager **owns the registry** of live time components — the boards' item cooldown Tickers, active statuses, and in-flight Deliveries — and advances them each sim-step (step 1 above). Membership is **pull-based**: it registers components **returned from** a component's step / `StatusManager.apply()` (a firing item hands back its Delivery; an applied status hands back its instance) and deregisters resolved/expired ones. Content never reaches *up* to register itself. The iteration order must be **deterministic** (same board state → same result); the concrete order (board position? insertion?) is deferred until there are real boards. (The `Timekeeper` no longer holds this — it's just the clock.)

---

## Pending-effect set & the visual wall

The manager holds the in-flight Delivery set. A *resolved* Delivery is kept until its visual's max duration elapses — so the `VFX driver` can read `now − impact_time` after the damage has already landed (the wall) — then dropped. The manager writes no visuals; the `VFX driver` reads the manager's Delivery set + the `Timekeeper`'s `render_time()` (continuous, so motion stays smooth between sim-steps).

---

## Player input (intents)

The manager receives UI *input-intents* during a fight (the input/output split — see architecture):

- **timescale intent** (hover slow-mo / throw) → sets the `Timekeeper`'s dial (base vs. override — Timekeeper PRD).
- **throw-potion intent** → activates the consumable: builds its payload(s) (no Ticker — combat_model.md), resolves the shape, spawns its Deliveries.

UI never writes combat state directly; the manager interprets the intent.

---

## Win/loss

Checked each tick after **Land** + the dead-reaping (steps 3–4): player `Actor` dead → loss; the enemy side empty (every enemy reaped on death) → win. On resolution: stop the `Timekeeper`, drop in-flight effects, signal the result up. *(Simultaneous death — both sides empty the same tick — resolves to **loss**; a rare edge, provisional.)*

---

## Prototype scope

- One `Combat manager` driving one player `Actor` + one enemy `Actor`: the central tick (advance → fire → land → events → win/loss).
- Target-shape resolution: self, opponent-leftmost, all-opponents, **and the item-target shapes** (opponent-item-random / all-opponent-items) — the random pick drawn from the per-fight RNG (below). Example item: **Hex Bolt** (silences a random enemy item).
- The event bus with one trigger ("on poison applied → push the block item").
- `Timekeeper` lifecycle (create / tear down); pull-based registration into its own registry; the UI timescale intent (hover slow-mo).

**Not** in scope: multi-enemy composition, potion/consumable content, the full event catalog, VFX content (only the data path the wall reads).

---

## Open / deferred

- **Timestep — resolved:** fixed-step, driven by `_physics_process`; the dial sets step cadence (`steps_due`) with a `MAX_STEPS` cap + backlog-drop on hangs; visuals read the continuous `render_time()`; autotest drives `sim_step()` directly.
- **Within-step component order — resolved (#24):** deterministic registration order, realized as **fixed type-ordered passes** (item cooldowns → statuses → Delivery travel, each in insertion order) — bit-reproducible without a literal `seq_id` field, which stays deferred until cross-type registration order actually matters.
- **Simultaneous death** tiebreak (→ loss, provisional).
- **AOE-at-arrival** specifics (set resolved at spawn; dead-at-arrival fizzle) — confirm when multi-enemy fights are built.
- **Per-fight RNG for random item-targeting — resolved + BUILT (#20):** the `Combat manager` owns a `RandomNumberGenerator` seeded in `start()` from a `combat_seed`. The `Run manager` derives that seed from its run **seed** (constant, saved) + the beat index (`_combat_seed_for(pos)`) and threads it through the `Encounter` — so fights stay bit-reproducible, a re-entered fight replays identically (resume isn't save-scummable), and deriving it never consumes the run stream the draft draws from. Item-target shapes draw their random pick from this stream. Item-targeted Deliveries land on the `Item` (its owning actor must be alive, else fizzle); the status applies to the item (e.g. silence gates it).
- **Encounter handoff — resolved (Encounter PRD):** the `Encounter` creates the `Combat manager` with the player + spawned enemy `Actor`s + their left-to-right ordering, and awaits the win/loss result.
- **Mid-fight roster changes (summoning + reaping) — BUILT.** `add_actor` files a combat-scoped summon onto either side (registers its Tickers/triggers, inserts front/back); `register_ally` adds a run-scoped ally mid-fight. On death the **combat-scoped** bodies (enemies + summon tokens) are **reaped** — removed from the roster + the component sweep, kept intact until **dissolved at teardown** (live Deliveries/VFX may still reference them) — so the fight is N-vs-M with bodies leaving as they fall. A **downed run-scoped ally is NOT reaped**: it stays on the roster (out of targeting + firing while dead, its slot kept dimmed) and the `Run manager` **revives it to full at the next fight** — only the player carries HP attrition.

## Dependencies

- **Calls down to:** the `Timekeeper` (create; `steps_due`; `advance`; set the dial; read `sim_time` / `render_time`), `Actor` (`take_damage` / `heal`, `is_alive`, read boards), `StatusManager` (`apply`), `Item` (fire; collect payloads / events). Owns the component registry itself.
- **Created & signalled by (above):** `Encounter` (creates it with the actors; receives the win/loss result, → `Run manager`). Receives UI input-intents.
- **Executes** `combat_model.md`'s resolution model.
