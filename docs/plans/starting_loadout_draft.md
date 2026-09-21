# Plan — Starting Loadout Draft

> **Status: partly shipped (2026-09-21).** The *randomised opening board* is built, without the
> choice: a character lists `starting_item_types` and `CharacterCatalog.starting_board` draws one
> item of each from its pool on the run RNG. What is still unbuilt is the **1-of-3 choice** below —
> the offer, the UI overlay and the pending-offer path. The constraint model also changed: the rule
> is now per-character type constraints, not the single "at least one attacking item" rule. If the
> choice is built later, it should generate its three sets through `starting_board` rather than a
> second generator.
>
> **Original status: planned, not built (2026-06-24).** A run-opening mechanic the owner floated: after
> character select, the player chooses **1 of 3 randomly-generated starting sets**, each a bundle of
> **3 items** with **at least one attacking item**. Replaces the hand-authored fixed starting kit so
> the first fights aren't dull and the opening is a real decision. Plans aren't catalogued in the
> index (transient); this graduates to a `systems/` doc when it ships.
>
> *Name is a placeholder — "starting set" / "loadout draft" are working terms (owner's words: "item
> sets"), to ratify.*

## Resolved decisions (owner, 2026-06-24)

1. **"Attacking item" = a DAMAGE effect aimed at the ENEMY** (an opponent target shape —
   `OPPONENT_LEFTMOST` / `ALL_OPPONENTS`), **not** `SELF`. Derived from the item's `effects` (no new
   metadata) — a small `ItemDef.deals_enemy_damage()` helper. **Self-damage does not count:** the
   Fleshmancer's **Flensing Hook** has a DAMAGE effect but targets `SELF`, so a set whose only
   "attacker" were Flensing Hook couldn't threaten the enemy — it must NOT satisfy the rule. (Real
   Fleshmancer attackers: Carving Knife, Cleaver, Bone Saw, Bone Spear, Flesh Explosion.) Could
   broaden to "offensive" (enemy debuffs too) later; not now.
2. **The chosen set IS the entire opening board.** `CharacterDef.starting_item_ids` is retired —
   the board always comes from the picked set. Starting **relic / potion / enchant** stay as-is
   (they're not items in the set). Engine-critical guarantees (e.g. the Druid always getting a spore
   applier) become later *generation rules*, not a fixed signature item.

## Model

- **Offer:** 3 sets × 3 items, drawn from the character's pool (`item_pool` + colorless — the same
  source `Draft` uses, decision #27). Seeded from the **run RNG** (deterministic, not save-scummable;
  like `Draft`, #17/#20).
- **Generation (constructive, per set):** draw 1 from the pool's *damage-dealing* items, then fill 2
  more **distinct within the set** from the full pool. Across the 3 sets: independent draws (repeats
  across sets allowed). Graceful degrade: pool < 3 distinct → allow within-set repeats; pool has no
  damage item → drop the constraint + log (shouldn't happen for a real pool).
- **Rules are an extensible list.** v1 = `[at_least_one_damage]`. Keep the constraint a small list so
  "more rules later" is additive (future: ≥1 block, an engine-starter per character, a rarity mix).
  Constructive satisfies v1 directly; a bounded validate-then-reroll fallback covers future rules.

## Flow & wiring

A new choice step **after character select, before the first beat** — mirrors the `Draft` offer/apply
pattern (#17: the RunManager holds the offer, the UI presents, the pick applies). It is a **within-run
pending offer + run-screen state**, NOT a top-level `Game.Phase` — the same shape as the reward draft
and the dormant choice layer, so the autotest (no run screen) and the UI drive it through the same
RunManager API:

1. `RunManager.start(seed, character)` seeds the run RNG, **generates the 3 starting sets**, holds
   them as a pending offer, and leaves the board **empty** (no `starting_item_ids`). It does **NOT**
   create the first encounter yet (that would run beat 0 on an empty board).
2. `has_pending_loadout()` / `pending_loadout_sets()` / `pick_loadout(index)`: the pick seeds
   `player.board` from the chosen set, clears the pending offer, **then** creates the first encounter
   + auto-saves (the deferred run-start tail). The run can't advance to beat 0 until a set is picked.
3. **Resume:** the choice precedes the first auto-save (encounter entry), so a quit-before-pick
   regenerates the same 3 sets from the saved RNG state — deterministic, no special persistence.

## Pieces to build

- **Engine:** `ItemDef.deals_damage()` (a DAMAGE-effect predicate, reusable — the autotest strategies
  can share it); the set generator (a `Draft.draw_starting_sets(pool, rng, set_count, set_size)`
  method — `Draft` is already the stateless pool-draw service); the rule list.
- **RunManager / Game:** generate + hold the pending offer at run start; the `pick_loadout` apply
  path; the `LOADOUT` phase. Remove the `starting_item_ids` board-seed.
- **UI:** a `starting_loadout_overlay` (3 sets × 3 item cards, reusing `draft_card` visuals) between
  character-select and the run, wired in the run-screen FSM.
- **Autotest:** `AutoTestDriver.choose_starting_set(sets)` (default: pick index 0; strategy-aware
  later) + `AutoTestMode.run_full` applying it after `start_run`.
- **Migration:** retire `CharacterDef.starting_item_ids` (and its use) across all character defs;
  keep relic/potion/enchant starts. Update tests that read it (`test_pool_integrity`,
  `test_run_manager`, `test_character_select`).
- **Tests:** generator (≥1 damage item, distinct-within-set, seeded determinism, graceful degrade);
  `pick_loadout` seeds the board; a full autotest descent still wins.
- **Docs:** graduate to a `systems/` doc on ship; note the run-flow change in the run-screen +
  run-manager docs + `game_design.md`.

## Review findings (2026-06-25)

- **DECISION NEEDED — starting enchants orphan.** `CharacterDef.starting_enchants` pins to a board
  **index** (`{ 'item_index': 0, 'enchant_id': WHETSTONE }`) of the *fixed* starting items. With the
  board now a chosen random set, that index is meaningless. (The Wanderer, the only character that
  carried a Whetstone-on-item-0 start, has since been deleted, so nothing uses the field today.)
  Options: **(a)** retire starting enchants too (relic + potion stay;
  enchants are earned via draft) — *recommended, simplest, kills the index coupling*; **(b)** a later
  generation rule attaches a starting enchant to the chosen attacker (re-introduces coupling). The
  earlier "enchant starts stay as-is" line in this plan is **wrong** — only relic + potion stay
  cleanly.
- **The "≥1 damage" rule guarantees existence, not a viable opener.** Flesh Explosion satisfies it
  but is a 20s-cooldown destroy-charged AOE — a dead opener. v1 accepts this (the rules list is how
  you'd add "≥1 *low-cooldown* attacker" later); name it so it isn't a surprise.
- **RNG stream shifts.** Adding a run-start draw moves every existing seed→outcome mapping. No save
  migration (dev), so fine — but current autotest seed baselines change.
- **Generator home is a judgment call.** A method on `Draft` (cohesion — it's the pool-draw service)
  vs. a separate `StartingLoadout` generator (the ≥1-attacker constraint + set-bundling are new
  responsibilities). Lean `Draft` method; revisit if the constraint logic grows.
- **UI is a new 9-card layout** (3 sets × 3), not a drop-in reuse of `draft_overlay` (which shows 3
  single cards). Reuses `draft_card` visuals, new grouping/container.

## Open / later

- Strategy-aware autotest set pick (v1 just picks index 0).
- Cross-set distinctness (v1 allows repeats across the 3 sets).
- Future generation rules (≥1 block, per-character engine-starter guarantees, rarity mix) — the
  reason the rule list is a list.
- Whether a "reroll the sets" affordance exists (probably not — deterministic by design).
