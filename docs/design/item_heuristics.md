# Item Tuning Heuristics

> **Starting properties for new items, not fixed rules.** They give a first number to react to,
> so a new item lands roughly on budget instead of being guessed from scratch. Real balance is
> decided in tuning (the `/tune` skill, real fights), and any item may break a heuristic for a
> reason. Every rate below is a starting point the owner ratifies or changes.

An item is priced in two steps. Work out its budget from its cooldown, then spend the budget on
what the item does. Every number an item ends up with, including its cooldown, is a whole number
(owner, 2026-09-24): round the result of the arithmetic to the nearest whole number.

The arithmetic is built, in `ItemPoints` (`src/data/item_points.gd`): `rate(cooldown)`,
`budget(cooldown, rarity)` and `spend(item_def)`, which prices an authored item by its effects.
`EnemyDef.points()` uses it to price an enemy.

**Every point value lives in one place: the "Item points" section of `src/data/balance.gd`.** That
covers the budget curve constants and the exchange rate for each mechanic. This doc names the
constants and explains them, but does not repeat their values, so tuning a rate needs no doc edit.
To see what a given item spends and may spend, run `tools/item_browser.sh`: every card shows the
item's points, its budget and the share of the budget it uses.

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

An item's budget is how many points it may spend. It comes from its cooldown, raised for uncommon
and rare items (see below).

```
rate(t)   = AT_BASELINE + PER_SECOND × (t − BASELINE_COOLDOWN)    points per second at a cooldown of t seconds
budget(t) = t × rate(t)                                           points the item may spend
```

`AT_BASELINE`, `PER_SECOND` and `BASELINE_COOLDOWN` are `Balance.POINTS_RATE_AT_BASELINE`,
`Balance.POINTS_RATE_PER_SECOND` and `Balance.POINTS_RATE_BASELINE_COOLDOWN`. The rate is a
straight line with no cap (owner, 2026-09-23): each extra second of cooldown adds the same amount
to the rate. Because the budget is the rate multiplied by the cooldown, the budget grows faster
than the cooldown.

The rate rises because a slow item loses value to **overkill** (damage past 0 HP is wasted, while
fast small hits spend almost exactly to the kill), to **trigger density** (anything per-hit fires
per swing, not per damage), and to **commitment** (a fast item contributes immediately and can be
redirected). The owner replaced an earlier curve that levelled off at the top with the straight
line because it is simpler and gives slow items a smaller bonus in the usual cooldown range.

**Rarity raises the budget** (owner, 2026-09-23). An uncommon or rare item's budget is the common
budget multiplied by `Balance.POINTS_UNCOMMON_MULTIPLIER` or `Balance.POINTS_RARE_MULTIPLIER`. Rarer
items are meant to be stronger, not only more involved: power is not flat across rarities. The
extra also pays for the conditions and interactions those items carry. `ItemPoints.budget(cooldown, rarity)` applies it. Enemy fight
budgets do not model rarity.

**Long cooldowns need large enemy health pools.** A slow item spends a large budget in one hit, so
an enemy with too little health turns most of it into overkill. The next section sets enemy health to match.

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

A regular fight is meant to last `Balance.POINTS_FIGHT_SECONDS`, and that length does not change
across the run — the enemy budget grows with the player's board to hold it
steady.

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
Armour brings the real cost lower. The numbers are on the Claw (`content/items/enemy/claw.gd`).

## Spending the budget

Every cost is a flat number of points for what the item delivers each time it fires. The rates are
the `Balance.POINTS_PER_*` constants; the table says what each one prices and why it sits where it
does relative to the others.

| Mechanic | Rate | Notes |
|---|---|---|
| Attack, single target | `POINTS_PER_DAMAGE`, per damage | The definition of a point. |
| Any effect on all opponents | the single-target cost times `POINTS_ALL_OPPONENTS_MULTIPLIER` | Applies to every mechanic, so an attack or a burn aimed at all enemies costs the same multiple. Fights run 1 to 4 enemies, most 1 to 2 ([enemy.md](../systems/enemy.md)), so it is dead weight often enough to be worth less than two targets. |
| Heal | `POINTS_PER_HEAL`, per health restored | An item buys more healing than damage per point. See below. |
| Self-damage | `POINTS_PER_SELF_DAMAGE`, given back per health | An item that hurts its own holder spends a run resource, so it gets back more than it costs the enemy. See below. |
| Shield, self | `POINTS_PER_SHIELD`, per shield | Worth more than health, because it takes the hit before health does and is never wasted on overheal. |
| Poison | `POINTS_PER_POISON_DAMAGE`, per eventual damage | N stacks deal `N × (N + 1) / 2` damage in total, because a tick deals its stacks and then loses one. It drains double shield, which is treated as cancelling out the delay. |
| Burn | `POINTS_PER_BURN_DAMAGE`, per eventual damage | The same total as poison, but it drains half shield instead of double. |
| Bleed | `POINTS_PER_BLEED_DAMAGE`, per eventual damage | The same total again, but it only cashes out when the holder is hit by an attack, so it needs a weapon alongside it. |
| Charge, own item | `POINTS_PER_CHARGE_SECOND`, per second of bar | Roughly the rate of a mid-cooldown item, which is what a second is worth to whatever receives it. |
| Decharge, enemy item | `POINTS_PER_CHARGE_SECOND`, per second of bar | Shares the charge rate. |
| Trigger that charges its own item | seconds charged per trigger × `POINTS_TRIGGERS_PER_COOLDOWN` × the item's own budget per second | Assumes a fixed number of triggers per cooldown (owner, 2026-09-23). The real number rises through a run as the board grows, so late in a run trigger items are underpriced. `ItemPoints.trigger_points`. |
| Empowered | `POINTS_PER_EMPOWERED_STACK`, per stack | A stack raises the next attack by `Balance.EMPOWER_MULT − 1`. See The Smith against the curve. |
| Spores | nothing | See below. |

Regen and crit are not on this table. Regen never loses stacks, so its value depends on how long
the fight runs rather than on what it applies, which is covered under the open questions below.
Crit is not a cost at all: a crit chance of `c` multiplies the item's expected output, so divide
the budget by `1 + c × (Balance.CRIT_MULTIPLIER − 1)` before spending it.

**Spores cost nothing.** A Spores applier pays its full budget in damage and stacks Spores on top.
Spores do nothing alone ([spore_druid.md](spore_druid.md)) and their value is only realised by a
Mass payoff the player has to draft as well, so the applier by itself is not getting a free effect.
Revisit this if Spores ever earn an effect of their own.

## Health is three rates

Health is not one quantity, so it does not get one rate. Assigning enemy health a point value says
nothing about what an item should pay to heal.

**Enemy health is one point per health, and this is forced rather than chosen.** A point is one damage
and one damage removes one enemy health, so the exchange is fixed by the definition. This is the
rate that prices enemies.

**Healing costs less than a point per health restored** (`POINTS_PER_HEAL`), so an item buys more
healing than it buys damage.
Healing is capped by the damage that has already landed, so any excess is wasted, and it arrives
after the hit rather than before it. Shield is priced above a point (`POINTS_PER_SHIELD`) for the opposite reasons: it
takes the hit before health does and is never wasted on overheal. This is the rate most likely to
move, because player health carries between fights while shield does not, which pulls healing's
value back up. It should settle somewhere between healing and shield once fights run long enough to
see whether in-combat healing matters at all.

**Self-damage gives back more than a point per health spent** (`POINTS_PER_SELF_DAMAGE`). Player health is the run's attrition
resource rather than a pool that refills each fight, so an item that carves its holder costs more
than the same number of points would cost an enemy. This is what prices Flensing Hook.

**Maximum health is not priced here.** It persists for the whole run rather than for one fight, so
it is worth more again than any of the three, and the things that grant it are relics rather than
items. It needs its own rate once relics are priced.

## Worked examples

A 4 second attack that also applies 3 poison: three poison stacks deal 3 + 2 + 1 = 6 damage in
total, which costs `6 × POINTS_PER_POISON_DAMAGE`. The attack's damage is whatever is left of
`budget(4)`.

A 2 second self-shield applies `budget(2) / POINTS_PER_SHIELD` shield. The Femur is authored this
way.

## The Smith against the curve

The empower engine ([smith.md](smith.md)) is the first thing these rules have to hold up for.

The weapons are on the curve. The plain two-handed Broadaxe and Greatsword spend their whole
budget on damage, so per-hit climbs faster than damage per second. The one-handed Warhammer spends
its budget on damage less the cost of its decharge (see Weapon cooldowns below). The Dagger splits
its budget between damage and bleed, with bleed priced by its eventual damage.

The armour pieces are priced the same way, through the shield rate: the shield an item applies is
its budget divided by `Balance.POINTS_PER_SHIELD`.

Mighty Blow prices differently from the rest, because a stack is worth a share of whatever attack
it raises. A stack has its own rate, `Balance.POINTS_PER_EMPOWERED_STACK`. Its starting estimate
was the most a stack can add: `Balance.EMPOWER_MULT − 1` of the Greatsword's hit, the biggest the
Smith has. After that it is a number of its own, tuned directly, and does not follow the Greatsword
or `EMPOWER_MULT` (owner, 2026-09-24). Mighty Blow's cooldown is the whole second whose budget is
nearest that price.

There is a catch the curve does not capture: an item is worth nothing if the fight ends before its
first cooldown. At the old placeholder enemy health an act 1 fight lasted about 5.6 seconds, so
the Warhammer and Mighty Blow never fired and the Smith played as a Broadaxe and nothing else. With
enemy health on the curve, the Smith's regular fights last about 10 to 16 seconds and both fire.
Slow items need fights long enough to reach them, and that is set by enemy health, not by the item
budget.

Stacks add up with no cap, and any attack uses one up, so what a stack is worth depends on the
board. A stack used up by a Greatsword-sized hit is worth the most; one used up by a smaller
attack, such as the Dagger's, is worth less.

## Weapon cooldowns

A loose guide, not a hard rule (owner, 2026-09-23): one-handed weapons take cooldowns of 1 to 4
seconds, and two-handed weapons take 5 seconds or more. A heavier one-handed weapon, such as a
warhammer, sits at the slow end of its range.

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
- **The attack bonuses** (flat and percentage, on the Deep Forge and Wide Forge). Rare items are
  expected to carry effects like these that the rates do not cover (owner, 2026-09-23).
- **Values read from a status the owner holds** (`per_owner_stack_id`, Shield Bash's attack equal to
  the shield). The value changes through the fight, so these are tuned by cooldown (owner,
  2026-09-23).
