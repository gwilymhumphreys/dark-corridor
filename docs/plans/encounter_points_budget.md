# Plan: encounter budgets in points

Generate each fight's enemies from a target points value instead of authoring a fixed composition
per encounter. The target comes from a fixed curve calculated once ahead of time, not measured
during the run.

Pricing rules this builds on: [`../design/item_heuristics.md`](../design/item_heuristics.md).
Existing run structure: [`../systems/run_manager.md`](../systems/run_manager.md),
[`../systems/encounter.md`](../systems/encounter.md).

## What it is for

The owner authors a set of enemies. The run picks a mix of them to meet a target, so pacing is one
curve rather than a composition authored per beat. Enemies and items are already in the same unit,
because health is priced at a point per health and enemy items sit on the same budget curve as the
player's.

## The blocker

**The player's board has no size cap.** `RunManager.apply_draft_pick` appends to `player.board`
unconditionally, so the board grows by one item for every regular fight won. Over 45 beats that is
roughly 27 items. Every number below depends on that growth rate, so if a cap is wanted, it has to
be decided before the curve is fixed. This is a pre-existing gap, not something this plan
introduces.

## The fixed curve

The target is calculated from an estimate of the player's board, not from the actual board.

```
items(n)     = STARTING_ITEMS + DRAFTS_PER_BEAT × n
damage(n)    = items(n) × AVERAGE_ITEM_RATE × DAMAGE_FRACTION
target(n)    = damage(n) × FIGHT_SECONDS × (1 + SYNERGY_GROWTH × n / TOTAL_BEATS)
```

`n` is the global beat index, 0 to 44. Each factor is an estimate to be tuned, and all of them
belong in `Balance`:

| Factor | Starting value | Where it comes from |
|---|---|---|
| `STARTING_ITEMS` | 3 | The starting board floor. Every character now draws three items at run start from its type constraints. |
| `DRAFTS_PER_BEAT` | 0.84 | Measured, not estimated: a full autotest run ends on a 41 item board from a 3 item start over 45 beats. |
| `AVERAGE_ITEM_RATE` | 8.11 | The budget curve's rate at a 4 second cooldown, taken as the average draft. |
| `DAMAGE_FRACTION` | 0.7 | The share of a board's output that is damage rather than shield or healing. |
| `FIGHT_SECONDS` | 20 | How long a regular fight should last. It does not change across the run. |
| `SYNERGY_GROWTH` | 0.5 | How much harder the curve gets than the raw board estimate, to cover synergies, relics and enchants without modelling them. |

The synergy factor is the one knob that covers everything the estimate cannot see. It is a single
multiplier that grows through the run rather than a model of what combines with what.

| Beat | Act.beat | Estimated items | Target |
|---|---|---|---|
| 0 | 1.0 | 3.0 | 340 |
| 7 | 1.7 | 8.9 | 1088 |
| 14 | 1.14 | 14.8 | 1941 |
| 22 | 2.7 | 21.5 | 3047 |
| 29 | 2.14 | 27.4 | 4128 |
| 37 | 3.7 | 34.1 | 5493 |
| 44 | 3.14 | 40.0 | 6802 |

Elites take a multiplier on the same curve rather than a curve of their own. Bosses are hand-authored
and not generated.

### What an enemy should be worth

The pools have to be banded, because one flat pool cannot serve a target of 340 and a target of 4128
within a 1 to 4 enemy limit. Taking a two-enemy fight as typical, this is the range to author to:

| Act | Target range | Typical enemy |
|---|---|---|
| 1 | 340 to 1941 | 170 to 971 |
| 2 | 2072 to 4128 | 1036 to 2064 |
| 3 | 4291 to 6802 | 2145 to 3401 |

## The generator

`RunManager._enter_beat` already resolves the beat and builds the `Encounter` right after the
previous beat's reward, so there is no new timing to add. Generation goes there.

1. Read the target for the beat, with the elite multiplier applied if the def's reward is ELITE.
2. Draw enemies from the act's pool on the run RNG until the total is within a tolerance of the
   target, respecting the existing 1 to 4 enemy limit.
3. Pass the drawn ids to the `Encounter`, which uses them instead of the def's `enemy_ids`.

**The `EncounterDef` stays as it is.** It carries the location frame, the type and the reward kind,
and only `enemy_ids` is replaced at instantiation. The fight defs and their per-band pools in
`RunMap.combat_pool` keep working unchanged.

**The drawn ids have to be saved.** `_current_def_id` is the only thing the snapshot records about a
beat, and the run RNG state is written after generation has already drawn from it, so a resumed run
cannot regenerate the same set. The drawn ids go into the snapshot beside `_current_def_id`. No
migration, per the project rule.

**The enemy pool is new.** `RunMap.combat_pool` returns `EncounterCatalog` ids, not enemy ids, so the
generator needs its own per-act pool of `EnemyCatalog` ids.

An enemy's points are its health plus the points its items spend, which is a function on `EnemyDef`.
The target is a single number and the draw is random: enemies are not expected to vary much in how
they split their points between health and threat, so there is no need to fill a health share and an
item share separately.

Bosses stay hand-authored and are not generated; their points are recorded so the curve stays
continuous across them.

## Deliberately out of scope

- **Positioning and roles.** Enemies are drawn without regard to composition. Tank-in-front and
  adds-before-boss are handled later.
- **Modelling synergy.** Covered by `SYNERGY_GROWTH` alone.
- **Measuring the player's actual board.** The curve is fixed, so a good draft stays rewarded.
- **Generating bosses.**

## Work

1. ~~Add the curve constants to `Balance`.~~ **Done.** The target constants are still to come.
2. ~~Add `ItemPoints` (`src/data/item_points.gd`): `rate(cooldown)`, `budget(cooldown)` and
   `spend(item_def)`. `spend` walks the def's effects and converts each to points by the rates in
   [`../design/item_heuristics.md`](../design/item_heuristics.md). An attack with shape `SELF` is
   self-damage and scores a credit. Regen, crit, summons, item creation and the parked statuses score
   nothing. A crit chance multiplies the total.~~ **Done.**
3. ~~Add `points()` to `EnemyDef`, as `max_hp` plus the spend of its items.~~ **Done.**
4. ~~Add `RunMap.target_points(position)`, `RunMap.enemy_pool(act)` and `RunMap.draw_enemies`.~~ **Done.**
5. ~~Generate in `RunManager._enter_beat`, pass the ids to `Encounter`, and add them to the snapshot.~~ **Done.**
6. ~~Raise `Balance.ENEMY_*_HP`.~~ **Done** for the Smith, the default character, whose items are
   on the curve. The Claw was resized at the same time so an early fight costs up to 10% of starting
   health. All three characters now clear the run on every seed tried. Because the enemies do not
   grow until step 7, fights after the first few cost the player nothing and get shorter.
7. Author enough enemies per act to fill the pools. This is the owner's. The lists are
   `EnemyPools.REGULAR` (see [`enemy_authoring_structure.md`](enemy_authoring_structure.md)); while
   an act's list is empty, its fights keep their authored composition.
8. ~~Give the autotest a way to pin a composition.~~ **Done** — `--enemies grunt,grunt`.

## Decided

- The board stays uncapped, so the estimate of about 27 items by the end of a run stands.
