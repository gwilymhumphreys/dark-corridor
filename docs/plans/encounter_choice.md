# Plan: a choice of three encounters before every fight

Before each fight the player is offered three encounters and picks one. Each encounter has its own
choice inside it: an event's options, a reward's pick, or a shop's goods. Encounters have a rarity,
rules that decide when they can appear, and can remember what the player did so a later visit
offers different options.

Related: [`../systems/run_manager.md`](../systems/run_manager.md),
[`../systems/encounter.md`](../systems/encounter.md), [`../systems/save.md`](../systems/save.md),
[`../systems/run_screen.md`](../systems/run_screen.md), [`encounter_points_budget.md`](encounter_points_budget.md).

**Naming is open.** This plan says "encounter" for the things offered in threes, because that is the
owner's word. The code keeps `EncounterDef` and `Encounter` for every beat, fights included, so a
new player-facing word would be a lexicon change, not a rename. Candidates are listed under
[Open questions](#open-questions).

## What there is now

- Each act is `RunMap.SQUARES`: fights, two elite fights, the relic encounter and the boss. Four events
  go into gaps drawn from the run seed (`act_layout`, `EVENT_GAPS`).
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

## The map

- `SQUARES` loses the relic square, leaving fights, two elite fights and the boss. The order stays
  content for the owner.
- Every square has a choice beat straight before it, the first fight included. `BEATS_PER_ACT` becomes
  twice the number of squares. A choice beat is at an even beat in the act, a square at an odd one.
- `act_layout`, `EVENT_GAPS`, `EVENTS_PER_ACT` and `LAYOUT_SEED_STRIDE` are removed; the layout is
  fixed.
- `ACTS` stays a constant. Whether the run is one act or several is the owner's call once this plays.
- `beat_spec` returns a new `BeatKind.CHOICE` for a choice beat. Squares keep their current specs.
- The points curve and `Balance.POINTS_DRAFTS_PER_BEAT` count beats, and half the beats are no longer
  fights. `target_points` takes the fight number (`RunMap.fight_number(position)`) instead, and the
  constant becomes drafts per fight.
- `MapStrip` already puts a marker on the line before a square during an event. The same marker shows
  during a choice beat and its encounter.

## Drawing the three

`RunManager._enter_beat` draws the offer for a choice beat into `_pending_choice`, and `pick_path`
creates the picked `Encounter`, as the dormant code already does.

1. **Candidates.** `EncounterPools.CHOICE` lists the encounter ids that can be offered. An encounter in
   no list is authored but never met, as with items and enemies.
2. **Requirements.** An encounter whose `requires` conditions do not all hold is left out.
3. **Weight.** Each remaining encounter's weight is its rarity weight (`Balance.ENCOUNTER_WEIGHT_COMMON`,
   `Balance.ENCOUNTER_WEIGHT_RARE`) multiplied by the multiplier of every weight rule whose condition
   holds.
4. **Draw.** Three different encounters are drawn by weight on the run random number generator. If
   fewer than three are eligible, the offer is smaller. If none are, the beat is skipped with a
   warning; a content check makes sure at least three encounters have no requirements.

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
| `FightBetween` | The next fight's number is in a range. Covers "only in act 2" as well. |
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
  whose conditions do not hold is hidden. For example, the first visit to a shrine offers "Leave an
  offering", which sets a flag and does nothing else; a later visit offers "Take back the offering,
  blessed", which requires that flag and gives a relic.

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

`RunEffect.amount` stays an integer. `HEAL_FRACTION` needs a fraction, so the effect gets a `fraction`
field, or it takes a percentage. The id kinds use a new `id` field.

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
| Event | The options whose conditions hold, as now. |
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

Adding an encounter of an existing kind is one file in `content/encounters/` and an entry in
`EncounterPools.CHOICE`. Adding a new kind touches `EncounterDef.Type`, `Encounter.begin`, the run
screen's overlay choice, `ChoiceCard` and the autotest driver. Most new encounters are expected to be
new data for the existing kinds.

## Presentation

- `ChoiceCard` shows the encounter's name, its kind (Event, Reward, Shop, Rest), a hint (the goods for
  a reward or shop), and its rarity. Its fight categories go.
- A new shop overlay in the corridor area, like the event overlay: the goods as reward options, each
  with a price, a buy button that is disabled when the player cannot afford it, the player's gold, and
  a leave button.
- The event overlay shows only the options whose conditions hold.

## Save

The snapshot gains `pending_choice` (the offered ids, because the random number generator has moved
past the draw), `flags` and `times_picked`. No migration. A save made at a choice beat has no `current_def_id`, so
`_snapshot_usable` accepts an empty one when `pending_choice` is present, and `rehydrate` restores the
offer instead of creating an encounter.

## Autotest

- `choose_path` stays a seeded random pick.
- A shop buys nothing and leaves. A reward takes the first good.
- Every baseline changes, because the map changes.

## Stages

Each stage leaves a playable run.

1. **Map and choice.** The new map, the choice beat, the draw with no rarity or rules, `pending_choice`
   in the snapshot, the fight-number points curve, the map strip marker, and `ChoiceCard` for the
   non-fight kinds. The relic encounter, both events and the rest go into `EncounterPools.CHOICE`.
2. **Rarity and conditions.** `rarity`, `requires`, `weights`, the condition classes, and the weighted
   draw.
3. **Effects and memory.** `effects` on options, the new `RunEffect` kinds, `flags`, `times_picked`,
   and option conditions. The existing placeholder events are converted.
4. **Rewards.** Stock entries, the mixed pending offer, the reward kind, and a potion pool. The relic
   encounter becomes a reward encounter.
5. **Shops.** The shop kind, prices, and the shop overlay, with one placeholder shop for testing.

Docs updated in each stage: `run_manager.md`, `encounter.md`, `save.md`, `run_screen.md`,
`autotest.md`, `lexicon.md` (the choice word, run flag, encounter rarity, and the Square, Event and
Relic encounter rows), and a decision log entry. The "Encounters and the choice layer" section of
`design/game_design.md` describes the older choice layer; that section is the owner's to rewrite.

## Tests

On fixtures ([`../systems/testing.md`](../systems/testing.md)): the map layout, the draw (distinct ids,
requirements, weights, empty and short pools), every condition, every effect, flags and
`times_picked` surviving a save and resume, option conditions, the mixed offer, shop purchases and
affordability. A content check that every id in `EncounterPools.CHOICE` resolves and that at least
three have no requirements.

## Open questions

1. **The word.** Keep "encounter", or give the offered things their own name. Candidates in the game's
   theme: "room" (the player picks one of three doors off the corridor), "detour", "side passage".
2. **Acts.** One act of ten fights, or keep several.
3. **Skipping.** Whether the player can walk past all three. The plan has no skip.
4. **Hidden or shown.** Whether an option whose conditions fail is hidden or shown disabled with the
   reason. Showing it tells the player what to aim for.
5. **Variety in an offer.** Whether the three must be different kinds (for example, at most one shop).
6. **Gold income.** Gold only comes from skipping drafts today, a small amount each, so a shop has
   little to sell against. Fights, events or rewards may need to give gold.
7. **Rarity on the card.** Whether the player sees an encounter's rarity before picking.
