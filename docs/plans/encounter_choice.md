# Plan: a choice of three encounters before every fight

**Status: stages 1 and 2 built 2026-09-30.** As-built detail is in
[`../systems/run_manager.md`](../systems/run_manager.md#the-choice-of-encounters),
[`../systems/encounter.md`](../systems/encounter.md#offer-rules) and
[`../systems/run_screen.md`](../systems/run_screen.md#the-choice-of-encounters). Stages 3 to 5 are still
to build. Differences from the plan are listed at the end.

Before each fight the player is offered three encounters, shown as cards standing in the corridor
where enemies stand, and picks one or walks past them for a little gold. Each encounter has its own
choice inside it: an event's options, a reward's pick, or a shop's goods. Encounters have a rarity,
rules built from the player's state that decide when they can appear, and can remember what the
player did so a later visit offers different options.

Related: [`../systems/run_manager.md`](../systems/run_manager.md),
[`../systems/encounter.md`](../systems/encounter.md), [`../systems/save.md`](../systems/save.md),
[`../systems/run_screen.md`](../systems/run_screen.md), [`encounter_points_budget.md`](encounter_points_budget.md).

"Encounter" stays the word (owner, 2026-09-29). The code keeps `EncounterDef` and `Encounter` for every
beat, fights included.

## What there is now

- The run is three acts. Each act is `RunMap.SQUARES`: fights, two elite fights, the relic encounter and
  the boss. Four events go into gaps drawn from the run seed (`act_layout`, `EVENT_GAPS`).
- The choice layer from before the current map is still wired but never used: `RunManager._pending_choice`,
  `pending_choice()`, `pick_path()`, `ChoiceOverlay` and `ChoiceCard`, the run screen's CHOOSING
  state, and `AutoTestDriver.choose_path`.
- An event option has one effect (`EventOptionDef.effect`): heal a fraction, raise maximum health, take
  damage or add an ally. The Encounter applies the first three and the RunManager applies the ally.
- `RunEffect` (maximum health, heal, gold) is applied by `RunManager._apply_run_effect` for relic run
  triggers, and repeats the maximum health code in `Encounter._apply_event_outcome`.
- Gold comes only from skipping a draft (`Balance.GOLD_SKIP`) and relic run triggers. Nothing spends it.
- There is a relic reward pool (`RelicCatalog.REWARD_POOL`) but no potion pool, and no screen for
  choosing which item an enchant goes on.
- Enemy readouts are Controls placed over the corridor at points unprojected from the enemies'
  arrived positions (`CombatCorridor.enemy_anchor`), and fade in over the end of the approach
  (`CombatView.show_enemies`).

## The map

- One act (`ACTS = 1`, owner). `SQUARES` loses the relic square, leaving fights, two elite fights and
  the boss: ten fights. The order stays content for the owner.
- Every square has a choice beat straight before it, the first fight included, so the run is twenty
  beats. A choice beat is at an even position, a square at an odd one.
- `act_layout`, `EVENT_GAPS`, `EVENTS_PER_ACT` and `LAYOUT_SEED_STRIDE` are removed; the layout is
  fixed.
- `beat_spec` returns a new `BeatKind.CHOICE` for a choice beat. Squares keep their current specs.
- The points curve and `Balance.POINTS_DRAFTS_PER_BEAT` count beats, and half the beats are no longer
  fights. `target_points` takes the fight number (`RunMap.fight_number(position)`) instead, and the
  constant becomes drafts per fight. The curve's values were set for a 45 beat run and need retuning
  with `/tune`; only the first act's `EnemyPools` lists are used.
- `MapStrip` already puts a marker on the line before a square during an event. The same marker shows
  during a choice beat and its encounter.

## After each fight

Every fight won, elites and the boss included, gives the player `Balance.FIGHT_WON_HEAL` health and
`Balance.FIGHT_WON_GOLD` gold (owner), applied through `_apply_run_effect` before the reward. The draft
panel shows what was gained. The final boss ends the run, so it gives nothing.

## Drawing the three

`RunManager._enter_beat` draws the offer for a choice beat into `_pending_choice`, and `pick_path`
creates the picked `Encounter`, as the dormant code already does.

1. **Positions.** `EncounterPools` has three lists, one per position left to right. Every encounter
   goes in one list. The left list holds the shops, so the left card is always a shop (owner). An
   encounter in no list is authored but never met, as with items and enemies.
2. **Requirements.** An encounter whose `requires` conditions do not all hold is left out.
3. **Weight.** Each remaining encounter's weight is its rarity weight (`Balance.ENCOUNTER_WEIGHT_COMMON`,
   `Balance.ENCOUNTER_WEIGHT_RARE`) multiplied by the multiplier of every weight rule whose condition
   holds.
4. **Draw.** One encounter per position, by weight, on the run random number generator, never the same
   encounter twice in one offer. An encounter the player cannot choose is never offered, so all three
   cards can always be picked (owner). A position with nothing eligible in its own list takes an
   eligible encounter from the other lists instead, so the offer is always three while at least three
   encounters are eligible. A content check makes sure every list has an encounter with no
   requirements.

**Skipping.** The player can walk past all three, which banks `Balance.ENCOUNTER_SKIP_GOLD` gold
(owner) and goes straight to the next fight. `RunManager.skip_choice()` sits beside `pick_path`.

### Conditions

A condition is a small class with `holds(run: RunManager) -> bool`. It only reads the run. Each kind is
one file under `src/run/conditions/`, so a new kind of rule is one new file. The same conditions are
used for an encounter's requirements, its weight rules, and its options (below).

| Condition | Holds when |
|---|---|
| `HasItems` | The board holds each listed item id, at least the given count of each. Several ids make a combination. |
| `HasItemType` | The board holds at least N items with a type tag (`ItemDef.types`). |
| `HasRelic` | The run holds a relic id. |
| `HealthBelow`, `HealthAbove` | Current health is below or above a fraction of maximum health. |
| `GoldAtLeast` | Gold is at least an amount. |
| `FlagAtLeast`, `FlagBelow` | A run flag (below) is at least, or below, a value. An unset flag is 0. |
| `FightBetween` | The next fight's number is in a range. |
| `TimesPicked` | This encounter has been picked at least, or at most, N times this run. |
| `CanAddAlly` | The run has a free ally slot. |
| `Not`, `AnyOf` | The inverse of one condition, or any of several. A plain list already means all of them. |

On the definition:

```gdscript
rarity = Rarity.RARE
requires = [HasItemType.new('blade', 3)]
weights = [{ 'if': HealthBelow.new(0.4), 'multiplier': 3.0 }]
```

## Remembering what happened

- **Run flags.** `RunManager.flags` is a dictionary from a flag name to a whole number, saved in the
  snapshot. An effect sets or adds to a flag. Nothing shows flags to the player.
- **Times picked.** `RunManager.times_picked` counts how often each encounter id was picked, saved in
  the snapshot. It is kept automatically, so "the second visit" needs no flag.
- **Options with conditions.** Every event option gets `requires`, a list of conditions. An option
  whose conditions do not hold is shown disabled, with the tooltip "You do not meet the requirements
  for this" (owner). For example, the first visit to a shrine offers "Leave an offering", which sets a
  flag and does nothing else; a later visit offers "Take back the offering, blessed", which requires
  that flag and gives a relic.

## Option effects

An option carries `effects: Array[RunEffect]` in place of `effect`, `amount` and `ally_def_id`, so one
option can cost something and give something. The RunManager applies every effect through
`_apply_run_effect`, and the Encounter no longer changes the player itself. Relic run triggers use
the same list, so they gain the new kinds too.

| `RunEffect.Kind` | Does |
|---|---|
| `MAX_HP`, `HEAL`, `GOLD` | As now. A negative `GOLD` is a cost. |
| `HEAL_FRACTION` | Heal a fraction of maximum health. |
| `DAMAGE` | Take damage. Lethal damage ends the run as a loss, as now. |
| `ADD_ALLY` | Add an ally by id. |
| `SET_FLAG`, `ADD_FLAG` | Set or add to a run flag. |
| `GAIN_ITEM`, `GAIN_RELIC`, `GAIN_POTION` | Add a named item, relic or potion. |

`RunEffect.amount` stays an integer, so `HEAL_FRACTION` gets a `fraction` field. The flag and id kinds
use a new `id` field.

## Encounter kinds

`EncounterDef.Type` becomes `FIGHT`, `EVENT`, `REWARD`, `SHOP` and `REST`. `RELIC` goes: the relic
encounter becomes a reward encounter. Every definition gets `rarity` (`Rarity.COMMON`, `Rarity.RARE`),
`requires` and `weights`.

Reward encounters and shops both describe what they offer with the same list of **stock entries**.
Each entry names a kind of goods (items, relics, potions), an optional list of item type tags, and a
count. A shop's theme is its name and its stock entries: a weaponsmith might list only items tagged
`weapon`, an apothecary only potions.

| Kind | The choice inside it |
|---|---|
| Event | Its options, as now, with the unmet ones disabled. |
| Reward | Pick one from goods drawn from the stock entries, in the draft panel. The relic encounter is a reward of three relics. |
| Shop | Goods drawn from the stock entries, each with a price. Buy any the player can afford, then leave. |
| Rest | A heal on arrival, as now. |

- Items come from the character's pool plus the colourless items, as the draft does, filtered by type.
  Relics come from `RelicCatalog.REWARD_POOL`. Potions need a new pool list.
- Enchants are left out until there is a screen for choosing which item an enchant goes on.
- Shop prices are `Balance` values by goods kind and rarity, as placeholders.
- A shop's goods are drawn when it begins, from the run random number generator, so a resumed shop
  shows the same goods. Purchases are not saved until the next beat, so quitting in a shop returns
  to its entrance with the gold unspent.

The pending draft offer (`_pending_offer`, items only) and the relic offer (`_pending_relic_offer`) are
replaced by one pending offer of mixed goods, used by fight drafts, reward encounters and the elite's
draft. `DraftOverlay` and `RewardOption` already show items and relics; they read the one offer.

Adding an encounter of an existing kind is one file in `content/encounters/` and an entry in one
`EncounterPools` list. Adding a new kind touches `EncounterDef.Type`, `Encounter.begin`, the run
screen's overlay choice, the encounter card and the autotest driver.

## Presentation

- **Cards in the corridor.** A choice beat walks up the corridor like a fight approach, with no enemy.
  The three encounters are card buttons (`EncounterCard`, a scene reworked from `ChoiceCard`) placed
  over the corridor at the three points where three enemies would stand, with an empty position left
  blank. `enemy_anchor` needs enemy sprites, so a new `CombatCorridor.slot_point(i, n)` unprojects
  the same positions (`_offset_x`, the arrived depth) with no sprite. They take
  the theme's worn panel, `UIJuice` for hover, press and sound, and come in over the end of the
  approach as the enemy readouts do, animated with `offset_transform_*`.
- A card shows the encounter's name, its kind (Shop, Event, Reward, Rest) and a hint (the goods for a
  reward or shop). Rarity changes the card's border or background colour; this can come after the
  rest (owner).
- A **Walk past** button under the cards shows the skip gold.
- Picking a card removes the others, and the encounter's own panel opens in the corridor area as the
  event and draft panels do now. `ChoiceOverlay` is removed.
- A new shop panel: the goods as reward options, each with a price, a buy button that is disabled when
  the player cannot afford it, the player's gold, and a leave button.
- The event panel shows every option, with the unmet ones disabled.

## Save

The snapshot gains `pending_choice` (the offered ids by position, because the random number generator
has moved past the draw), `flags` and `times_picked`. No migration. A save made at a choice beat has no
`current_def_id`, so `_snapshot_usable` accepts an empty one when `pending_choice` is present, and
`rehydrate` restores the offer instead of creating an encounter.

## Autotest

- `choose_path` stays a seeded random pick and never skips.
- A shop buys nothing and leaves. A reward takes the first good.
- Every baseline changes, because the map changes.

## Stages

Each stage leaves a playable run.

1. **Map and choice.** One act, the new map, the choice beat with the three position lists and an
   unweighted draw, skipping for gold, the fight-won health and gold, `pending_choice` in the
   snapshot, the fight-number points curve, the map strip marker, and the cards in the corridor. The
   relic encounter, both events and the rest go into the position lists; the left list stays empty
   until shops exist.
2. **Rarity and conditions.** `rarity`, `requires`, `weights`, the condition classes, the weighted
   draw, and the rarity colour on the card if the owner wants it now.
3. **Effects and memory.** `effects` on options, the new `RunEffect` kinds, `flags`, `times_picked`,
   and disabled options. The existing placeholder events are converted.
4. **Rewards.** Stock entries, the mixed pending offer, the reward kind, and a potion pool. The relic
   encounter becomes a reward encounter.
5. **Shops.** The shop kind, prices, and the shop panel, with one placeholder shop in the left list.

Docs updated in each stage: `run_manager.md`, `encounter.md`, `save.md`, `run_screen.md`,
`autotest.md`, `lexicon.md` (run flag, encounter rarity, and the Square, Event and Relic encounter
rows), and a decision log entry. The "Encounters and the choice layer" section of
`design/game_design.md` describes the older choice layer; that section is the owner's to rewrite.

## How stages 1 and 2 differ

- A card wider than its share of the row is scaled down (`EncounterChoice.CARD_FILL`), because three
  enemies at their arrived depth stand closer together than a card is wide.
- `--autofight` walks past every choice, so a screenshot run still goes straight to a fight.
- `test_target_ends_far_above_where_it_starts` now expects the last fight to be worth more than four
  times the first, not ten, since the run is ten fights instead of 45 beats.
- `FlagAtLeast`, `FlagBelow` and `TimesPicked` move to stage 3, which adds the run flags and pick
  counts they read.
- `FightBetween` counts fights from 1, as the map's squares are numbered for the player.
- The rarity colour on the card is left for later (owner).
- The placeholder recruit event requires `CanAddAlly`, so it is not offered once the ally slots are
  full.

## Tests

On fixtures ([`../systems/testing.md`](../systems/testing.md)): the map layout, the draw (one per
position, requirements, weights, empty lists), skipping, the fight-won gain, every condition, every
effect, flags and `times_picked` surviving a save and resume, disabled options, the mixed offer, shop
purchases and affordability, and the cards' placement. A content check that every id in the position
lists resolves, and that every list has an encounter with no requirements.
