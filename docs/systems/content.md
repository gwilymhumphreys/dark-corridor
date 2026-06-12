# Dark Corridor — Content PRD (Relics · Enchantments · Consumables)

Content PRD. Sits under the [Architecture Map](architecture.md). Covers the three content-layer categories beyond [`Item`](item.md): **`Relic`** (persistent run-level modifier), **`Enchantment`** (a one-per-item modifier), and **`Consumable`** (the manually-fired reserve — potions). All three are **thin** — they lean on the foundation ([StatusManager](status_manager.md), [Combat manager](combat_manager.md), [Actor](actor.md)) and reuse the [`combat_model.md`](combat_model.md) resolution model; this PRD covers what's category-*specific*. Relic, Enchantment, and Consumable all share the **Draftable** contract with `Item` (a shared definition-face + a `category` tag, composition — [architecture](architecture.md); drafting, slow-mo-hover inspection, tooltips); Enchantment differs only in *application* — it attaches to a chosen item rather than taking its own slot.

**Engine:** Godot 4.
**Date:** 2026-06-05. Pre-prototype.
**Naming:** `class_name Relic`, `class_name Consumable`, `class_name Enchantment` — instanced (held in the player run-state), not autoloads.

Boundaries live in the hub: [architecture.md → Interface contracts → `Content`](architecture.md#interface-contracts-boundary-hub). This PRD specifies the *internals*.

---

## Purpose

These are the run-level content categories that decorate the player's engine without being board items. Each is **data-defined** (definition vs. instance, like Item/Enemy) and **mechanically thin** — it expresses its effect through systems that already exist, not new combat code. Why one PRD: all three lean on the same foundation and would each be a short file; collected here, split later if one grows.

What it **is not**: not new combat mechanics (all route through `StatusManager` / `Combat manager` / `combat_model.md`); not a board `Item` (a relic/potion is not a board participant); not the draft *draw* (`Draft` offers them; the `Run manager` applies the pick) or the reward grant (`Run manager` / `Encounter`).

---

## Relic

A **persistent run-level modifier** — run-state, not Actor-owned (decision #6); distinct UI region (background power, not foreground play — design).

- **Definition** — rarity tier (common/uncommon/rare, *feel*-based for relics — not a clean power ladder, design), the effect, a portrait/icon, an optional passive-trait flag (a character's starting relic may carry its passive — design). Data-defined; format deferred.
- **Effect surface** — three shapes, all existing mechanisms: (a) **combat-start status** (BUILT — Stone Ward / Iron Idol) — applied to the player `Actor` via `StatusManager.apply` when a fight begins; (b) **triggered** — owns an event-push `Ticker` subscribed to the Combat manager's event bus (a relic reacts like a trigger item — combat_model.md; not yet built); (c) **direct** (BUILT — `MAX_HP_BONUS`, Vital Charm) — a one-time run-state mod applied on grant (raises max + current HP, baked into the snapshot, **not** re-applied on rehydrate; +1 potion slot etc. would be the same shape). *(Which relics use which is content.)*
- **Lifetime** — run-level: held in run-state, persists across fights, **saved** (Save PRD). Acquired at the guaranteed midpoint / per elite / per boss / character-start (the `Run manager` grants — design's acquisition rates).

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
- **Throw → resolve** — a **throw-potion intent** reaches the `Combat manager`, which activates the consumable: builds its payload(s), resolves the target-shape, spawns its Deliveries (combat_model.md) — the same resolution surface as an item fire, minus the Ticker. Effects are tactical (heal, instant block, freeze, instant damage, apply-status-to-all — design).
- **Slow-mo-on-hover** to inspect + throw during combat (design — opt-in agency; slows both sides).
- **Saved** — potions are run-state, in the snapshot (Save PRD).

---

## Prototype scope

**Built (2026-06-06):** all three categories, each proving its path end-to-end and wired into the run + headless autotest (starting-kit grants stand in for drafting them — slot composition is deferred):

- One **relic** — Stone Ward (a combat-start block status applier), in run-state, applied at each fight start, saved (`src/content/relics/relic*.gd`).
- One **enchant** — Whetstone (scale-a-value, +50%), applied to a chosen item, saved on the board entry; the Item fire pipeline scales payload values (`src/content/enchants/enchant*.gd`, `Item._resolve_effect`).
- One **consumable** — Healing Draught (a thrown self-heal), in a potion slot, fired via `RunManager.throw_potion` → `CombatManager.throw_consumable` → a travel-0 Delivery (`src/content/consumables/consumable*.gd`). **Not** in scope: the relic/potion/enchant pools' content, rarity tuning, the re-enchant + potion-drop sub-choice UIs, character starting-relic passives.

---

## Open / deferred

- **The pools' content** (relic / potion / enchant catalogues) + rarity tuning — content/design (the pool work).
- **Definition data formats — resolved (#23):** typed GDScript def objects + catalogs, not data files (player-facing strings stay localizable via `tr(def.name)` — `CLAUDE.md`).
- **Relics-as-items** — whether `Relic` and `Item` collapse to one type with different presentation (design open question) — resolve in prototype.
- **Re-enchant + the potion-drop / enchant-target sub-choice UIs** — a UI pass.
- **Character starting-relic passive trait** — the Characters PRD's (deferred).

## Dependencies

- **Calls down to:** `StatusManager` (relic/enchant status effects), `Combat manager` (a triggered relic's event-push Ticker; a thrown consumable's Delivery), `Item` (an enchant hooks its host's pipeline), `Actor` (relic direct mods).
- **Driven by (above):** the `Run manager` — holds them in run-state, applies a drafted pick (relic → relics, enchant → chosen item, potion → slot), grants relics on reward; `Draft` offers them; `Save` persists them (run-state).
- **Shares** the **Draftable** base with `Item` (Relic, Enchantment + Consumable; design).
