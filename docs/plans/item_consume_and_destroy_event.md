# Dark Corridor — Item-Destroyed Event & Item-Consume Support PRD

> **This is engineering work, NOT content — a building agent should implement it.**
> Two general engine seams the **Fleshmancer**'s flesh-*consumer* payoffs need (design:
> [`../design/character_ideas.md` → *Flesh Golem / Meat*](../design/character_ideas.md)). The
> capabilities are **general** (any item can charge off a destroyed item; any item can consume
> board items as fuel); they are named here for the driver. The chunk, Flesh Explosion, the
> consumer items, and **all numbers** stay the **owner's content** (decision #23).

Follow-up to the shipped [`../systems/item_creation_and_decay.md`](../systems/item_creation_and_decay.md)
(create + decay). Reuses the [`../systems/spore_engine.md`](../systems/spore_engine.md) consume model
(Cap 1) and the [`../systems/combat_manager.md`](../systems/combat_manager.md) event bus; adds **no
new resolution model**.

**Engine:** Godot 4.
**Date:** 2026-06-20. **Deferred capability — not yet built.** Build with the owner when the
consumer content needs it.

---

## Purpose

The Fleshmancer **produces** chunks (built: the `CREATE_ITEM` attacks) and now needs the two ways to
**use** them — and the insight that makes it one system: a chunk's only exhaust is **destruction**,
and *both* uses flow through it.

- **Mode A — charge-on-destroy** (passive): a chunk's death charges other items. Wants chunks to die
  *fast* (more destruction = more charge). The decay clock feeds it a **trickle**.
- **Mode B — consume-directly** (active): an item spends a *pile* of chunks for a scaling effect (the
  Mass-payoff feel). Wants chunks to *persist* so a hoard exists to spend.

These are not opposed — **consuming a chunk *is* destroying it**, so if consume routes through the
same destroy event, a big consume is the direct payoff **plus** a charge **burst**. Passive decay is
a charge trickle; active consume is a deferred charge burst. One event unifies both. The decay clock
is the **dial** between trickle and hoard-then-burst.

So: **two seams, one shared event.**

1. **`ITEM_DESTROYED` event** — fired whenever an item is removed mid-fight; the hook Mode A charges off.
2. **Own-board item-consume** — count/remove/scale board items as fuel (the Mass-twin); Mode B,
   wired to remove **via** seam 1 so it inherits the charge synergy for free.

**What needs NO new work:** the trigger machinery (`trigger_subs` + the bus route already exist — an
item just subscribes to the new event); the removal plumbing (`CombatManager.remove_item`, built for
decay); the consume *pattern* (`spore_engine.md` Cap 1 is the precedent).

### Consistency with decision #23 — general seams, no baked flesh

The engine gains **one event** and **one consume verb** (+ its `ItemEffect` fields). It bakes no
"chunk": *which* item is consumed, how many, the scaling, and which items charge are `ItemDef` /
`Balance`, authored by the owner.

---

## Capability 1 — `ITEM_DESTROYED` event (the charge-on-destroy hook)

**Driver:** Flesh Explosion — "whenever one of your items is destroyed, charge."

**Current state (confirmed, 2026-06-20):** `EventBus.Event` is `{ ITEM_FIRED, DAMAGE_DEALT,
STATUS_APPLIED, HEALED }` — **no item-destroyed event**, and `CombatManager.remove_item` publishes
nothing. So a destroy-triggered item cannot be authored today.

**The work:**

- Add **`ITEM_DESTROYED`** to the `EventBus.Event` enum (`src/combat/event_bus.gd`).
- Publish it in **`CombatManager.remove_item(it)`** — `bus.publish(EventBus.Event.ITEM_DESTROYED,
  it.def.id, it.owner, it)` — **before** the `bus.unsubscribe` / `Item.dissolve()` lines (so the bus
  still routes to the *other* items). **Source = the destroyed item's owner** so `OWN_SIDE` trigger
  filtering works ("when *my* item dies", decision #30).
- **Guard: do not publish at teardown.** `remove_item` runs both mid-fight (decay) and during the
  combat-scoped strip at `teardown()`; a fight ending is not a "destroy" for triggers. Suppress the
  publish when the fight is resolved/tearing down — check the existing `_resolved` flag (the one
  `add_item` guards on) and verify the teardown path.
- **Trigger side is already built:** items declare `trigger_subs` (`{ event, amount, filter,
  source_filter }`) and the bus routes them. A charge item subscribes `{ event:
  EventBus.Event.ITEM_DESTROYED, amount: <fraction of its bar> }`, `source_filter` defaulting
  `OWN_SIDE`. The push `amount` is a **fraction of the cooldown bar** (`combat_model.md`) — e.g. "1s
  on a 20s item" = `0.05` (coupled to the cooldown; re-derive if it changes). The optional `filter`
  could narrow by destroyed item def id (`it.def.id` is the published data) later; the first consumer
  charges on *any* own item destroyed (no filter).
- **Determinism:** published in the deterministic removal path — no RNG.

---

## Capability 2 — Own-board item-consume (the Mass-twin)

**Driver:** the "consume your chunks for a scaling effect" payoff.

**Current state:** the spore engine consumes *status stacks* (`StatusManager.consume(target, id,
amount) → count`, scaling a payload — `spore_engine.md` Cap 1). There is **no** equivalent for
*board items*.

**The work — the exact parallel of Mass, on board items instead of stacks:**

- Add fields to `ItemEffect` (`src/content/items/item_effect.gd`), copied through `Payload.from_effect`
  and `_spawn_delivery` **exactly as** the `consume_*` / `summon_*` / `create_item_def_id` fields are:
  `consume_item_def_id: String` (which item to eat), `consume_item_amount: int` (up to N; document
  whether `0` = "all present" or add an explicit all-flag), `consume_item_scale: float` (payload
  value added per item consumed).
- **Resolve in `CombatManager._fire_item`** — NOT in `Item` (item-removal lives on the manager, and
  `Item` stays downward-clean; this mirrors how opponent-fuel Mass resolves in the manager's
  per-target spawn path, `spore_engine.md` Cap 1). On fire, before spawning the effect's deliveries:
  count matching items (`consume_item_def_id`) on the **owner's** board, remove up to
  `consume_item_amount`, and scale that effect's payload value by the count removed (`+= count *
  consume_item_scale`). Iterate a **copy** of the board — removal mutates it mid-pass (cf.
  `_drain_uses` iterating `it.statuses.duplicate()`).
- **Determinism:** count/remove in the deterministic sweep — no RNG.

---

## The synergy — the critical wiring (why both ship together)

Capability 2 **must** remove its consumed items by calling **`CombatManager.remove_item`** (the
Capability-1-publishing path) — **never a silent `board.erase`**. Then each consumed chunk publishes
`ITEM_DESTROYED`, so a Capability-1 charge item (Flesh Explosion) charges off both *passive decay*
and *active consume* with **no extra code**: consume-death and decay-death are the same event. This
constraint is the point of building the two together; state it in the as-built doc.

**Loop-safety:** a big consume + several charge items spikes (eat 6 → 6 pushes → a payoff fires).
That is loop-safe by construction — accrual-only triggers land **next tick**, no within-step recursion
(the Bazaar lesson, [`combat_model.md`](../systems/combat_model.md)). Note it as the power ceiling to
watch in `/tune`; **do not** add loop guards.

---

## Build order

Each test-first, its own green commit, headless autotest as the regression backstop
([`../systems/autotest.md`](../systems/autotest.md)):

1. **Capability 1** (`ITEM_DESTROYED` + publish in `remove_item` + teardown guard) — small, self-contained.
2. **Capability 2** (item-consume fields + `_fire_item` resolution), removing **via** `remove_item`
   so the synergy lands for free.
3. **Then content (owner, not this PRD):** Flesh Explosion (a charge item), the consumer items, and
   their numbers.

---

## Testing

- **GUT units:** `ITEM_DESTROYED` fires on a decay-destroy with the owner as source; **does not fire
  at teardown**; a `trigger_subs` item charges off it; item-consume counts / removes / scales (a
  no-fuel consume is a safe no-op); **consumed items publish `ITEM_DESTROYED`** so a charge item sees
  them (the synergy test).
- **Autotest:** the suite stays green; a chunk-consume / charge E2E is owner-content, deferred.

---

## Dependencies / files touched

- **`event_bus.gd`** — new `Event.ITEM_DESTROYED`.
- **`combat_manager.gd`** — publish `ITEM_DESTROYED` in `remove_item` (pre-unsubscribe, owner source,
  teardown-guarded); item-consume resolution in `_fire_item` (count + `remove_item` + scale).
- **`item_effect.gd` / `payload.gd`** — `consume_item_def_id` / `consume_item_amount` /
  `consume_item_scale`, copied through.
- **Docs (same change):** extend [`../systems/item_creation_and_decay.md`](../systems/item_creation_and_decay.md)
  with both capabilities + the synergy; refresh its [`../index.md`](../index.md) keywords; add hub
  interface-contract entries.

## Open / deferred

- **`consume_item_amount` "all" semantics** — `0` = all, or an explicit flag (implementer's call; document).
- **Destroyed-item trigger `filter`** — narrowing a charge by *which* def died; not needed by the
  first consumer.
- **All numbers** (charge fractions, consume amounts, scaling) are content — `ItemDef` / `Balance`.
- **No baked content** — do not author the chunk, Flesh Explosion, or any consumer item; ship only
  the seams + tests.
