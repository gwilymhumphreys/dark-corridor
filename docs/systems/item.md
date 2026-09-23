# Dark Corridor — Item PRD

Content PRD (first of the content layer). Sits under the [Architecture Map](architecture.md). An `Item` is the board participant that drives the cascade: a data-configured entity that owns a `Ticker` ([Combat PRD](combat_model.md)) and, when it fires, produces effect(s) the `Combat manager` resolves. Builds on the foundation ([Timekeeper](timekeeper.md) cooldowns, [StatusManager](status_manager.md) statuses, [Actor](actor.md) board) and `combat_model.md`'s fire model.

**Engine:** Godot 4.
**Date:** 2026-06-04. Pre-prototype.

Boundaries live in the hub: [architecture.md → Interface contracts → `Item`](architecture.md#interface-contracts-boundary-hub). This PRD specifies the *internals*.

---

## Purpose

Items are the engine the player builds; the cascade is many small items firing. An item shares the **Draftable** base with Relic / Enchantment / Consumable (drafting, slow-mo-hover inspection, tooltips — see [design](../design/game_design.md)); this PRD covers the **combat-participant** side. Item power is many-small-not-few-big. Rarity buys both complexity and numbers: uncommon and rare items get a larger points budget (owner, 2026-09-23).

What it **is not**:

- Not the resolver — it produces payloads (each with a target-shape and `travel_time`); the `Combat manager` + `combat_model.md` resolve them into Deliveries (travel, landing, fizzle).
- Not the tick engine — it owns a `Ticker` (combat_model.md defines it); the `Combat manager` advances it each step (on the `Timekeeper`'s clock).
- Not status rules (`StatusManager`), not the board or targeting authority (`Actor` holds the board; the `Combat manager` targets).

---

## Definition vs. instance

- **Item definition** (`ItemDef`, #23) — content/data: `id` / `name_key` / optional `description_key` (flavor), `rarity` (a complexity and power tier), `types` (the synergy tags — see [Item type tags](#item-type-tags)), `mechanics` (the authored list of mechanic ids the item counts as — see [The mechanics list](#the-mechanics-list)), `cooldown`, one-or-more `ItemEffect`s (each a payload kind, or a `mechanic` id for a [mechanic](mechanics.md), + value + target *shape* — single-target / AOE), `trigger_subs` (event subscriptions), `starting_uses` (the decay seed — [item_creation_and_decay.md](item_creation_and_decay.md)), and `panel_color`, read on each use: the `Colours` variable named by `panel_colour_name`, else the first effect's colour. An effect's colour is likewise read on use (`ItemEffect.color`: its `colour_name`, else its mechanic's colour, else its status's). Each authored item is one file under `content/items/` ([authoring.md](../design/authoring.md)). (`size` is a design lever, not yet a field; the enchant lives on the *instance*, below; the panel's value is computed at runtime, not stored.)
- **Item instance** — runtime, on a board: a definition + live `Ticker` state + its one enchant (if any) + its item-targeted statuses. **Duplicates stack independently** — two of the same definition are two instances, each its own Ticker, firing twice (design).

---

## Items are active; triggers layer on (no passive type)

Reconciling design's vocabulary with `combat_model.md`'s *composition, not inheritance* (an item owns a Ticker; no `if type ==`):

- **Every item is active** — it owns a Ticker whose accumulator fills as the combat clock steps (its cooldown) and fires its effect(s) on crossing. Effect subtypes (design): Weapon (damage; single-target / AOE), Armor (shield), Heal, Apply-status (poison / burn / freeze / …).
- **Triggers are an additional accrual input, not a separate type** — a triggered item *still ticks normally*; declared events **push the same accumulator** on top of the time accrual (the charges model — combat_model.md; an instant reaction is a ~100% push). Triggers accelerate / supplement firing; they don't replace the cooldown.
- **No passive item type** — always-on / passive effects are **statuses** (`StatusManager`'s static-modifier shape), applied to actors or items and usually sourced from relics (design). An item confers a lasting effect by *applying a status*, not via a passive mechanism. (Global flat modifiers like "+10% all damage" are stat-like statuses — deferred with the stat-status problem.)

One `Item` class, configured by its definition; some definitions also declare trigger inputs.

---

## Firing pipeline (one item, one fire)

When the item's `Ticker` crosses — its accumulator filled step-by-step, plus any trigger pushes (combat_model.md):

1. **Gate check** — item-targeted gate statuses (e.g. *silence*) can suppress the fire (`StatusManager`). A gated item's cooldown **freezes** (decision #30): the Combat manager skips its accrual while a gate status sits on it, so a lifting gate never releases a banked burst — the first fire lands one full cooldown after the lift. (The in-`fire()` gate check stays as a backstop.)
2. **Fire** — reset the cooldown; play the fire-emote (recoil / flash — combat_model.md). The fire is an event others can trigger off.
3. **Resolve payload(s)** — for each of the item's effects, apply the enchant and the outgoing-value bonuses of the **owner's** statuses and **the item's own** statuses, combined by one rule ([mechanics.md → Combining bonuses](mechanics.md#combining-bonuses)) → a **payload** `(kind, value)`, plus its target-shape and `travel_time`. The outgoing-damage modifier stage receives **the firing item itself** (`StatusManager.modify_outgoing(owner, value, self)`, #35) so an actor-targeted status can scope to a weapon attack — the Smith empower doubles only `weapon`-tagged damage; Weak scales any. This stage stays **pure** (it also runs on the tooltip-preview path, `Item.display_value`); a status that *consumes* on firing does so on the actor-level `on_owner_item_fired` hook, drained by the Combat manager after the payload spawns.
4. **Hand them up** — the item returns its payload(s) + shape + travel to the `Combat manager`, which resolves the shape and spawns a `combat_model.md` **Delivery** per target. The item never calls up.

A fire may yield several payloads (a rare combining damage + heal); each becomes its own Delivery (fire-rate and travel are decoupled — combat_model.md).

**Use-status drain (Decay).** After the payloads are handed up, the Combat manager drains the item's item-targeted **use-statuses** — one more consultation of the item's own statuses, beside the gate (step 1) and value-modifiers (step 3). The drain runs *after* the fire so the final activation still lands; when a use-status (Decay) empties, the item is **removed from its board** (deregistered + dissolved). Seeded by the def's `starting_uses`. See [`item_creation_and_decay.md`](item_creation_and_decay.md).

---

## Targeting: declare a shape, don't resolve a target

An effect declares a **relative target-shape**, not a resolved target:

- **self** — the owner (the item knows its owner via board membership); shield/heal/self-buff.
- **opponent-leftmost** — single-target actor (deterministic leftmost).
- **all-opponents** — AOE over actors.
- **opponent-item-random** — one *random* item on the living opponents (e.g. silence / debuff an enemy item). Selection is **random via the seeded combat RNG**, so the fight stays deterministic / bit-reproducible. *(Random is the provisional default — may become a rule after testing. Deliberate exception to the actor-level "leftmost, never random" rule, which exists for player predictability; item-targeting trades that for variety, to validate.)*
- **all-opponent-items** — every item on the living opponents (AOE over items).
- **own-item-random** — one *random* item on the owner's own board, for the [charge and decharge mechanics](mechanics.md#charge-and-decharge). Same seeded RNG as the opponent case. The **firing item is left out of the pool**, so an item that charges its own board cannot charge itself.
- **all-own-items** — every other item on the owner's own board (again without the firing item). Only the owner's board — an ally's items are not included.

The four **item** shapes are resolved by the `Combat manager` as **pool, then filter, then pick**: a pool builder (the living opponents' boards, or the owner's own board), an optional **target filter** (`TargetFilter`) that drops the pool items an effect rejects, and the pick (one at random via the seeded RNG for the two `-random` shapes, or all survivors). The filter applies to **item** pools only — the actor shapes (`self`, `opponent-leftmost`, `all-opponents`) ignore it (a filter on one is an authoring mistake, warned once and ignored). An unfiltered shape (a null or empty filter) resolves exactly as it did before the filter step; an empty result after filtering yields no Delivery, like an empty pool.

The `Combat manager` (which knows sides + ordering) resolves the shape to actual target(s) **at spawn** and locks the Delivery onto them (a single target that dies mid-flight → fizzle, per combat_model.md; an item target removed from the board before arrival fizzles the same way). Shape is **per-effect** (a rare's damage = opponent, its heal = self). This is what keeps Items downward-clean — no `Item → Combat manager` dependency; the item declares, the manager (above) resolves. *(Ally-targeting — e.g. an enemy buffing another enemy — is a possible future shape the Combat manager would resolve; not in the prototype.)*

---

## Item-targeted statuses

Items hold their own statuses (`StatusManager` rules; instances on the item). **Three kinds are implemented today:** **gates** (silence — consulted at step 1, `Item.is_gated`), **value bonuses** (the attack bonuses — consulted at step 3) and **use-statuses** (Decay — drained after the fire, step 5). 

**Item value bonuses.** `Item._resolve_effect` and the pure `display_value` preview both ask the item's own statuses for an `outgoing_bonus`, as well as the owner's, so a status on one item raises that item's attacks only ([mechanics.md → Attack bonuses](mechanics.md#attack-bonuses)). A buff for all the owner's weapons can still be an actor-targeted status scoped by type tag (`EmpoweredStatus`, #35). Like every status, item-targeted statuses are **combat-scoped** (decision #26) — cleared at the fight's teardown, never carried between fights; the *permanent* item modifier is an **Enchantment** (one slot, below).

---

## Enchantments (one slot; details → Content PRD)

An item has **one enchant slot**. An enchant hooks the item's fire/resolve: scale a value (+50%), add a secondary effect, change a target-shape, or add an on-resolve trigger ("when this deals damage, apply poison"). Enchants also absorb pure-numerical upgrades — numeric scaling lives in the enchant layer, not in rarity (design). Enchant content is the [Content PRD](content.md)'s.

---

## Triggers & synergies (item side; the bus is the Combat manager PRD's)

Synergy is the core decision mechanism (design). The item side:

- An item **declares trigger conditions** — event types that push its accumulator *on top of* the normal time accrual (the item still ticks), e.g. "on poison applied: +N", "on item fired" (the charges model). A declaration (`trigger_subs`) carries the event, the `seconds` it charges the item each time (a fixed number, usually 1; the Combat manager turns it into a share of the bar when it subscribes), an optional **data filter** (a status string id), and an optional **source filter** — whose events it listens to, defaulting to **OWN_SIDE** ("when MY side applies X", decision #30); `ANY` / `OPPONENT_SIDE` are per-item opt-ins.
- An item **emits events** others trigger off — its fire; its Deliveries, on landing, emit on-damage / on-status-applied.
- **Routing** — collecting events and pushing matching items' Tickers — is the combat **event bus**, owned by the `Combat manager` (it holds all participants). This PRD defines the item's declare/emit surface; the bus is the Combat manager PRD's. *(This closes the "trigger delivery" the StatusManager PRD deferred.)*
- "Scales with item count" and similar read board state **at resolve** — a computed modifier, not a trigger.

---

## Definition tags: rarity, size, damage-shape

- **Rarity** (common / uncommon / rare → bronze / silver / gold border) — a *complexity* tier and a *power* tier. Common = simple/single-purpose; uncommon = conditional/interactive; rare = build-anchor / may combine multiple effects. Uncommon and rare items get a larger points budget, so they are stronger as well as more involved; power is not meant to be flat across rarities (owner, 2026-09-23; multipliers in `Balance`, see [item_heuristics.md](../design/item_heuristics.md)).
- **Size** — a *tempo* tag coupling cooldown ↔ per-hit value (bigger = slower = bigger hit; DPS roughly flat), ~2–3 sizes. Reads as rhythm, not power; distinct from rarity (border) and build-anchor (a separate glow channel). *A leaning from the art doc, to test — count and whether it ships are open.*
- **Damage-shape** (single-target / AOE) — a per-damage-effect tag; feeds the target-shape.

---

## The mechanics list

`ItemDef.mechanics` is an **array of mechanic string ids** ([mechanics.md](mechanics.md)) naming what
the item counts as: its identity, not a summary of its effects. A target filter matches against it
("a random enemy poison item"), and the tooltip's keyword column is seeded from it.

- **Authored, not derived.** The list is written by hand rather than computed from the effects,
  because the awkward cases are judgment calls rather than facts about the data. An item that
  charges when poison is applied **is** a poison item; an item that creates a bleeding dagger is
  **not** a bleed item. No rule produces both, and a rule set covering fuel, summons, creation and
  enchants would grow without ever matching how the cards play. The question the author answers is
  "should *your poison items* pick this one up".
- **One checked floor.** `tests/content/test_pool_integrity.gd` requires that every mechanic an
  effect deals or applies — an effect's `mechanic`, a `status_id` that is also a mechanic id, and
  `crit` when `crit_chance` is set — appears in the list. The check is one-way: an item may list
  more than that, which is the point of authoring it, but never less. Nothing above the floor is
  checked, so `consume_id`, trigger filters and created items are the author's call.
- **Alphabetical.** The list is written sorted by id, and the sweep enforces it, because it seeds
  the tooltip keyword column and an arbitrary-but-fixed order keeps a mechanic in the same relative
  place on every item.

## Item type tags

`ItemDef.types` is an **array of type-tag string ids** (a Bazaar-style tag set) drawn from **five tags** — `weapon` · `armour` · `skill` · `spell` · `trinket` (the `ItemType` consts). The axis is the **source / vessel of the effect** (weapon = an attack; armour = self-shield; skill = an active ability; spell = a cast effect; trinket = a passive / utility bearer).

- **Read in three places.** The fire pipeline itself never branches on `types`, so a tag still has no *inherent* effect, but three things read tag membership: a status can (the firing item is threaded into the outgoing-damage / actor-fire hooks, #35 — the Smith empower, `EmpoweredStatus`, uses `types.has(ItemType.WEAPON)` to double only weapon attacks); a **target filter** can, which is how "all your weapons" is targeted; and the tooltip shows an item's tags as a type line. Tags are the synergy hook they were designed as ("your next *weapon* attack", "*spells* deal +2").
- **Display names.** `ItemType.display_name` / `display_name_plural` give each tag its word, singular and plural. Placeholder copy — the owner's to write.
- **An array, not a single field** — most items carry exactly one tag; the array just lets a rare carry more later. A synergy checks `types.has('weapon')`.
- **Items only.** Tags live on `ItemDef`; **Relic / Enchantment / Consumable are separate `Draftable` categories** (#21) and stay untagged.

Decision + rationale: [decision_log.md #34](../decision_log.md).

---

## Attack sound

`ItemDef.attack_sound` names the folder under `assets/sound-effects/mechanics/attack/` whose
recordings this item's attacks play — `blade` and `blunt` to start with, and any other name
works by making the folder. Empty means the plain attack folder.

It is deliberately separate from `types`. A type tag is part of the synergy vocabulary that
content reads, so adding `blade` there would make it something an item could key off. Nothing
but the sound layer reads `attack_sound`. If a blade synergy is ever wanted, it becomes a type
tag then; until it does, telling a sword from a mace is a sound decision alone. The folder
scheme and the other two layers of a hit: [audio.md](audio.md).

---

## Presentation (reads, doesn't live here)

Each item exposes its effect-family colour + value for the panel (usually one; rare items may show more than one), and its `Ticker` for the cooldown fill. Border = rarity; build-anchor = a separate highlight (glow), never size or border. The item emits a fire-reaction (recoil/flash) the presentation plays. Items don't draw.

---

## Prototype scope

- One `Item` class + a handful of data-defined definitions — a **weapon** (single-target damage), an **armor** (self shield), an **apply-status** (poison), all ticking — and one with a **trigger input** (ticks normally, *and* "on poison applied" pushes its accumulator).
- The fire pipeline (gate → fire → resolve with status/enchant modifiers → hand payloads up).
- Tie-ins: `Combat manager` registers the cooldown Tickers (in its registry), resolves target-shapes, and routes the trigger event; `StatusManager` for item statuses + applying effects.

**Not** in scope: the ~100-item pool, enchant content, passive-item global modifiers, the size count.

---

## Open / deferred

- **Item-definition data format — resolved:** typed GDScript `ItemDef` objects in a static catalog keyed by a **string id** (decision-log #23, amended from int) — not JSON / `.tres`.
- **Effect-kind catalog + values / cooldowns / sizes** — content (the design's pool work).
- **Enchantment specifics** — [Content PRD](content.md).
- **Trigger event catalog + the event bus mechanism** — Combat manager PRD (the item declares/emits; the bus routes).
- **Silenced-item cooldown — resolved (decision #30):** the Ticker **holds** while gated (no accrual, nothing banked); the first fire lands one full cooldown after the gate lifts.
- **Size** — whether to ship size-as-tempo and how many sizes (art doc: a leaning to test).
- **Ally-targeting shape** — only if enemies ever buff/heal allies; the Combat manager would resolve it; not in the prototype.
- **Item-target shapes — added (resolved 2026-06-05):** `opponent-item-random` (one random enemy item; selection **random via seeded RNG**, provisional) and `all-opponent-items`.
- **Own-board item shapes — added (2026-09-18):** `own-item-random` and `all-own-items`, for charge and decharge. **Narrowing which items they pick is now built** — a per-effect **target filter** narrows the pool by item type tag and/or mechanic before the pick (see [Targeting](#targeting-declare-a-shape-dont-resolve-a-target)). Naming a *specific* item definition as a target (rather than a tag or a mechanic) is still not built.

## Dependencies

- **Calls down to:** `StatusManager` (apply statuses on resolve; read its own gate/value statuses). **Reads** its owner `Actor` (self-target, board membership).
- **Owns** a `Ticker` (combat_model.md) — advanced by the `Combat manager` each step (on the `Timekeeper`'s clock); the item doesn't call up.
- **Driven by (above):** the `Combat manager` — registers the item's Ticker, collects fired payloads (resolves shape → target → spawns the Delivery), routes events to push trigger items. The item returns / emits; it never calls up.
- Effect resolution (travel / landing / fizzle) is `combat_model.md`'s, executed by the `Combat manager`, which then hits `Actor.take_damage` / `StatusManager.apply`.
- Shares the **Draftable** base with `Relic` / `Enchantment` / `Consumable`.
