# Plan: item pools, haste and slow, lives

Three changes the owner decided on 2026-11-20 (decisions #65, #66 and #68). They are independent, so
each is its own stage with its own tests, docs and commit. Reviewed against the code on 2026-11-20.

Suggested order: haste and slow first (fully specified), then lives, then item pools (waiting on the
first open question below).

## Stage A: haste and slow (decision #66)

Each is an on-or-off status on an actor with a duration. A new application adds its duration to the
time left. While one is on, the actor's item cooldown bars fill faster or more slowly over time.

### Current state

- `CombatManager.sim_step` fills each item's bar with `it.cooldown.step()`, which adds one step
  (`Ticker.step`). A gated item skips the call.
- `TimedStatus` already adds a reapplication's duration to the time left (`reapply` raises the
  ticker's threshold), and its `count` is unused, so it is the base both statuses need.
- `CombatHooks` is the hook base for statuses and relic passives; `StatusManager.hooks_of(actor)`
  lists them in order.

### Design

| Piece | What |
|---|---|
| `HasteMechanic`, `SlowMechanic` | New mechanics (`'haste'`, `'slow'`) in `src/content/mechanics/`, registered in `MechanicRegistry._build`, each naming its status. |
| `HasteStatus`, `SlowStatus` | Extend `TimedStatus`. Override a new hook, `cooldown_rate(target) -> float`, returning `Balance.HASTE_RATE` or `Balance.SLOW_RATE`. |
| `CombatHooks.cooldown_rate` | New hook, default 1.0. A relic passive can use it later ("your items fill 10% faster"). |
| `StatusManager.cooldown_rate(actor)` | The product of every hook's rate for that actor. |
| `Ticker.advance(amount)` | Adds `amount` steps; `step()` becomes `advance(1.0)`. |
| `CombatManager.sim_step` | Fills each item's bar with `advance(StatusManager.cooldown_rate(it.owner))`. |

- An effect applying haste or slow carries only a duration (`ItemEffect.duration`) and a target
  shape: self for haste, an opponent shape for slow. Its value is unused.
- Only the bar filling over time changes. Trigger pushes, the charge and decharge mechanics, status
  ticks and relics are unchanged.
- Determinism holds: the rate is read from statuses in a fixed order each step.

### Open

1. **Haste and slow on at once.** Multiplying the two rates is simplest. Cancelling each other out
   (rate 1.0) is the other option.
2. **Trigger pushes.** The owner said haste and slow affect only how fast bars fill. This plan reads
   that as time only, so a trigger still adds its authored seconds. Confirm.
3. **Display.** The health bar's `StatusNumbers` shows a stack count per mechanic status. Haste and
   slow have no stacks, so they need either the seconds left or the icon alone. The value pill on
   an item that applies them has the same question.
4. **Pricing.** Unpriced at first, like the attack bonuses. The parked note in `item_heuristics.md`
   on timed debuffs applies.
5. **Content the owner adds:** items that apply them, the two mechanic shops (`shop_haste`,
   `shop_slow`), icons in the `IconSlots` folders and the keyword card text.

### Tests

On fixture items: a hasted actor's item fires sooner and a slowed one's later by the expected steps;
reapplying adds duration; the status expires and the rate returns to 1.0; trigger pushes and charge
are unchanged; a gated item still does not fill; both statuses at once follow open question 1.

### Docs

`systems/mechanics.md` (the twelve, a new section), `status_manager.md` (the hook),
`combat_model.md` (the Ticker), `lexicon.md` (drop "planned"). The lexicon now says "slow" is not
used for a long-cooldown item; docs that still say "slow item" change to "long-cooldown item" in the
same stage. Item file comments are the owner's content and are left alone unless he asks.

## Stage B: full heal after every fight, and lives (decision #68)

### Current state

- `RunManager._on_encounter_resolved` ends the run on a lost fight (`_end_run(Outcome.DIED)`). A won
  fight runs `_apply_fight_won_gain` (`Balance.FIGHT_WON_HEAL` health and `Balance.FIGHT_WON_GOLD`).
- `advance()` calls `_full_heal()` when crossing into a new act; the run has one act, so it never
  happens.
- The rest encounter (`content/encounters/rest.gd`) is in `EncounterPools.RIGHT`.
- The run screen treats a resolved fight as won unless the run has ended
  (`run_screen.gd`, the `FIGHTING` state), then burns the square and the enemies.
- A fight's seed comes from the run seed and the beat position (`_combat_seed_for`), so fighting the
  same fight again with the same board gives the same result.

### Design

- `RunManager.lives: int`, starting at `Balance.STARTING_LIVES`, saved in the snapshot and read with
  a default.
- After every fight, won or lost, `_full_heal()` restores the player and the allies.
- A lost fight costs one life. At zero lives the run ends as now. Otherwise the fight resolves with
  no fight-won gold and no reward, and the run moves on to the next beat.
- A won fight gives gold and raises maximum health by `Balance.FIGHT_WON_MAX_HP` (a
  `RunEffect.max_hp`), replacing `FIGHT_WON_HEAL`. This is one way to make maximum health grow; see
  open question 2.
- `RunEffect.gain_life(n)` (new kind `LIFE`) for event options and relic run triggers.
- Lives in shops: a `StockEntry.lives(amount)` kind and a `LifeDef` that extends `ItemDef`, the way
  potions do (decision #57), so a life is shown and bought like any good. Its price is
  `Balance.SHOP_PRICE_LIFE`.
- `rest` leaves `EncounterPools.RIGHT`. The rest encounter type and its panel stay in the code.
- Run screen: a lost fight with lives left shows a panel ("a life lost", lives remaining, Continue),
  in the same style as the rest panel (decision #64), and the square does not burn. The lives are
  shown on the character sheet beside health.
- Autotest: the run carries on after a loss; the report records lives lost per fight, and the run
  outcome is DIED only when lives run out. Baselines change.
- `RunManager.RunEvent.FIGHT_LOST` can now exist, because a relic could react to a lost fight. It is
  added with the first relic that needs it.

### Open

1. **What a lost fight gives.** The plan gives nothing and moves on. Fighting it again would end the
   same way unless the board changed, because the fight's seed is fixed by its position.
2. **How maximum health grows.** The plan raises it a little for each won fight. Other options: a
   larger step after each elite and boss, or only through rewards and shops.
3. **A lost final boss with lives left.** The run cannot move past it. Options: the run ends anyway;
   or the player gets a choice of encounters (for a shop) and fights it again.
4. **Starting lives**, the life price and the health step: the owner's values.
5. **Enemy damage.** `item_heuristics.md` sets it from what a fight should cost in health, which no
   longer applies. A new rule is the owner's, decided in tuning.

### Tests

Full heal after a won and a lost fight, allies included; a loss with lives left costs one and moves
on with no reward; the last life ends the run; lives save and load; `gain_life`; buying a life;
maximum health rises per won fight; `rest` is not offered; the autotest continues after a loss.

### Docs

`run_manager.md` (health economy, lives, snapshot), `encounter.md` (rest, shops, run effects),
`save.md`, `run_screen.md` (the lost fight panel, the lives display), `autotest.md`, `lexicon.md`.

## Stage C: item pools (decision #65)

### Current state

- `CharacterDef.item_pool` lists item ids. `RunManager._draft_pool()` returns it plus
  `ColorlessPool.ITEMS` (empty). Rewards, shops and `has_items_for` all draw from `_draft_pool()`,
  and `CharacterCatalog.starting_board` draws from `item_pool`.
- `ItemDef.mechanics` is authored per item and already answers "should your poison items pick this
  one up" (decision #41). The mechanic shops filter by it (decision #59).
- An item in no character's list is never drafted. That is how Chunk of Flesh (created in fights),
  the enemy Claw and the example items stay out of drafts.

### Open question 1: filled by hand or from the mechanics list

**Manual.** A pool is a file listing item ids (`content/pools/<id>.gd`). An item listed in several
pools needs all of them. Every item is placed by hand.

**From the mechanics list.** A pool is a mechanic id, plus extra named pools for engines that are
not mechanics (Spores, Chunks of Flesh, summon). An item needs every pool in its `mechanics` list
and in a new `ItemDef.pools` list. Nothing is placed by hand. This works for most items today, with
three gaps:

- An item with an empty `mechanics` list, such as Mighty Blow, needs no pool. Either that means it is
  offered to every character, or every item must name at least one pool.
- The list sometimes leaves out a pool an item should need. The two forges give attack bonuses but
  list only burn, because the attack bonus is not a mechanic, so they would reach a character with
  burn and no attack items. The author adds `attack` to make them need it.
- Items that must never be drafted need a flag (`ItemDef.draftable = false`) instead of being left
  out of every list.

Type tags (weapon, armour and so on) are not needed to fill pools, because they describe the item's
fiction, and the mechanics already say what it does. They could later be a character-level filter.

### Design (either answer)

- `CharacterDef.item_pools: Array[String]` replaces `item_pool`.
- `ItemPools.items_for(pool_ids) -> Array` (new, `src/content/items/item_pools.gd`) returns every
  draftable item whose needed pools are all in `pool_ids`, in catalog order so draws stay
  deterministic.
- `_draft_pool()` and `starting_board` use it. `ColorlessPool` is removed: an item that needs no pool
  takes its place, if that is the answer to the first gap.
- Each character's `item_pools` is set so it is offered at least the items it has now. This also
  offers it every other character's items that its pools cover; that is the intended effect, but
  which pools each character holds is the owner's.

### Open

2. Which pools each character holds (content).
3. Whether a pool can be held by only one character, or any character can hold any pool.

### Tests

`items_for` with fixture items: an item needing two pools appears only when both are held; an
undraftable item never appears; the order is fixed. The fixture character moves to `item_pools`.
`test_pool_integrity`, `test_starting_board`, `test_draft` and `test_run_manager` change to read the
computed pool.

### Docs

`draft.md`, `run_manager.md`, `item.md`, `design/authoring.md` (how to place an item in a pool),
`content.md` if relics are affected (they are not planned to be).
