# Dark Corridor — Item PRD

Content PRD (first of the content layer). Sits under the [Architecture Map](architecture.md). An `Item` is the board participant that drives the cascade: a data-configured entity that owns a `Ticker` ([Combat PRD](combat_prd.md)) and, when it fires, produces effect(s) the `Combat manager` resolves. Builds on the foundation ([Timekeeper](timekeeper_prd.md) cooldowns, [StatusManager](status_manager_prd.md) statuses, [Actor](actor_prd.md) board) and `combat_prd`'s fire model.

**Engine:** Godot 4.
**Date:** 2026-06-04. Pre-prototype.

Boundaries live in the hub: [architecture.md → Interface contracts → `Item`](architecture.md#interface-contracts-boundary-hub). This PRD specifies the *internals*.

---

## Purpose

Items are the engine the player builds; the cascade is many small items firing. An item shares the **Draftable** base with Relic/Consumable (drafting, slow-mo-hover inspection, tooltips — see [design](design.md)); this PRD covers the **combat-participant** side. Item power is many-small-not-few-big and roughly flat across rarity (design) — rarity buys complexity, not numbers.

What it **is not**:

- Not the resolver — it produces payloads (each with a target-shape and `travel_time`); the `Combat manager` + `combat_prd` resolve them into Deliveries (travel, landing, fizzle).
- Not the tick engine — it owns a `Ticker` (combat_prd defines it); the `Combat manager` advances it each step (on the `Timekeeper`'s clock).
- Not status rules (`StatusManager`), not the board or targeting authority (`Actor` holds the board; the `Combat manager` targets).

---

## Definition vs. instance

- **Item definition** — content/data (~100 in the launch pool): type, payload(s) (kind + value), cooldown, size, per-effect damage-shape, rarity, enchant-slot, and the panel's effect-family colour + value. Data-defined; the format is content/impl (deferred, as with status definitions).
- **Item instance** — runtime, on a board: a definition + live `Ticker` state + its one enchant (if any) + its item-targeted statuses. **Duplicates stack independently** — two of the same definition are two instances, each its own Ticker, firing twice (design).

---

## Items are active; triggers layer on (no passive type)

Reconciling design's vocabulary with `combat_prd`'s *composition, not inheritance* (an item owns a Ticker; no `if type ==`):

- **Every item is active** — it owns a Ticker whose accumulator fills as the combat clock steps (its cooldown) and fires its effect(s) on crossing. Effect subtypes (design): Weapon (damage; single-target / AOE), Armor (block), Heal, Apply-status (poison / burn / freeze / …).
- **Triggers are an additional accrual input, not a separate type** — a triggered item *still ticks normally*; declared events **push the same accumulator** on top of the time accrual (the charges model — combat_prd; an instant reaction is a ~100% push). Triggers accelerate / supplement firing; they don't replace the cooldown.
- **No passive item type** — always-on / passive effects are **statuses** (`StatusManager`'s static-modifier shape), applied to actors or items and usually sourced from relics (design). An item confers a lasting effect by *applying a status*, not via a passive mechanism. (Global flat modifiers like "+10% all damage" are stat-like statuses — deferred with the stat-status problem.)

One `Item` class, configured by its definition; some definitions also declare trigger inputs.

---

## Firing pipeline (one item, one fire)

When the item's `Ticker` crosses — its accumulator filled step-by-step, plus any trigger pushes (combat_prd):

1. **Gate check** — item-targeted gate statuses (e.g. *silence*) can suppress the fire (`StatusManager`). (Whether a gated item's cooldown holds or keeps cycling is the gate status's behaviour — content.)
2. **Fire** — reset the cooldown; play the fire-emote (recoil / flash — combat_prd). The fire is an event others can trigger off.
3. **Resolve payload(s)** — for each of the item's effects, apply value modifiers (item-targeted statuses like *+2 damage* or *triggers-twice*, via `StatusManager`) and enchant hooks → a **payload** `(kind, value)`, plus its target-shape and `travel_time`.
4. **Hand them up** — the item returns its payload(s) + shape + travel to the `Combat manager`, which resolves the shape and spawns a `combat_prd` **Delivery** per target. The item never calls up.

A fire may yield several payloads (a rare combining damage + heal); each becomes its own Delivery (fire-rate and travel are decoupled — combat_prd).

---

## Targeting: declare a shape, don't resolve a target

An effect declares a **relative target-shape**, not a resolved target:

- **self** — the owner (the item knows its owner via board membership); block/heal/self-buff.
- **opponent-leftmost** — single-target actor (deterministic leftmost).
- **all-opponents** — AOE over actors.
- **opponent-item-random** — one *random* item on the living opponents (e.g. silence / debuff an enemy item). Selection is **random via the seeded combat RNG**, so the fight stays deterministic / bit-reproducible. *(Random is the provisional default — may become a rule after testing. Deliberate exception to the actor-level "leftmost, never random" rule, which exists for player predictability; item-targeting trades that for variety, to validate.)*
- **all-opponent-items** — every item on the living opponents (AOE over items).

The `Combat manager` (which knows sides + ordering) resolves the shape to actual target(s) **at spawn** and locks the Delivery onto them (a single target that dies mid-flight → fizzle, per combat_prd; an item target removed from the board before arrival fizzles the same way). Shape is **per-effect** (a rare's damage = opponent, its heal = self). This is what keeps Items downward-clean — no `Item → Combat manager` dependency; the item declares, the manager (above) resolves. *(Ally-targeting — e.g. an enemy buffing another enemy — is a possible future shape the Combat manager would resolve; not in the prototype.)*

---

## Item-targeted statuses

Items hold their own statuses (`StatusManager` rules; instances on the item): value modifiers (+damage), charges (triggers-twice-next), gates (silence), timed item-buffs. The fire pipeline consults them (steps 1, 3). Item-targeted statuses persist on player items across fights; their timers only advance during combat (a Timekeeper consequence).

---

## Enchantments (one slot; details → Enchantment PRD)

An item has **one enchant slot**. An enchant hooks the item's fire/resolve: scale a value (+50%), add a secondary effect, change a target-shape, or add an on-resolve trigger ("when this deals damage, apply poison"). Enchants also absorb pure-numerical upgrades — numeric scaling lives in the enchant layer, not in rarity (design). Enchant content is the Enchantment PRD's.

---

## Triggers & synergies (item side; the bus is the Combat manager PRD's)

Synergy is the core decision mechanism (design). The item side:

- An item **declares trigger conditions** — event types that push its accumulator *on top of* the normal time accrual (the item still ticks), e.g. "on any poison applied: +N", "on item fired" (the charges model).
- An item **emits events** others trigger off — its fire; its Deliveries, on landing, emit on-damage / on-status-applied.
- **Routing** — collecting events and pushing matching items' Tickers — is the combat **event bus**, owned by the `Combat manager` (it holds all participants). This PRD defines the item's declare/emit surface; the bus is the Combat manager PRD's. *(This closes the "trigger delivery" the StatusManager PRD deferred.)*
- "Scales with item count" and similar read board state **at resolve** — a computed modifier, not a trigger.

---

## Definition tags: rarity, size, damage-shape

- **Rarity** (common / uncommon / rare → bronze / silver / gold border) — a *complexity* tier, **not** a power multiplier (design: power ~flat; numeric scaling is enchants). Common = simple/single-purpose; uncommon = conditional/interactive; rare = build-anchor / may combine multiple effects.
- **Size** — a *tempo* tag coupling cooldown ↔ per-hit value (bigger = slower = bigger hit; DPS roughly flat), ~2–3 sizes. Reads as rhythm, not power; distinct from rarity (border) and build-anchor (a separate glow channel). *A leaning from the art doc, to test — count and whether it ships are open.*
- **Damage-shape** (single-target / AOE) — a per-damage-effect tag; feeds the target-shape.

---

## Presentation (reads, doesn't live here)

Each item exposes its effect-family colour + value for the panel (usually one; rare items may show more than one), and its `Ticker` for the Bazaar-style cooldown ring. Border = rarity; build-anchor = a separate highlight (glow), never size or border. The item emits a fire-reaction (recoil/flash) the presentation plays. Items don't draw.

---

## Prototype scope

- One `Item` class + a handful of data-defined definitions — a **weapon** (single-target damage), an **armor** (self block), an **apply-status** (poison), all ticking — and one with a **trigger input** (ticks normally, *and* "on poison applied" pushes its accumulator).
- The fire pipeline (gate → fire → resolve with status/enchant modifiers → hand payloads up).
- Tie-ins: `Combat manager` registers the cooldown Tickers (in its registry), resolves target-shapes, and routes the trigger event; `StatusManager` for item statuses + applying effects.

**Not** in scope: the ~100-item pool, enchant content, passive-item global modifiers, the size count.

---

## Open / deferred

- **Item-definition data format** — content/impl.
- **Effect-kind catalog + values / cooldowns / sizes** — content (the design's pool work).
- **Enchantment specifics** — Enchantment PRD.
- **Trigger event catalog + the event bus mechanism** — Combat manager PRD (the item declares/emits; the bus routes).
- **Silenced-item cooldown** — does the Ticker hold or keep cycling while gated? = gate-status behaviour (content).
- **Size** — whether to ship size-as-tempo and how many sizes (art doc: a leaning to test).
- **Ally-targeting shape** — only if enemies ever buff/heal allies; the Combat manager would resolve it; not in the prototype.
- **Item-target shapes — added (resolved 2026-06-05):** `opponent-item-random` (one random enemy item; selection **random via seeded RNG**, provisional) and `all-opponent-items`. **Still open:** a board-wide *accumulator push* (e.g. a `trigger-all-items-once` potion) is a **push, not a payload delivery**, so it routes through the event bus rather than a target-shape — and consumables (spec'd as Delivery-spawners) will need that push surface; spec it when the first such consumable is built.

## Dependencies

- **Calls down to:** `StatusManager` (apply statuses on resolve; read its own gate/value statuses). **Reads** its owner `Actor` (self-target, board membership).
- **Owns** a `Ticker` (combat_prd) — advanced by the `Combat manager` each step (on the `Timekeeper`'s clock); the item doesn't call up.
- **Driven by (above):** the `Combat manager` — registers the item's Ticker, collects fired payloads (resolves shape → target → spawns the Delivery), routes events to push trigger items. The item returns / emits; it never calls up.
- Effect resolution (travel / landing / fizzle) is `combat_prd`'s, executed by the `Combat manager`, which then hits `Actor.take_damage` / `StatusManager.apply`.
- Shares the **Draftable** base with `Relic` / `Consumable`.
