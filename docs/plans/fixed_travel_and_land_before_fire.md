# Plan: fixed travel for every delivery, and land before fire

Built 2026-09-23 (decision #48). Written the same day after the owner decided three changes to how a combat step resolves.
The decisions are the owner's. Written to be implemented by a session that has not seen the
conversation.

Plans are not catalogued in `docs/index.md`.

## Why

A combat step (`CombatManager.sim_step`, `src/combat/combat_manager.gd`) runs in this order now:

1. Advance item cooldowns, statuses and in-flight deliveries; list the items whose bars filled.
2. Fire the listed items. Each picks its targets as it fires. Deliveries with zero travel are added
   to this step's landing list.
3. Land every delivery that arrived this step.
4. Remove dead enemies and summoned tokens, then check for a win or loss.

Nothing dies until step 3, so an item firing in step 2 can pick an enemy that a projectile arriving
on the same step is about to kill. Its own delivery then fizzles on arrival.

Travel is authored in seconds per effect. `ItemEffect.travel_for` gives effects aimed at the other
side `Balance.WEAPON_TRAVEL`, and effects aimed at the holder or the holder's own items zero.
Summons and created items default to zero because nothing sets their travel. `CombatManager` turns
the seconds into a whole number of steps with `Ticker.from_seconds`.

Because own-board effects have zero travel, an item that charged itself would refill its bar on the
step it fired and then fire every step. To prevent that, `_all_own_items` leaves the firing item out
of the pool for `own-item-random` and `all-own-items`.

## The decisions

1. **Every delivery has travel time and a projectile.** Nothing lands on the step it was fired.
2. **Travel is a fixed number of steps**, the same for every delivery, set by one constant. The
   visuals already draw the flight from the delivery's step count
   (`VfxDriver._draw`, `src/vfx/vfx_driver.gd`), so they need no change to follow it.
3. **Deliveries land before items fire.** An item firing on a step sees every death from that
   step's landings.
4. **The firing item is no longer left out of its own-board targets.** Travel time limits a
   self-charging item to one fire per travel time, so the rule is no longer needed.

## Changes

### Travel constant

- Replace `Balance.WEAPON_TRAVEL` (seconds) in `src/data/balance.gd` with `Balance.TRAVEL_STEPS`,
  an integer count of steps. Use the step count that the current value rounds to, so attack timing
  does not change.
- Remove `ItemEffect.travel`, `ItemEffect.travel_for` and the two lines that call it in
  `src/content/items/item_effect.gd`.
- Remove `Payload.travel` and the line in `Payload.from_effect` that copies it
  (`src/combat/payload.gd`).
- In `CombatManager._spawn_delivery`, set `d.travel = Ticker.new(Balance.TRAVEL_STEPS)`.
- Check that no content file sets `travel`. None did when this plan was written.

`_dot_visual` still builds a delivery with `Ticker.new(0)`. It is a display-only record for a
damage-over-time tick whose damage the status already applied, and it is created already landed. It
is not a delivery in the sense of this rule, so it stays as it is.

### Step order

Rewrite `sim_step` to this order:

1. Advance item cooldowns and list the items whose bars filled. Advance statuses. Advance deliveries
   and list the ones that arrived.
2. Land the arrived deliveries.
3. Remove the dead (`_reap_dead`).
4. Check for a win or loss (`_check_resolution`). If the fight is over, stop here, so no item fires
   after the fight has ended.
5. Fire the listed items. Keep the existing check that skips an item removed earlier in the step.
   `_fire_item` already returns early when the item's owner is dead, so an item whose owner died in
   step 2 does not fire.
6. Drop spent deliveries (`_prune_deliveries`).

Bars are advanced and the full ones listed before landing, as now. A charge or trigger push from a
landing on this step therefore fills a bar that is only checked on the next step. That keeps the
existing rule that a chain advances at most one link per step.

`_fire_item` no longer adds anything to a landing list, since no delivery arrives on the step it is
fired. Remove the `arrived` parameter and the `if d.travel.crossed()` branch.

### Potions

Changed after the build (owner, 2026-09-23): a delayed potion would feel bad in a crisis and in slow
motion, so thrown potions fly `Balance.POTION_TRAVEL_STEPS` (one step) instead of `TRAVEL_STEPS`.
`_spawn_delivery` takes the travel step count. The rest of the potion path is as planned below.

`throw_consumable` lands zero-travel deliveries immediately. With fixed travel, a thrown potion's
deliveries are added to the in-flight set like any other and land after `TRAVEL_STEPS`. Remove the
immediate `_land` call. The `_reap_dead` and `_check_resolution` calls at the end of the function can
go too, since a throw no longer lands anything outside the step loop. A potion is treated as an item
that fires once: its flight starts at the slot it was thrown from (`CombatViewFramed.consumable_pos`,
recorded in `_on_potion_pressed`), the same way an item's flight starts at its board cell. The
drawing needs no change.

### Own-board targets

- Remove the `firing_item` parameter from `_all_own_items` and include every item on the owner's
  board, including the one firing.
- Update the two callers in `_resolve_targets`.

### Tests

About thirty places in the tests set `travel = 0.0` on an effect or fixture so its delivery lands
on the fire, then call `cm._fire_item(it, arrived)` and land the `arrived` list. With the `travel`
field and the `arrived` parameter gone, they need a replacement:

- Add `tests/utils/combat_steps.gd` (`class_name CombatSteps`, not named `test_*` so GUT does not
  collect it) with `static func fire_and_land(cm, it) -> void`. It fires the item and then lands
  every delivery that fire added to `cm._deliveries`. This tests what a delivery does on landing,
  separately from the step loop.
- Replace each fire-then-land-`arrived` block with `CombatSteps.fire_and_land(cm, it)`, and each
  `_fire_item(it, [])` with `_fire_item(it)`. Delete the `travel = ...` lines in tests and fixtures,
  and the fixture constant `ATTACK_TRAVEL` if nothing else uses it.
- Tests that run the full step loop and expect a same-step land need to step `Balance.TRAVEL_STEPS`
  more times.
- `test_ticker` and `test_delivery` test a zero-step `Ticker` directly. That is still valid, since
  `_dot_visual` uses one, so they stay.

Add tests for:

- A delivery aimed at the holder lands exactly `TRAVEL_STEPS` steps after the fire.
- An item firing on the same step that a projectile kills the leftmost enemy targets the next enemy,
  not the dead one.
- An item whose owner dies from a landing on the same step does not fire.
- The fight ends on the step the last enemy dies, and no item fires on that step.
- An item with an `all-own-items` charge effect charges itself, and fires no more often than once per
  `TRAVEL_STEPS`.

Run the full GUT suite and one autotest run afterwards. Autotest results will shift a little, because
shields and heals now land later than before.

## Docs to update in the same change

| Doc | What changes |
|---|---|
| `docs/systems/combat_model.md` | Remove "travel_time may be zero". State that every delivery travels a fixed number of steps. |
| `docs/systems/combat_manager.md` | Rewrite the central tick list in the new order. Remove "the firing item excluded" from the own-item shapes. |
| `docs/systems/mechanics.md` | Remove the bullet saying the firing item is left out of both own-board shapes. |
| `docs/systems/item.md` | Update the own-item shape lines if they mention the exclusion. |
| `docs/systems/content.md` | A thrown potion now travels like any other delivery. |
| `docs/design/authoring.md` | Replace the `WEAPON_TRAVEL` reference and "instant on your own" with the fixed travel rule. |
| `docs/decision_log.md` | Add a decision recording the three rules above. |

### Summons and created items

These travel like every other delivery and get a projectile (owner, 2026-09-23). Both target the
firing actor, so the projectile flies from the firing item's cell to its owner.

- In `VfxDriver._draw` (`src/vfx/vfx_driver.gd`), remove the early `continue` that skips `SUMMON`
  and `CREATE_ITEM` deliveries, so their flight is drawn. Once landed they still draw nothing,
  because `_impact_key` has no drawer for either kind.
- Leave the two sound checks that skip these kinds (`_travel_key_of` and the landing sound check)
  as they are. Sounds for them are a separate piece of work.
- Their colour comes from `ItemEffect._get_color`, which falls back to white for these kinds.
  Setting `colour_name` on the effect changes it.
- Add a test that a summon arrives `TRAVEL_STEPS` steps after the fire.
- Update `docs/systems/vfx_driver.md` if it says these kinds draw no projectile.
