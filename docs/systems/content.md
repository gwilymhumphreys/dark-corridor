# Dark Corridor — Content PRD (Relics · Enchantments · Consumables)

Content PRD. Sits under the [Architecture Map](architecture.md). Covers the three content-layer categories beyond [`Item`](item.md): **`Relic`** (persistent run-level modifier), **`Enchantment`** (a one-per-item modifier), and **`Consumable`** (the manually-fired reserve — potions). All three are **thin** — they lean on the foundation ([StatusManager](status_manager.md), [Combat manager](combat_manager.md), [Actor](actor.md)) and reuse the [`combat_model.md`](combat_model.md) resolution model; this PRD covers what's category-*specific*. Relic, Enchantment, and Consumable all share the **Draftable** contract with `Item` (a shared definition-face + a `category` tag, composition — [architecture](architecture.md); drafting, slow-mo-hover inspection, tooltips); Enchantment differs only in *application* — it attaches to a chosen item rather than taking its own slot.

**Engine:** Godot 4.
**Date:** 2026-06-05. Pre-prototype.
**Naming:** `class_name Relic`, `class_name Consumable`, `class_name Enchantment` — instanced (held in the player run-state), not autoloads.

Boundaries live in the hub: [architecture.md → Interface contracts → `Content`](architecture.md#interface-contracts-boundary-hub). This PRD specifies the *internals*.

---

## Purpose

These are the run-level content categories that decorate the player's engine without being board items. Each is **data-defined** (definition vs. instance, like Item/Enemy) and **mechanically thin** — it expresses its effect through systems that already exist, not new combat code. Why one PRD: all three lean on the same foundation and would each be a short file; collected here, split later if one grows.

What it **is not**: not new combat mechanics (all route through `StatusManager` / `Combat manager` / `combat_model.md`); not on the board (a relic is an `Item` but held apart from the board; a potion is not an item); not the draft *draw* (`Draft` offers them; the `Run manager` applies the pick) or the reward grant (`Run manager` / `Encounter`).

---

## Relic

An **item with no timer** (decision #51): a powerful, run-changing ability made of triggers and passives. The run owns the player's relics; during a fight each relic is an `Item` that fires when one of its triggers happens. Plan and later stages: [`plans/relics_as_items.md`](../plans/relics_as_items.md).

**Location:** `src/content/relics/` (`RelicDef`, `Relic`, `RelicCatalog`), `src/content/relics/passives/` (`RelicPassive`, its subclasses, `PassiveRegistry`), `content/relics/` (one file per relic).

- **Definition** — `RelicDef extends ItemDef`, so a relic has the item fields: `effects`, `trigger_subs`, `mechanics`, `crit_chance`, `rarity` (feel-based for relics, not a power ladder), `icon` (placeholders in `assets/icons/relics/`). A relic trigger is an item trigger without `seconds`. A trigger entry may carry its own `'effects'` and `'fires_per_fight'`, so one relic can have several triggers that do different things; an entry without them fires the relic's `effects` and shares the relic's `fires_per_fight`. Relic-only fields:

| Field | Meaning |
|---|---|
| `passives` | Always-on abilities for the whole fight, written as `ItemEffect`s like `effects` |
| `fires_per_fight` | 0 = no limit; 1 = "the first time each fight" |
| `run_triggers` | Abilities outside fights: `{'event': RunManager.RunEvent, 'effects': Array[RunEffect]}` entries |

- **Run** — `RunManager.relics: Array[Relic]` holds the player's relics for the run (saved as ids). Before each fight `RunManager.begin_current` builds one `Item` per relic into `Actor.relics`; `CombatManager.teardown` dissolves them, so per-fight state (the fire count) starts fresh.
- **Enemies** — `EnemyDef.relic_ids` builds the enemy's `Actor.relics` in `make_actor`.
- **In a fight** — `Actor.relics` is separate from the board, so board-wide effects never pick a relic. Each trigger entry has its own one-step ticker (`Item.trigger_tickers`) that never fills over time; its event fills it completely (the subscription pushes 1.0) and on the next step the relic fires that entry's effects through the item fire pipeline (`Item.fire_trigger`: targeting, crit, deliveries, combat log). Entries fire separately, so two entries whose events happen in one step both fire, and two events for one entry fire it on two steps. An entry that used its fires for the fight (`Item.trigger_spent`) drops further pushes. The relic's `cooldown` ticker is unused.
- **Not an item firing** — a relic's fire publishes no `ITEM_FIRED` and skips the use-status and fire-status drains, so it does not use up an Empowered stack. The events its effects cause when they land (`APPLIED`, `DAMAGE_TAKEN`) publish as usual.
- **Events** — relics mostly use `FIGHT_START` (published once in the first step, so a start-of-fight relic fires on step two) and `DAMAGE_TAKEN` alongside the item events ([combat_manager.md](combat_manager.md)).
- **Passives** — each `passives` entry becomes a `RelicPassive` on the relic's `Item` (`Item.passives`), its class chosen by the effect's mechanic in `PassiveRegistry` (attack bonus and attack percent bonus so far; a content check fails for any other). A passive is not a status: it extends `CombatHooks`, the hook base class `StatusEffect` also extends, and the status manager and Combat manager call the passives of an actor's relics before its statuses ([status_manager.md → Behaviour hooks](status_manager.md#behaviour-hooks-the-combathooks-and-statuseffect-interface)). Nothing that removes, counts or consumes statuses reaches it. The attack bonus passives raise the attacks of the owner's board items that the effect's shape (`ALL_OWN_ITEMS`) and target filter pick, checked at fire time, so items created during the fight are covered. A relic with only passives never fires.
- **Outside fights** — the Run manager applies the effects of each `run_triggers` entry whose event happens, in relic order. `PICKED_UP` fires once for the new relic when it is granted, picked from an offer, or given as the character's starting relic; its result is kept in the saved health and gold and is not applied again on load. `FIGHT_WON` fires after a won fight (not the final boss, which ends the run), before that fight's reward, so a relic won there does not react to it. `DRAFT_SKIPPED` fires after the skip gold is added. A `RunEffect` (`src/run/run_effect.gd`) raises maximum and current health (`max_hp`), heals up to maximum health (`heal`), or adds gold (`gold`).
- **Display** — relic tokens in the sheet's Relics box and the enemy's item row (before its items), with the item tooltip ([tooltips.md](tooltips.md)).

## Enchantment

A **`Draftable`** (drafted / inspected / tooltipped like Item / Relic / Consumable) that is a **one-per-item modifier** (Item PRD's one enchant slot) — it differs from the others only in *application*: on pick it attaches to a chosen item rather than taking its own slot.

- An enchant **instance** attaches to its host `Item` instance and hooks the item's fire/resolve pipeline (Item PRD step 3): scale a value (+50%), add a secondary payload, change a target-shape, or add an on-resolve trigger ("when this deals damage, apply poison").
- **Drafted, applied to a chosen item** — offered as a draft slot (Draft PRD); on pick the `Run manager` applies it to a player-chosen item (the enchant-target sub-choice). One enchant per item; re-enchanting is content/UI.
- **Numeric scaling lives here, not in rarity** — a "+X stronger version of item Y" is an enchant, not an item (design). Rarity tiers (common/uncommon/rare) — higher = more dramatic.
- **May use the status system** when the effect is status-shaped — a tool, not its definition (design).
- **Saved** — an item's enchant is part of the board snapshot (Save PRD).

## Consumable (potions)

A **manually-fired reserve** — no `Ticker` (combat_model.md: the one thing that doesn't accrue-toward-firing).

- **Slots** — 3 potion slots (design); found mainly in drafts; consumed on use; a potion taken when slots are full drops one (the potion-drop sub-choice — Draft PRD).
- **Throw → resolve** — a **throw-potion intent** reaches the `Combat manager`, which activates the consumable: builds its payload(s), resolves the target-shape, spawns its Deliveries (combat_model.md) — the same resolution surface as an item fire, minus the Ticker. Effects are tactical (heal, instant shield, freeze, instant damage, apply-status-to-all — design). A thrown potion's Deliveries fly `Balance.POTION_TRAVEL_STEPS` (one step, decision #48) and land in the step loop like an item's; a lethal throw resolves the fight on that step. A potion thrown while the fight is paused lands on the first step after it resumes. **Thrown payloads are exempt from the thrower's combat modifiers** (decision #30): Weak doesn't scale a potion down and Blind can't whiff a throw — potions are the reserve, not the engine.
- **Slow-mo-on-hover** to inspect + throw during combat (design — opt-in agency; slows both sides).
- **Saved** — potions are run-state, in the snapshot (Save PRD).

---

## Prototype scope

**Built (2026-06-06):** all three categories, each proving its path end-to-end and wired into the run + headless autotest (starting-kit grants stand in for drafting them — slot composition is deferred):

> **Not reachable in play right now (2026-09-18).** A starting kit was the only way a run got a
> potion or an enchant, and the only character that carried them was the deleted Wanderer
> placeholder. None of the authored characters has a starting relic, potion or enchant, and Stone Ward is
> not in `RelicCatalog.REWARD_POOL`, so only Vital Charm and Iron Idol can be earned mid-run. The
> code paths are all still exercised by the test suite. Giving a character a starting kit, or
> adding a potion or enchant reward, is content work for the owner.

- Relics — Stone Ward and Iron Idol (shield at the start of each fight), Vital Charm (maximum health on grant).
- One **enchant** — Whetstone (scale-a-value, +50%), applied to a chosen item, saved on the board entry; the Item fire pipeline scales payload values (`src/content/enchants/enchant*.gd`, `Item._resolve_effect`).
- One **consumable** — Healing Draught (a thrown self-heal), in a potion slot, fired via `RunManager.throw_potion` → `CombatManager.throw_consumable` → a Delivery that lands on the next step (`src/content/consumables/consumable*.gd`). **Not** in scope: the relic/potion/enchant pools' content, rarity tuning, the re-enchant + potion-drop sub-choice UIs, character starting-relic passives.

---

## Open / deferred

- **The pools' content** (relic / potion / enchant catalogues) + rarity tuning — content/design (the pool work).
- **Definition data formats — resolved (#23):** typed GDScript def objects + catalogs, not data files (player-facing strings stay localizable via `tr(def.name)` — `CLAUDE.md`).
- **Relic health thresholds and rule changes** — stage 4 of [`plans/relics_as_items.md`](../plans/relics_as_items.md).
- **Re-enchant + the potion-drop / enchant-target sub-choice UIs** — a UI pass.
- **Character starting-relic passive trait** — the Characters PRD's (deferred).

## Dependencies

- **Calls down to:** `StatusManager` (enchant status effects), `Combat manager` (a relic's items and triggers; a thrown consumable's Delivery), `Item` (an enchant hooks its host's pipeline). A relic's run triggers are applied by the `Run manager`.
- **Driven by (above):** the `Run manager` — holds them in run-state, grants relics on reward or from the relic encounter's offer, applies an enchant to a chosen item (`apply_enchant`); `Draft` offers them; `Save` persists them (run-state).
- **Shares** the **Draftable** base with `Item` (Relic, Enchantment + Consumable; design).
