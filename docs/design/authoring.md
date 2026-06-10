# Content Authoring Guide

> How to add content to the game — the **file mechanics**. The *design* (what to make) lives in
> the other `docs/design/` files + [`design.md`](../project/design.md); the *systems* (how each
> kind works) live in the `docs/project/` PRDs. This is the bridge: where a def goes, how it's
> keyed, and how it goes live. The front door for content work is the **`/content`** skill.

## Ownership

The project owner designs the content; an assisting agent is a **sounding board + scribe** —
pressure-test ideas, surface tensions, connect them to the built systems, pitch options *with
their costs*, and write down what the owner decides. Agents don't originate content and author it
unilaterally; they pitch, the owner calls it. (Dev/debug strings stay English; player-facing text
is localizable.)

## The model

Content = typed GDScript **def objects** in static **catalogs**, keyed by a **string id**
(decision #23), organized by kind under `src/content/<kind>/`:

`items/` · `enemies/` · `relics/` · `consumables/` · `enchants/` · `encounters/` · `statuses/` · `characters/`

Each kind has a `*_def.gd` (the schema), a `*_catalog.gd` (the collection — lazily built, keyed by
string id), and where relevant a runtime instance class (`relic.gd`, `enchantment.gd`,
`consumable.gd`). **Statuses are the exception:** they are not def-objects but **polymorphic
`StatusEffect` subclasses** (one class per status, keyed by string id #23, registered in
`StatusRegistry`) — see below.

## To add a draftable item (the common case)

1. **Write the def.** Add a `_name() -> ItemDef` builder in `items/item_catalog.gd` (or a new
   themed file the catalog aggregates). Give it a **string id** with a const alias —
   `const POCKET_SHROOMS := 'pocket_shrooms'` — and set its effects via `ItemEffect` (kind / value
   / shape / travel / `status_id` + `duration` for a status applier, the `consume_id` Mass fields,
   the `summon_*` fields). Shared numbers point to `Balance`; the player-facing `name_key` is source English.
2. **Register it.** Add it to the catalog's `_build()` — `_defs[POCKET_SHROOMS] = _pocket_shrooms()`.
3. **Make it live.** Add the id to a character's `item_pool` in `characters/character_catalog.gd` —
   or to `items/colorless_pool.gd` if it genuinely belongs to *every* character (the exception that
   earns it, never a default tier — decision #27).

**Active / disabled = pool membership.** A def that exists but is in no pool is "disabled" — it's
authored and inspectable but never drafted. That is the toggle: add/remove the id from a pool. Not
a flag on the def, not a folder. (`HEX_BOLT` / `SUNDER` are catalog-only examples today.)

## Other kinds

Enemies, relics, potions, enchants, and encounters follow the same **def + catalog**
pattern in their own dir — see the matching PRD ([item](../project/item_prd.md) ·
[enemy](../project/enemy_prd.md) ·
[content](../project/content_prd.md) (relics/enchants/potions) · [encounter](../project/encounter_prd.md))
for each def's fields and how it resolves.

- A **status** is NOT a def — it's a **`StatusEffect` subclass** (`statuses/<name>_status.gd`)
  overriding the hooks it needs (`modify_outgoing`, `absorb`, `on_step`, …; default no-op),
  extending an intermediate base (`TimedStatus` / `PeriodicStatus` / `PoolStatus`) or `StatusEffect`
  directly. Set `id` / `name_key` / `color` by plain assignment in `_init` (the `name_key = '...'`
  assignment is what localizes it). Make it live with **one line** in `StatusRegistry` (`id →
  creator`). An applier (item/relic) references it by string id (`status_id = 'weak'`) and, for a
  timed status, sets `duration` (per-application). See [status PRD](../project/status_manager_prd.md).

- A **character** is a `CharacterDef` (`characters/character_catalog.gd`): its own `item_pool`,
  starting board, starting relic, starting potions/enchants. Adding a character = a def + registering
  it; the run picks one at `start`.
- **Enemies stay a shared pool** and the **reward-relic pool stays shared** — only *item* pools split
  per character (#27).

## After authoring

- **Added a new `class_name` script?** Run a headless `--import --exit` once or the test suite won't
  see the global (commands in [`../project/handoff.md`](../project/handoff.md)).
- **Player-facing strings** (names, encounter prose) show via `tr(def.name_key)` — run the POT
  pipeline after adding them ([localization](../reference/localization.md)).
- Keep the GUT suite green; update the relevant design doc if the design shifted, and the card-pool
  running counts. Commit coherent additions (`/c`).

## What's buildable now

The spore engine is fully built — status-stack **consume** (Mass fuel), **evasion** (blinding
whiff), and **summon** (mid-fight roster + persistent allies); see
[`../project/spore_engine_prd.md`](../project/spore_engine_prd.md). So the **entire spore pillar is
authorable today**: appliers, Mass payoffs, blinding, lethal-as-execute, summon tokens. Nothing in
the spore design is engine-gated.
