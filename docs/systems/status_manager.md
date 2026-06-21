# Dark Corridor — StatusManager PRD

Foundation PRD. Sits under the [Architecture Map](architecture.md). The `StatusManager` is the **stateless facade** over statuses: it exposes `apply` / read / resolve calls and holds **no per-fight state**. Behaviour is **not** a rulebook keyed by type here — each status is a **polymorphic `StatusEffect` subclass** (one class per status, the Slay-the-Spire `AbstractPower` model) that owns both its state and its behaviour via hooks; the facade just loops a target's statuses and calls those hooks. Status *instances* live on their targets (`Actor` / `Item`) and are advanced each step by the `Combat manager` (on the [Timekeeper](timekeeper.md)'s clock).

> **Refactored 2026-06-10** from a centralized rulebook (one `StatusManager` switching on a shape enum, statuses keyed by an int `Type`) to per-status classes. Rationale: many statuses with wildly different effects bloat a central switch; a class-per-status keeps each effect's behaviour in its own ~6-line file and lets the engine stop naming statuses (`type == BLOCK` → `status.absorb(...)`). Canonical record: decision-log **#29**.

**Engine:** Godot 4.
**Date:** 2026-06-04. Pre-prototype.

Boundaries (inbound / exposed surface) live in the hub: [architecture.md → Interface contracts → `StatusManager`](architecture.md#interface-contracts-boundary-hub). This PRD specifies the *internals*.

---

## Purpose

Statuses are the shared modifier primitive — dots (poison/burn), block, regen, freeze, timed buffs/debuffs, item buffs, silence, and similar. A status is **`(target, count/stacks, behaviour)`**, where target is an `Actor` *or* an `Item` (the dual-targeting that's the key extension over Spire — items, which persist across fights, can carry statuses *during a fight*). All statuses are **combat-scoped** (decision #26) — see below.

The `StatusManager` is a thin **facade** — a global, stateless autoload anyone can call (`StatusManager.apply(…)`). It delegates every decision to the status instances; the **behaviour lives in the `StatusEffect` classes**, not here. Globally reachable is *correct* precisely because it's stateless (a facade, not a per-fight manager — see [the scope discussion in architecture](architecture.md)).

What it **is not**:

- **Not an instance store** — instances live on their targets; the facade just routes calls to them. (Statuses are combat-scoped, never run-persistent — decision #26.)
- **Not the rulebook** — each `StatusEffect` subclass is its own rule. The facade holds no per-type switch.
- **Not the ticker** — the `Combat manager` advances each instance each step (on the `Timekeeper`'s clock).
- **Not effect *content*** — specific per-effect numbers are content (`Balance`); the classes are the engine that runs them.

### Naming

- `class_name StatusManagerAutoload`, registered as `StatusManager` (autoload convention — access via `StatusManager.*`).

---

## The status model

A status is a **`StatusEffect` subclass instance**, held in its target's `statuses` list. It carries its own state:

- `id` (`'poison'`, `'block'`, … — string id, decision #23). The `Type` enum is gone.
- `count / stacks` — numeric value.
- `duration` + `ticker` — *optional*; time-driven subclasses build the ticker **from the application's duration** (so duration rides the application, not a global on a def).
- `source` — *optional*; the actor/item that applied it, for source-dependent rules / attribution.
- **No `target` reference** — every hook receives `(target, ctx)` instead, preserving the no-back-reference / no-RefCounted-cycle invariant.

The **behaviour** lives in the subclass: it overrides only the hooks it needs. A `StatusRegistry` maps `id → creator`. New statuses are authored as a class file + one registration line.

### Status shapes → class hierarchy

The old shapes are now **intermediate base classes** that carry the common machinery, so a concrete status is tiny:

- **`PeriodicStatus`** (poison / burn / regen) — ticks each interval, dealing `count × damage_per_tick` to the holder in-place through `take_damage` (carrying the instance's `flags`, so an `unblockable` DoT bypasses block — the applying Delivery is long gone by tick time), then decays a stack and expires when drained. The Combat manager spawns a **visual-only** Delivery so the wall still shows the number (no double damage, no on-`DAMAGE_DEALT` event). Mass fuel.
- **`TimedStatus`** (Weak / Vulnerable / Blind) — a duration Ticker counts down, then expires. Reapply **stacks** by extending the timer (the ratified default; override for refresh / max).
- **`PoolStatus`** (block) — an inert `count` consumed by `absorb()` during the incoming-damage pass, not by time. **No Ticker**; removed once emptied (`is_spent`).
- **Static** (silence / the inert Spores counter) — extends `StatusEffect` directly, no ticker; gates a fire or sits as fuel.

Time-driven instances (`on_step` returns expiry) are advanced each step. The Combat manager advances statuses **uniformly across both target kinds** — each actor *and* each board item is swept the same way (a timed status on an item counts down exactly like one on an actor). Periodic damage only lands on actors (the `take_damage` owner; the hook guards `target is Actor`); timed / static work on either.

### Statuses are combat-scoped (decision #26)

Every status — actor- **or** item-targeted — lives only for the fight: created during combat, cleared at `CombatManager.teardown()`, **never saved**. A status has no coherent cross-fight meaning (a half-consumed block pool, a ticking poison), so it doesn't carry over and the run snapshot never serializes instances. Durable effects live one layer up — a **Relic** (run-level state) or an **Enchantment** (permanent item modifier) holds the magnitude and, where needed, re-applies a *fresh* combat-scoped status each fight (e.g. Stone Ward → combat-start block). So a timed status on a player `Item` doesn't "pause between fights" — it simply ends with the fight; the durable version of that effect is an Enchantment.

---

## `apply(target, id, count, duration?, source?, flags?, ctx?) → instance`

1. **Find** an existing status of the same `id` **and the same `flags`** on the target — a different-flags application (unblockable poison over blockable poison) gets its **own instance**, so one application's flags never silently rewrite another's. A reapply keeps the **first** applier as `source`; the combat log credits that source for the stack's DoT ticks (no proportional multi-applier split).
2. **Reapply or create.** Existing → `existing.reapply(count, duration, source, flags)` — **the class decides stacking** (additive count by default; `TimedStatus` extends its duration; a class may refresh / max). Else → `StatusRegistry.create(id)`, `setup(count, duration, …)` (which builds the ticker from the **per-application duration**), `on_apply(target, ctx)`, append.
3. **Return the instance.**
4. **On-apply event** is emitted by the *Combat manager* at the Delivery's land (`STATUS_APPLIED` carries the string id) — **only when the apply succeeded** (an unknown id applies nothing and publishes nothing) — so reactive items can trigger ("when you apply poison, gain 1 block").

`ctx` is the seam for a `StatusContext` (apply other statuses, spawn, publish). It is **still `null` on the `apply` path** (no built status needs ctx *at apply*), but the class now exists in a **minimal form** — one `remove_item(item)` capability the Combat manager fulfils — realized for the **Decay use-status**, whose emptying must remove its host item ([`item_creation_and_decay.md`](item_creation_and_decay.md) Cap 2). The Combat manager passes it to the `on_holder_fired` active hook. Hooks must still tolerate a null ctx (apply-outside-combat).

---

## Incoming-damage pipeline

`Actor.take_damage` delegates to `StatusManager.resolve_incoming_damage(target, raw, flags) → net`:

- Iterates the target's damage-modifier statuses in a defined order — **amplifiers** (`Vulnerable`) then **absorbers** (block). Block consumes its `count` against the remaining (amplified) damage; the remainder hits HP.
- **Block absorbs damage unless the effect is `unblockable`.** Per-effect flag — some DoTs set it, some don't; an `unblockable` payload skips the absorber stage and hits HP (after any amplifiers). For a DoT the flag is stored on the `StatusEffect` instance at apply time and re-passed into `take_damage` on every tick (the originating Delivery no longer exists).
- **Stat-statuses — BUILT (#6).** `VulnerableStatus` overrides `modify_incoming` (amplifier — scales up before block) and `WeakStatus` overrides `modify_outgoing` (applied to the holder's DAMAGE payloads **at fire time** via `StatusManager.modify_outgoing(actor, amount)` in `Item._resolve_effect`). Both fold each status's hook in `statuses`-list order. Magnitudes are **% multipliers**, not flat-per-fire (a flat per-fire modifier makes fast items strictly dominant — the authoring guidance). The real stat-status content (numbers, per-stack variants) is the owner's.

---

## Behaviour hooks (the `StatusEffect` interface)

A subclass overrides only what it does; every hook is a no-op / identity by default. Two kinds:

- **Active (push)** — the status acts via `ctx`: `on_apply`, `on_expire`, `on_step(target, ctx) -> expired`, `on_holder_fired(item, ctx)` (an **item-targeted** status acts when its holder item fires — Decay drains here, [`item_creation_and_decay.md`](item_creation_and_decay.md)), `setup` / `reapply` (lifecycle + stacking). `on_expire` runs at every **natural** removal — timed expiry, consumed-to-zero, spent-removal after a damage pass — but **not** at combat teardown (the fight ending is a clear, not an expiry).
- **Modifiers (pull)** — the engine queries at a pipeline stage, in list order: `modify_outgoing`, `modify_incoming`, `absorb(amount, flags, …) -> remaining`, `gates_fire`, `causes_evasion`. Plus `is_fuel` / `consume` (Mass), `is_spent` (pool removal), and presentation fields.

**Thrown consumables are exempt from the holder's combat modifiers** (decision #30): a potion's payload skips `modify_outgoing` (Weak) and `has_evasion` (Blind) — potions are the reserve, not the engine, so debuffs that degrade the board don't degrade the panic button. A deliberate asymmetry with the item fire pipeline, not an accident.

Pull for modifiers keeps the engine in control of *when and in what order* contributions compose — preserving the deterministic sweep (#24) and amplify-before-absorb (#6). Push for active effects lets the status do its own work. Small, additive set — extend as effects need.

---

## Surface (presentation reads, doesn't live here)

Distinct icon + per-effect colour per type (the design's colour vocabulary). Presentation is **instance fields** (`name_key`, `color`, `icon`) set by plain assignment in each class's `_init` — which is also how `tools/extract_pot.gd` localizes the names (it scans `name_key = '...'`). The UI reads `status.color` / `status.name_key` directly; the facade does not draw.

## Asymmetric acquisition

"Enemies get strength often, players rarely" is acquisition-rate tuning **at the source**, not engine special-casing (design). Same rule, different exposure.

---

## Built

- The polymorphic `StatusEffect` hierarchy + `StatusRegistry` (id → creator).
- Eight statuses across the shapes: **block** (pool), **poison** (periodic DoT), **weak** / **vulnerable** / **blind** (timed), **silence** (static gate), **spores** (inert counter / Mass fuel), **decay** (item-targeted use-status — drained by the holder's fire, removes the item at 0; [`item_creation_and_decay.md`](item_creation_and_decay.md)).
- `apply` (per-application duration + class-decided stacking) and `resolve_incoming_damage` (amplify → absorb).
- Tie-ins: Combat-manager stepping of time-driven statuses; `Actor.take_damage` through the pipeline.

---

## Open / deferred

- **`StatusContext` is minimal** — realized with one `remove_item(item)` capability for the **Decay** use-status ([`item_creation_and_decay.md`](item_creation_and_decay.md)); the `apply` path still passes `null` (no status needs ctx *at apply*). It fleshes out further (`apply_status`, `spawn_token`, `publish_event`, `rng`) only when a status that applies / spawns / chains is authored.
- **Event-subscribing statuses** ("when a spore is applied, gain block") are not yet a hook — the surface allows adding `on_event` later; no current status needs it.
- **Authoring guidance** (not a global rule): a *flat per-fire* damage modifier makes fast items strictly dominant in the cascade, so per-fire damage scaling should be percentage or charge-limited ([design](../design/game_design.md)).

Resolved: **statuses are polymorphic `StatusEffect` classes**, string-id (#23), one file per status (2026-06-10 refactor). **block** persists until consumed (pure pool, no Ticker) and absorbs all damage except `unblockable` payloads. **Reapply stacks by default**; `TimedStatus` extends its duration. Damage-modifier order is amplify (`modify_incoming`) then absorb.

## Dependencies

- **Above:** nothing — foundation autoload, stateless, depends on nothing.
- **Used by:** `Item` / `Relic` / `Consumable` / `Enemy` abilities (`apply` / read), `Actor` (`take_damage` → `resolve_incoming_damage`), `Combat manager` (registers Tickers returned from `apply`; reads on-apply events for the trigger backbone).
