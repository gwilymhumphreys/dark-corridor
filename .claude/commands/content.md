Author game content for Dark Corridor — items, enemies, relics, potions, enchants, encounters, statuses, characters. Orients a fresh session for the owner to design content with the agent as sounding board + scribe.

> **You (the agent) do NOT originate content.** The project owner designs it. Your job is to (1) be a **sounding board** — pressure-test ideas, surface tensions, connect them to the built systems, pitch options *with their costs* — and (2) **write down what the owner decides** into the right def file, keeping ids / catalogs / pools / running counts / cross-links consistent. The creative calls are the owner's; pitch, don't unilaterally invent-and-author. (Dev/debug strings stay English; player-facing text is localizable.)

## First, get oriented (read before authoring)

**The how-to — HOW to add a file:** [`docs/design/authoring.md`](../../docs/design/authoring.md) — the Content Authoring Guide (def + catalog pattern, string ids, where files go, how a draftable goes live). The single most-needed doc.

**The design — WHAT to make:**
- [`docs/design/influence_dcc.md`](../../docs/design/influence_dcc.md) — tone: *recombination* (fuse two recognisable things from different domains; humour is a byproduct, delivery stays grim). Shapes enemies / bosses / NPCs.
- [`docs/design/mushroom_druid.md`](../../docs/design/mushroom_druid.md) — the first character: the spore engine (Mass / Self ways to play, summon pillar).
- [`docs/design/character_ideas.md`](../../docs/design/character_ideas.md) — **parking lot** of uncommitted character concepts (Spore Druid promoted; Blade Mage, Wizard, Black Hole, Mechanic parked) + the **resource toolkit** for designing new characters: reusable resources (mana, heat, ammo, gold, HP, allies, items) placed on axes, and the `resource + theme` screen ("don't put a resource on its obvious home"). Where new character ideas land before they graduate to a working file.
- [`docs/design/card_pool_targets.md`](../../docs/design/card_pool_targets.md) — per-character breadth *signals* (held loosely, never quotas).
- [`docs/design/per_character_pools.md`](../../docs/design/per_character_pools.md) — decision #27: each character draws from its **own** item pool (+ a small shared colorless pool); enemies & the reward-relic pool stay shared.
- [`docs/project/design.md`](../../docs/project/design.md) — the whole-game snapshot (core loop, rarity = complexity not power, the damage/block/scaling triad, encounters, characters).

**The mechanics — HOW it works (read the one for what you're authoring):**
- Items → [`item_prd.md`](../../docs/project/item_prd.md) · statuses → [`status_manager_prd.md`](../../docs/project/status_manager_prd.md) · enemies → [`enemy_prd.md`](../../docs/project/enemy_prd.md) · relics / enchants / potions → [`content_prd.md`](../../docs/project/content_prd.md) · encounters / events → [`encounter_prd.md`](../../docs/project/encounter_prd.md) · the draft → [`draft_prd.md`](../../docs/project/draft_prd.md).
- Spore-build engine seams — status-stack **consume** (Mass fuel), **evasion** (blinding whiff), **summon** roster — all **BUILT** → [`spore_engine_prd.md`](../../docs/project/spore_engine_prd.md).
- Canonical record + open questions → [`decision-log.md`](../../docs/project/decision-log.md). Localization → [`reference/localization.md`](../../docs/reference/localization.md).

## The authoring how-to

The file mechanics — where each def goes, the string-id + catalog pattern, the other kinds, and how a draftable goes **live** — are in the **[Content Authoring Guide](../../docs/design/authoring.md)**. Read it before authoring. The one rule to internalize: **active / disabled = pool membership** — a def in no pool is authored-but-not-drafted; add/remove its id from a character's `item_pool` (or `colorless_pool`), not a flag, not a folder.

## What's buildable now

The spore engine is fully built (consume / evasion / summon), so the **entire spore pillar is authorable today** — appliers, Mass payoffs, blinding (whiff), lethal-as-execute, summon tokens, persistent allies. Nothing in the spore design is engine-gated.

## Working rhythm

- Run + test commands (Godot exe, GUT suite, headless autotest) are in [`docs/project/handoff.md`](../../docs/project/handoff.md). Keep the suite green; `--import` after adding a `class_name`.
- After authoring: update the relevant design doc if the design shifted, and the card-pool running counts. Commit coherent additions when the owner says so (`/c`).

ARGUMENTS: $ARGUMENTS
