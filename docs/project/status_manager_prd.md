# Dark Corridor — StatusManager PRD

Foundation PRD. Sits under the [Architecture Map](architecture.md). The `StatusManager` is the **stateless rulebook** for statuses: it defines how each status type behaves and exposes `apply` / read / resolve calls, but holds **no per-fight state** — status *instances* live on their targets (`Actor` / `Item`) and are advanced each step by the `Combat manager` (on the [Timekeeper](timekeeper_prd.md)'s clock).

**Engine:** Godot 4.
**Date:** 2026-06-04. Pre-prototype.

Boundaries (inbound / exposed surface) live in the hub: [architecture.md → Interface contracts → `StatusManager`](architecture.md#interface-contracts-boundary-hub). This PRD specifies the *internals*.

---

## Purpose

Statuses are the shared modifier primitive — dots (poison/burn), block, regen, freeze, timed buffs/debuffs, item buffs, silence, and similar. A status is **`(target, count/stacks, behaviour)`**, where target is an `Actor` *or* an `Item` (the dual-targeting that's the key extension over Spire — items, which persist across fights, can carry statuses *during a fight*). All statuses are **combat-scoped** (decision #26) — see below.

The `StatusManager` owns only the **behaviour rules**, keyed by status type — a global, stateless autoload anyone can call (`StatusManager.apply(…)`). Globally reachable is *correct* precisely because it's stateless (it's a rulebook, not a per-fight manager — see [the scope discussion in architecture](architecture.md)).

What it **is not**:

- **Not an instance store** — instances live on their targets; the Manager is rules. (Purely to keep the autoload **stateless** — *not* a persistence mechanism: statuses are combat-scoped, never run-persistent — decision #26.)
- **Not the ticker** — the `Combat manager` advances each instance's Ticker each step (on the `Timekeeper`'s clock).
- **Not effect *content*** — specific per-effect numbers and decrement rules are content (the [Combat PRD](combat_prd.md) defers those); the Manager is the engine that runs them.

### Naming

- `class_name StatusManagerAutoload`, registered as `StatusManager` (autoload convention — access via `StatusManager.*`).

---

## The status model

A status **instance** (held by its target) is data:

- `type` (poison, block, …) — keys into the behaviour rule.
- `target` — the `Actor` or `Item` it sits on.
- `count / stacks` — numeric value.
- `ticker` — *optional*; only time-driven shapes have one (see shapes).
- `source` — *optional*; the actor/item that applied it, for source-dependent rules.

The **behaviour** (how a type acts) lives in the `StatusManager`, keyed by `type`. Composition, not subclassing: an instance is data + a type key; the Manager looks up the rule. (Same instinct as the Ticker — share the engine, keep identities distinct.)

### Status shapes

Not every status ticks. Four shapes:

- **Periodic** (poison / burn / regen) — a Ticker fires its payload each interval; per the Combat PRD a tick *is* a fire (→ a Delivery, `travel_time` 0 for the instant case), so DoT damage lands through the same path as item hits. Has a Ticker → **registered for stepping** (in the Combat manager's registry).
- **Timed** (a 5s debuff) — a Ticker counts the duration down, then `on_expire`. Has a Ticker → registered.
- **Persistent pool** (block) — a `count` consumed by an external event (incoming damage), not by time. **No Ticker** — block persists until consumed or combat ends (no decay). Not a time component.
- **Static modifier** (a flat / "again" modifier read at resolve time) — no Ticker; alters a calculation when read. Not a time component.

Only Ticker-bearing shapes (periodic / timed) get registered for stepping; pools and static modifiers don't tick. The Combat manager advances statuses **uniformly across both target kinds** — each actor *and* each board item is swept the same way each step (a timed status on an item counts down exactly like one on an actor). Periodic-damage shapes only sit on actors (the `take_damage` owner); timed / static work on either.

### Statuses are combat-scoped (decision #26)

Every status — actor- **or** item-targeted — lives only for the fight: created during combat, cleared at `CombatManager.teardown()`, **never saved**. A status has no coherent cross-fight meaning (a half-consumed block pool, a ticking poison), so it doesn't carry over and the run snapshot never serializes instances. Durable effects live one layer up — a **Relic** (run-level state) or an **Enchantment** (permanent item modifier) holds the magnitude and, where needed, re-applies a *fresh* combat-scoped status each fight (e.g. Stone Ward → combat-start block). So a timed status on a player `Item` doesn't "pause between fights" — it simply ends with the fight; the durable version of that effect is an Enchantment.

---

## `apply(target, type, count, source?) → instance`

1. **Resolve source-side application modifiers** — e.g. a relic's "your poison is applied twice" scales `count`. (Read from `source`; the specific modifiers are content.)
2. **Create or update** the instance on the target per the type's **stacking policy** — default **additive stacks**; some types refresh duration or stay independent. The policy is per-type; the *specific* policies are content (Combat PRD defers decrement/stacking).
3. **Return the instance**, so the `Combat manager` can register its Ticker (if any) in its registry. Content never reaches *up* — `apply` hands the instance back; the in-combat caller registers it (matches the Combat manager's pull-based registration).
4. **Emit an on-apply event** so reactive items can trigger ("when you apply poison, gain 1 block"). The trigger *mechanism* (accrual pushes) is the Combat/Item PRD's; the Manager only makes application observable.

---

## Incoming-damage pipeline

`Actor.take_damage` delegates to `StatusManager.resolve_incoming_damage(target, raw, flags) → net`:

- Iterates the target's damage-modifier statuses in a defined order — **amplifiers** (e.g. a future `vulnerable`) then **absorbers** (block). Block consumes its `count` against the remaining damage; the remainder hits HP.
- **Block absorbs damage unless the effect is `unblockable`.** Per-effect flag — some DoTs set it, some don't; an `unblockable` payload skips the absorber stage and hits HP (after any amplifiers).
- With only block defined now the order is trivial; the amplifier slot is reserved for the deferred stat-statuses.

---

## Behaviour hooks (the rule interface)

A type's rule may implement: `on_tick` (periodic payload), `on_expire`, `modify_incoming_damage` (absorb / amplify), `on_apply` / `on_stack`, and `gate` (e.g. silence → the item can't fire while gated). Small, additive set — extend as effects need.

---

## Surface (presentation reads, doesn't live here)

Distinct icon + per-effect colour per type (the design's colour vocabulary; a status uses the same colour as the panel of the item that applied it). Naming preserves intuition — poison should *feel* different from a damage buff even though the engine treats them uniformly. The Manager exposes `type → {icon, colour, name}` for the UI; it does not draw.

## Asymmetric acquisition

"Enemies get strength often, players rarely" is acquisition-rate tuning **at the source**, not engine special-casing (design). Same rule, different exposure.

---

## Prototype scope

- The instance model + behaviour-by-type lookup.
- Three statuses exercising the shapes: **block** (pool / absorber), **poison** (periodic DoT), one **timed debuff**.
- `apply` (stacking + return-for-registration + on-apply event) and `resolve_incoming_damage` (block).
- Tie-ins: Combat-manager registration of periodic/timed Tickers; `Actor.take_damage` through the pipeline.

**Not** in scope: stat-statuses (below); per-effect decrement/decay numbers (content); the full hook list.

---

## Open / deferred

- **Stat-statuses (strength / weak / vulnerable equivalents)** — deliberately deferred ([design](design.md)). Constraint to honour when designed: a flat damage modifier must not make fast items strictly dominant over slow ones in the high-trigger cascade (percentage / charge-budgeted / slowest-item-targeted are candidate forms). The engine reserves the amplifier slot; no flat stat-status ships until this is solved in prototype.
- **Per-effect stack / decrement semantics** (how poison decrements, whether regen counts down) — content, settled as effects are authored (Combat PRD defers these).
- **Damage-modifier ordering** — precise amplifier/absorber order, settled when the first amplifier (vulnerable-type) is designed.
- **Status-definition data format — resolved:** typed GDScript `StatusDef` objects in a static catalog (decision-log #23), not JSON.
- **Trigger delivery** — how on-apply events reach reactive items (the accrual-push backbone) is the Combat/Item PRD's.

Resolved: **block** persists until consumed (pure pool, no Ticker) and absorbs all damage except `unblockable` payloads — a per-effect flag (varies by DoT, not a blanket rule).

## Dependencies

- **Above:** nothing — foundation autoload, stateless, depends on nothing.
- **Used by:** `Item` / `Relic` / `Consumable` / `Enemy` abilities (`apply` / read), `Actor` (`take_damage` → `resolve_incoming_damage`), `Combat manager` (registers Tickers returned from `apply`; reads on-apply events for the trigger backbone).
