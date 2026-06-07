Author game content for Dark Corridor — items, enemies, relics, potions, enchants, encounters, statuses, characters. Orients a fresh session for the owner to design content with the agent as sounding board + scribe.

> **You (the agent) do NOT originate content.** The project owner designs it. Your job is to (1) be a **sounding board** — pressure-test ideas, surface tensions, connect them to the built systems, pitch options *with their costs* — and (2) **write down what the owner decides** into the right def file, keeping ids / catalogs / pools / running counts / cross-links consistent. The creative calls are the owner's; pitch, don't unilaterally invent-and-author. (Dev/debug strings stay English; player-facing text is localizable.)

## First, get oriented (read before authoring)

**The design — WHAT to make:**
- [`docs/design/influence_dcc.md`](../../docs/design/influence_dcc.md) — tone: *recombination* (fuse two recognisable things from different domains; humour is a byproduct, delivery stays grim). Shapes enemies / bosses / NPCs.
- [`docs/design/mushroom_druid.md`](../../docs/design/mushroom_druid.md) — the first character: the spore engine (Mass / Self ways to play, summon pillar).
- [`docs/design/card_pool_targets.md`](../../docs/design/card_pool_targets.md) — per-character breadth *signals* (held loosely, never quotas).
- [`docs/design/per_character_pools.md`](../../docs/design/per_character_pools.md) — decision #27: each character draws from its **own** item pool (+ a small shared colorless pool); enemies & the reward-relic pool stay shared.
- [`docs/project/design.md`](../../docs/project/design.md) — the whole-game snapshot (core loop, rarity = complexity not power, the damage/block/scaling triad, encounters, characters).

**The mechanics — HOW it works (read the one for what you're authoring):**
- Items → [`item_prd.md`](../../docs/project/item_prd.md) · statuses → [`status_manager_prd.md`](../../docs/project/status_manager_prd.md) · enemies → [`enemy_prd.md`](../../docs/project/enemy_prd.md) · relics / enchants / potions → [`content_prd.md`](../../docs/project/content_prd.md) · encounters / events → [`encounter_prd.md`](../../docs/project/encounter_prd.md) · the draft → [`draft_prd.md`](../../docs/project/draft_prd.md).
- Spore-build engine seams — status-stack **consume** (Mass fuel), **evasion** (blinding whiff), **summon** roster — all **BUILT** → [`spore_engine_prd.md`](../../docs/project/spore_engine_prd.md).
- Canonical record + open questions → [`decision-log.md`](../../docs/project/decision-log.md). Localization → [`reference/localization.md`](../../docs/reference/localization.md).

## How content is authored (the mechanics)

Content = typed GDScript def objects in static catalogs, **keyed by a string id** (decision #23), organized by kind under `src/content/<kind>/`: `items/` · `enemies/` · `relics/` · `consumables/` · `enchants/` · `encounters/` · `statuses/` · `characters/`. (Status *type* is still an enum — engine vocabulary.)

**To add a draftable item (the common case):**
1. Add a `_name() -> ItemDef` builder in `items/item_catalog.gd` (or a new themed file the catalog aggregates). Give it a **string id** with a const alias — `const POCKET_SHROOMS := 'pocket_shrooms'` — and set its effects (`ItemEffect`: kind / value / shape / travel / `status_type` / the `consume_*` / `summon_*` fields). Shared numbers point to `Balance`.
2. Register it in the catalog's `_build()` — `_defs[POCKET_SHROOMS] = _pocket_shrooms()`.
3. **Make it live** = add the id to a character's `item_pool` in `characters/character_catalog.gd` (or to `items/colorless_pool.gd` if it genuinely belongs to *every* character — the exception that earns it). A def that exists but is in no pool is "disabled" — *that* is the active/disabled mechanism: pool membership, not a flag or a folder.

Enemies / relics / potions / enchants / statuses follow the same **def + catalog** pattern in their own dir. A **character** is a `CharacterDef` (`characters/character_catalog.gd`): its own `item_pool`, starting board, starting relic, starting potions/enchants. After adding a new `class_name` script, run a headless `--import` once or the suite won't see the global.

**Player-facing strings** (names, encounter prose) are source-English on the def, shown via `tr(def.name_key)` — POT-extractable. Run the POT pipeline after adding strings (see `CLAUDE.md` / localization.md).

## What's buildable now

The spore engine is fully built (consume / evasion / summon), so the **entire spore pillar is authorable today** — appliers, Mass payoffs, blinding (whiff), lethal-as-execute, summon tokens, persistent allies. Nothing in the spore design is engine-gated.

## Working rhythm

- Run + test commands (Godot exe, GUT suite, headless autotest) are in [`docs/project/handoff.md`](../../docs/project/handoff.md). Keep the suite green; `--import` after adding a `class_name`.
- After authoring: update the relevant design doc if the design shifted, and the card-pool running counts. Commit coherent additions when the owner says so (`/c`).

ARGUMENTS: $ARGUMENTS
