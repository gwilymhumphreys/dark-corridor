# Plan: shared health bar with shield, and whole numbers in combat

Two changes decided by the owner on 2026-09-23:

1. Every combat value that lands on a character is a whole number: health, max health, damage
   taken, healing and status counts.
2. One health bar scene replaces the three copies (player portrait, enemy panel, ally slot). It
   draws shield over health, stretches to fit whichever is larger, marks every 100 points with a
   faint line, and shows the shield icon and value above the bar.

Plans are not catalogued in `docs/index.md`.

## Part 1: whole numbers

### The rule

A value is rounded once, at the moment it is applied to health, shield or a status count. The steps
before that stay fractional, so several bonuses and crit combine before rounding
(`StatusManager.combine`, then crit, then landing). Rounding uses `roundi`, so halves round up.

### Types

| Field | Now | After |
|---|---|---|
| `Actor.hp`, `Actor.max_hp` | `float` | `int` |
| `StatusEffect.count` | `float` | `int` |
| `Actor.take_damage` / `Actor.heal` return | `float` | `int` |
| `StatusManager.stack_count` / `consume` return | `float` | `int` |

Parameters that receive a computed value (`take_damage(amount)`, `heal(amount)`,
`StatusManager.apply(count)`, `reduce(amount)`, `consume(amount)`, `StatusEffect.setup` and
`reapply`) keep accepting `float` and round inside, so callers such as
`player.heal(def.heal_fraction * player.max_hp)` do not change. `Delivery.value` and
`ItemEffect.value` stay `float`; they are the values before landing.

### Where rounding happens

| Site | Change |
|---|---|
| `Actor.take_damage` | Runs the float amount through `StatusManager.resolve_incoming_damage`, then subtracts `roundi(net)` from health. |
| `Actor.heal` | Adds `roundi(amount)`, capped at max health. |
| `StatusManager.apply`, `StatusEffect.setup`, `reapply` | Round the incoming count. |
| `StatusManager.reduce`, `consume` | Round the amount. |
| `PoolStatus.absorb` | See below. |
| `PeriodicStatus.on_step`, `RegenStatus.on_step`, `BleedStatus` | Pass their computed float; the receiving call rounds. |
| `Actor._init`, `RunManager` max health bonuses and snapshot load | Round to `int`. |
| `Item.display_value` / `base_value` | Return the rounded value, so the tooltip shows the number that will land (before crit). |

`PoolStatus.absorb` with a whole shield count, for incoming damage `d` (float, after Vulnerable) and
the dealing mechanic's multiplier `m`:

- The shield cost is `roundi(d * m)`. If that is no more than the shield, the shield loses the cost
  and no damage gets through.
- Otherwise the shield covers `count / m` damage and drops to 0, and `d - count / m` goes on to
  `take_damage`, which rounds it.

Example: 3 burn damage (m = 0.5) against 1 shield costs `roundi(1.5) = 2`, more than 1, so the
shield covers 2 damage and 1 goes through.

`TimedStatus` duration is time, not a count, and stays `float`. `AttackPercentBonusStatus` already
stores whole percentages in `count`.

### Tests and reports

Update tests that expect fractional health, shield or counts. Tests that assert exact numbers should
compare integers with `assert_eq`. The combat log and autotest report already print numbers; check
they still format cleanly with integers.

## Part 2: the health bar

### Scene

A new `HealthBar` scene (`src/scenes/combat/health_bar.tscn` / `.gd`), used by
`combat_view_framed.tscn`, `enemy_hud.tscn` and `ally_slot.tscn` in place of their `HP` controls.
Each view sets `health_bar.actor` in its setup and clears it on unbind, like `StatusNumbers` now.
The per-view `_refresh_hp` code moves into the bar, which reads the actor each frame and writes
nothing.

Layout, top to bottom:

- **Shield readout.** The shield icon (`MechanicRegistry.get_mechanic('shield').icon`) and the
  shield value, both in `Colours.SHIELD`, left-aligned above the bar. Its space stays reserved when
  shield is 0 (the contents are hidden, the row is not), so the bar does not move.
- **The bar row.** The bar itself, then `StatusNumbers` to its right. Shield is removed from
  `StatusNumbers`, which keeps poison, burn, bleed and regen.

The bar is a fixed size set by each view (the current sizes), drawn in this order:

| Layer | What it shows |
|---|---|
| Background | The bar's full width, in the background colour. |
| Health fill | Current health, from the left. |
| Max health line | A faint line where max health ends. Only drawn when shield is larger than max health, since otherwise it is the bar's right edge. |
| Shield fill | Current shield, from the left, over the health fill, in `Colours.SHIELD`. |
| Point lines | A faint vertical line every `HealthBar.LINE_STEP` points (100), across the whole bar. |
| Label | `health / max health`, centred, as now. |

The enemy bar keeps its own colours. `HealthBar` exports `fill_colour_name` and
`background_colour_name` so the enemy panel can set `ENEMY_HP_BAR_FILL` and `ENEMY_HP_BAR_BG`. The
line colour is a new `Colours.HP_BAR_LINE`; the interface palette finds `Colours` variables by name,
so nothing else needs registering.
All drawn parts use `interface_element_material`, like the bars now.

### Scale

The bar's full width stands for `max(max_hp, shield)` points. Health fill width is `hp / scale`,
shield fill width is `shield / scale`, and the point lines sit at every multiple of `LINE_STEP` below
`scale`. When the scale changes, the shown scale eases towards the new one over a short time
(a constant in `health_bar.gd`), so the fills and lines shrink or grow smoothly instead of jumping.
The fills themselves still follow health and shield directly, as now.

The lines and the max health line are drawn in the bar's `_draw()`, redrawn when the shown scale
changes.

### Juice

The new scene gets a `UIJuice` node, following the project rule for new UI entities, using the same
preset as `StatusNumbers`.

## Docs to update in the same change

| Doc | Change |
|---|---|
| `docs/systems/actor.md` | Health is whole numbers; rounding at `take_damage` / `heal`. |
| `docs/systems/status_manager.md` | Counts are whole numbers; where they round. |
| `docs/systems/mechanics.md` | Shield section: the rounding of shield cost. Health bar numbers section: shield moves above the bar; describe `HealthBar`. |
| `docs/systems/run_screen.md` | Point the three health bars at `HealthBar` if it describes them. |
| `docs/decision_log.md` | New entry: combat values are whole numbers, rounded once when applied. |
| `docs/history/build_log.md` | Dated entry with the test count. |

## Order of work

1. Whole numbers (Part 1), then run the GUT suite.
2. The health bar scene and the three views (Part 2), then run the GUT suite, reimport, and take
   screenshots of a fight with shield below and above max health for the owner to check.
3. Docs.

Making the bars larger is a separate step after this.
