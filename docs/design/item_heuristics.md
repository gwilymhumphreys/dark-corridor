# Item Tuning Heuristics

> **Starting properties for new items, not fixed rules.** They give a first number to react to,
> so a new item lands roughly on budget instead of being guessed from scratch. Real balance is
> decided in tuning (the `/tune` skill, real fights), and any item may break a heuristic for a
> reason. Every rate below is a starting point the owner ratifies or changes.

An item is priced in two steps. Work out its budget from its cooldown, then spend the budget on
what the item does.

The arithmetic is built, in `ItemPoints` (`src/data/item_points.gd`): `rate(cooldown)`,
`budget(cooldown)` and `spend(item_def)`, which prices an authored item by its effects. The rates
and the curve constants are in `Balance`. `EnemyDef.points()` uses it to price an enemy.

The Smith is the character these rules are being applied to first. The Spore Druid and the
Fleshmancer were authored before the mechanics were revised, so their items are off this curve in
places; they are revisited once the Smith is playable.

## Points

**Points** are the shared unit all the rules are written in. One point is one damage from a
single-target attack. Every other mechanic has an exchange rate into points, so a multi-mechanic
item is priced by adding up what each part costs rather than by a separate rule per combination.

Health appears in the rules three times and at three different rates, because the three are not the
same thing. See [Health is three rates](#health-is-three-rates).

## The budget curve

An item's budget is how many points it may spend, and it comes from its cooldown alone.

```
rate(t)   = 26 / (1 + e^(−0.33 × (t − 6.4)))    points per second at a cooldown of t seconds
budget(t) = t × rate(t)                          points the item may spend
```

The rate rises with the cooldown, slowly at first, steepest around a 6.4 second cooldown, then
flattening towards a ceiling of 26 points per second that is effectively reached by 30 seconds.
Because the budget is the rate multiplied by the cooldown, the total climbs steeply: 2 seconds is
worth 10 points, 10 seconds is worth 199, and 20 seconds is worth 514.

The rate rises because a slow item loses value to **overkill** (damage past 0 HP is wasted, while
fast small hits spend almost exactly to the kill), to **trigger density** (anything per-hit fires
per swing, not per damage), and to **commitment** (a fast item contributes immediately and can be
redirected). It flattens at the top because those losses are bounded. A 20 second weapon is not
four times as wasteful as a 5 second one.

| Cooldown | Rate | Budget |
|---|---|---|
| 1s | 3.75 | 3.7 |
| 2s | 4.93 | 9.9 |
| 3s | 6.39 | 19.2 |
| 4s | 8.11 | 32.4 |
| 5s | 10.05 | 50.2 |
| 6s | 12.14 | 72.9 |
| 7s | 14.28 | 100.0 |
| 8s | 16.35 | 130.8 |
| 10s | 19.93 | 199.3 |
| 15s | 24.56 | 368.4 |
| 20s | 25.71 | 514.2 |

**Long cooldowns need large enemy health pools.** A 10 second item spends 199 points, so an enemy
with too little health turns most of it into overkill. The next section sets enemy health to match.

## Pricing an enemy

A point of damage removes a point of enemy health, so an enemy is priced in the same currency as
an item.

```
enemy points = health + the points its items spend
```

That is one number for how much of a problem an enemy is: the damage the player has to spend to
kill it, plus the value of what it does back. Enemy items are priced on the same curve as the
player's, so a weapon is worth the same whoever is holding it, and an encounter can be budgeted by
adding up the enemies in it.

### Setting health from a target fight length

Only the points a board spends on **damage** kill an enemy, and an item on the curve spends its
budget at its rate, so a board's damage output is the sum of the rates of its damage items.

```
enemy health = the board's damage points per second × the seconds it should survive
```

A regular fight is meant to last about 20 seconds (`Balance.POINTS_FIGHT_SECONDS`), and that
length does not change across the run — the enemy budget grows with the player's board to hold it
steady.

| Board | Points per second | Health for a 20 second kill |
|---|---|---|
| 2 items, 3s and 4s cooldowns | 14.5 | 290 |
| 4 items, 3s to 6s | 36.7 | 734 |
| 6 items, 2s to 7s | 55.9 | 1118 |

Three things push the real fight longer than the division suggests, and are why the figure is a
floor rather than a target. The enemy's own shield and healing add to its effective health. The
killing blow wastes whatever it deals past zero. And a board never spends its whole budget on
damage.

The placeholder health values in `Balance.ENEMY_*_HP` are set from this for a beat 0 fight, so a
starting board takes roughly the target time to kill a regular enemy.

### Setting damage from what a fight should cost

An enemy's damage is set by how much health a fight should take from the player, not by the item
budget. An early regular fight costs a player with no armour up to 10% of starting health (owner,
2026-09-22), so the enemy's damage per second is that amount divided by the target fight length.
Armour brings the real cost lower. `Balance.ENEMY_CLAW_*` holds the numbers.

## Spending the budget

Every cost is a flat number of points for what the item delivers each time it fires.

| Mechanic | Points | Notes |
|---|---|---|
| Attack, single target | 1 per damage | The definition of a point. |
| Attack, all opponents | 1.5 per damage | Fights run 1 to 4 enemies, most 1 to 2 ([enemy.md](../systems/enemy.md)), so it is dead weight often enough to be worth less than two targets. |
| Heal | 0.75 per health restored | An item buys more healing than damage per point. See below. |
| Self-damage | gives back 1.5 per health | An item that hurts its own holder spends a run resource, so it gets back more than it costs the enemy. See below. |
| Shield, self | 1.25 per shield | Worth more than health, because it takes the hit before health does and is never wasted on overheal. |
| Poison | 1 per eventual damage | N stacks deal `N × (N + 1) / 2` damage in total, because a tick deals its stacks and then loses one. It drains double shield, which is treated as cancelling out the delay. |
| Burn | 0.75 per eventual damage | The same total as poison, but it drains half shield instead of double. |
| Bleed | 0.5 per eventual damage | The same total again, but it only cashes out when the holder is hit by an attack, so it needs a weapon alongside it. |
| Charge, own item | 6 per second of bar | Roughly the rate of a mid-cooldown item, which is what a second is worth to whatever receives it. |
| Decharge, enemy item | 6 per second of bar | |
| Spores | 0 | See below. |

Regen and crit are not on this table. Regen never loses stacks, so its value depends on how long
the fight runs rather than on what it applies, which is covered under the open questions below.
Crit is not a cost at all: a crit chance of `c` multiplies the item's expected output, so divide
the budget by `1 + c × (CRIT_MULTIPLIER − 1)` before spending it.

**Spores cost nothing.** A Spores applier pays its full budget in damage and stacks Spores on top.
Spores do nothing alone ([spore_druid.md](spore_druid.md)) and their value is only realised by a
Mass payoff the player has to draft as well, so the applier by itself is not getting a free effect.
Revisit this if Spores ever earn an effect of their own.

## Health is three rates

Health is not one quantity, so it does not get one rate. Assigning enemy health a point value says
nothing about what an item should pay to heal.

**Enemy health is 1 point per health, and this is forced rather than chosen.** A point is one damage
and one damage removes one enemy health, so the exchange is fixed by the definition. This is the
rate that prices enemies.

**Healing costs 0.75 points per health restored**, so an item buys more healing than it buys damage.
Healing is capped by the damage that has already landed, so any excess is wasted, and it arrives
after the hit rather than before it. Shield is priced above it at 1.25 for the opposite reasons: it
takes the hit before health does and is never wasted on overheal. This is the rate most likely to
move, because player health carries between fights while shield does not, which pulls healing's
value back up. It should settle somewhere between healing and shield once fights run long enough to
see whether in-combat healing matters at all.

**Self-damage gives back 1.5 points per health spent.** Player health is the run's attrition
resource rather than a pool that refills each fight, so an item that carves its holder costs more
than the same number of points would cost an enemy. This is what prices Flensing Hook.

**Maximum health is not priced here.** It persists for the whole run rather than for one fight, so
it is worth more again than any of the three, and the things that grant it are relics rather than
items. It needs its own rate once relics are priced.

## Worked examples

A 4 second attack that also applies 3 poison has a budget of 32.4 points. Three poison stacks deal
6 damage in total, at 1 point each, so 6 points. That leaves 26.4 points of damage.

A 2 second self-shield has a budget of 9.9 points, which at 1.25 points per shield is 7.9 shield.
The authored Femur is 8.

## The Smith against the curve

The empower engine ([smith.md](smith.md)) is the first thing these rules have to hold up for.

The weapon ladder is on the curve. The 5 second Broadaxe is 50 damage, the 6 second Warhammer is
73, and the 7 second Greatsword is 100. The shape of the ladder is unchanged, with per-hit climbing
faster than damage per second.

The armour ladder is priced the same way, through the shield rate: the shield an item applies is
its budget divided by `Balance.POINTS_PER_SHIELD`. That gives 15 shield at 3 seconds (Vambraces),
26 at 4 (Sallet), 40 at 5 (Kite Shield) and 58 at 6 (Breast Plate).

Mighty Blow prices differently from the rest, because a charge is worth whatever weapon it doubles.
One cooldown cycle banks one charge, and that charge adds exactly one weapon's per-hit damage. So
the empower's budget for a cycle has to cover the biggest per-hit it can reach. The biggest is the
Greatsword's 100, which is `budget(7)`, so the empower's cooldown is 7 seconds.

The general rule: **an empower's cooldown equals the cooldown of the biggest per-hit weapon it can
reach.** Both sides use the same budget function, so the two match exactly.

There is a catch the curve does not capture: an item is worth nothing if the fight ends before its
first cooldown. At the old placeholder enemy health an act 1 fight lasted about 5.6 seconds, so
the Warhammer and Mighty Blow never fired and the Smith played as a Broadaxe and nothing else. With
enemy health on the curve, the Smith's regular fights last about 10 to 16 seconds and both fire.
Slow items need fights long enough to reach them, and that is set by enemy health, not by the item
budget.

The cooldown matters more than it looks, because charges stack with no cap. At a cooldown below the
weapon's, the overspend is not a fixed amount — it grows with the board. With a single Greatsword,
a 5 second empower is capped by how often the Greatsword fires, so it adds 14.28 points per second
against an allowed 10.05. With enough weapons to consume every charge, it adds 100 every 5 seconds,
which is 20 per second against the same 10.05. Matching the cooldown removes the difference: at 7
seconds both cases come out at 14.28.

## Parked

**Weak, Vulnerable, Blind and Silence are parked** and are not priced here. They are timed statuses
outside the mechanic set, they predate the revised mechanics, and whether they stay in the game at
all is undecided. Items that currently apply them (Wilt Frond, Pocket Shrooms, Hex Bolt, Sundering
Bolt) are left alone.

One thing is worth keeping for when they come back. A timed debuff cannot be priced as a flat cost,
because its value is the fraction of the fight it is active for: a 2 second Weak from a 2 second item
is always on, and the same Weak from an 8 second item is on a quarter of the time. It needs a cost
in points per second of cooldown, so that a slow item does not buy the same debuff cheaply.

## Status durations are per-application

A timed status's duration rides the application. An applier sets `ItemEffect.duration` and it flows
through to the status instance, so a different item can apply a longer version of the same status.
The `Balance` duration constants are defaults an applier reuses, not a global the status owns.
Re-applying a timed status extends the timer. Non-timed statuses, meaning shield, poison and spores,
ignore `duration`, and their `count` is the magnitude.

## What this leaves unpriced

These need the owner's decision before the rules cover a whole character. None of them block the
Smith.

- **Chunk of Flesh creation.** A chunk fires twice for 1 damage, so its literal output is 2 points,
  but the Fleshmancer's creators are authored as though a chunk were worth far more. See the pricing
  note in `src/data/balance.gd`.
- **Regen.** It never loses stacks, so one stack heals for the rest of the fight. Pricing it needs an
  assumed remaining fight length, and at the current per-tick heal one stack would cost more than a
  5 second item's whole budget. That suggests regen wants to decay, or to heal less per tick.
- **Relics**, which are not on the item curve at all, including the maximum health they grant.
- **Creating and consuming items**, and **summons**.
