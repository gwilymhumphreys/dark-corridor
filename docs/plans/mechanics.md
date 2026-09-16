# Plan: mechanics

This plan turns the game's basic combat rules (attack, shield, heal, poison, burn, bleed, regen and
crit) into mechanics. A mechanic is a named rule with one class that holds its name, description,
icon, colour and what it does. Item effects name the mechanic they use, so items, relics and
enchantments can later refer to them ("your poison items", "when you shield"). Nothing here is built
yet. The design decisions are the owner's (2026-09-17). This plan is written to be implemented by a
session that has not seen the conversation.

The model is the card battler grail (installed at `C:\games\Steam\steamapps\common\card-battler`;
its keyword rules and card text are in `localization_1.1.1.tsv`). Grail has a small, fixed set of
keywords, and most of its cards, traits and enchantments are written in terms of them.

Plans are not catalogued in `docs/index.md`.

## Why

Today one rule such as poison is spread across six places:

| Part of poison | Where it is now |
|---|---|
| What happens when it lands | `Delivery.Kind.APPLY_STATUS` and a branch in `CombatManager._land` |
| Its state on the target and how that behaves | `PoisonStatus` |
| Name, description, icon | `PoisonStatus`, or a `kw:*` entry in `KeywordCatalog` for rules that are not statuses |
| Colour | `Colours.STATUS_POISON`, copied by hand onto each item's `ItemEffect.color` and `panel_color` |
| Projectile and impact | Drawers chosen by `Delivery.Kind`, so poison, block and attacks all look alike |
| How other items refer to it | A string in a trigger filter, and only for statuses |

Attacks, heals and block are each built differently from poison, so an item cannot say "when you
shield" or "your attack items have +2" in the way it says "when you apply poison".

## Words used in this plan

- **Attack** is the mechanic for a direct hit from an item or potion.
- **Damage** is health or shield lost from any source. Poison, burn and bleed deal damage but are
  not attacks.
- **Stacks** is a status's `count`.
- **The eight** means the eight mechanics below. **Outside the set** means every other status and
  delivery kind (weak, vulnerable, blind, silence, spores, decay, empowered, summon, item creation).

## The eight mechanics

Every value named here is a new or renamed constant in `src/data/balance.gd`. Give new constants
placeholder values with a `# PLACEHOLDER — owner tunes` comment.

| Mechanic | Id | What it is | What it does |
|---|---|---|---|
| **Attack** | `'attack'` | Direct | Deals damage to the target. |
| **Shield** | `'shield'` | Status on an actor | Replaces block. A pool that absorbs incoming damage before health and stays until used up. How much shield a hit uses depends on the mechanic that dealt it. |
| **Heal** | `'heal'` | Direct | Restores health up to maximum, then removes some poison, burn and bleed from the healed actor. |
| **Poison** | `'poison'` | Status on an actor, ticks | Every `POISON_TICK_INTERVAL`, deals stacks × `POISON_DAMAGE_PER_TICK` to the holder, then loses one stack. Does double damage to shield. This is the current poison behaviour. |
| **Burn** | `'burn'` | Status on an actor, ticks | The same as poison with its own constants (`BURN_TICK_INTERVAL`, `BURN_DAMAGE_PER_TICK`), except that it does half damage to shield. For now shield is the only rule that differs. |
| **Bleed** | `'bleed'` | Status on an actor, triggered by attacks | Each time the holder is hit by an attack, deals damage equal to its stacks to the holder, then loses one stack. Does half damage to shield. |
| **Regen** | `'regen'` | Status on an actor, ticks | Every `REGEN_TICK_INTERVAL`, heals the holder by stacks × `REGEN_HEAL_PER_TICK`. Never loses stacks, so it lasts the whole fight. |
| **Crit** | `'crit'` | A chance on an item | When the item fires, rolls its crit chance. On a crit, the values of that fire's deliveries are multiplied by `CRIT_MULTIPLIER`. |

Poison and burn stay fuel for the consume effects (they extend `PeriodicStatus`, whose `is_fuel`
returns true). Regen and bleed are not fuel.

### Shield

When damage reaches shield, the shield loses the damage times the dealing mechanic's shield
multiplier. If the shield runs out, the damage it could not cover goes to health unchanged.

| Dealt by | Constant | Value |
|---|---|---|
| Attack | none | 1 |
| Poison | `SHIELD_MULTIPLIER_POISON` | 2 |
| Burn | `SHIELD_MULTIPLIER_BURN` | 0.5 |
| Bleed | `SHIELD_MULTIPLIER_BLEED` | 0.5 |
| Anything else, or no mechanic given | none | 1 |

Absorb calculation, where `m` is the multiplier:

```gdscript
var covered: float = minf(net, count / m)   # damage the shield can cover
count -= covered * m
net -= covered
```

Example: a 10 damage poison tick against 30 shield removes 20 shield and no health. Against 6
shield, the shield covers 3 damage and is used up, and 7 goes to health.

- The unblockable flag still skips shield entirely.
- Vulnerable still scales damage up before shield absorbs it (`modify_incoming` runs first).
- `Actor.take_damage(amount, flags, mechanic_id: String = '')` gains the argument.
  `StatusManager.resolve_incoming_damage` and `StatusEffect.absorb` pass it through, and
  `PoolStatus.absorb` looks up the multiplier with `MechanicRegistry.shield_multiplier(mechanic_id)`.
- Every caller passes its mechanic: the attack mechanic passes `'attack'`, `PeriodicStatus` passes
  its own `id`, and bleed passes `'bleed'`.

### Bleed

- Bleed triggers only when an attack delivery lands on its holder. Poison and burn ticks, bleed's own
  damage, and outside-set damage do not trigger it, so it cannot repeat within a step.
- It triggers even when shield absorbs the whole attack.
- An attack that is evaded or fizzles does not land, so it does not trigger bleed.
- An attack that kills the holder does not trigger bleed.
- An attack with shape `ALL_OPPONENTS` triggers each target's bleed separately.
- Item type tags play no part. An attack from an item not tagged weapon still triggers it.
- Bleed keeps its applying flags, so an unblockable bleed (Bone Spear) still skips shield.

**How:** add a hook `StatusEffect.on_holder_attacked(target, ctx) -> bool` (returns true when
expired, default false). After `take_damage` in the attack mechanic's `land`, if the target is still
alive, the Combat manager calls it on each of the target's statuses. `BleedStatus` moves its
behaviour from `on_owner_item_fired` to this hook. Bleed's damage gets the same wall visual and
combat log entry as today, using the code now in `_drain_actor_fire_statuses`. Move that shared
code into one helper so both paths use it. `EmpoweredStatus` still uses `on_owner_item_fired`.

This is a reaction inside the damage step, not an item trigger, so it does not conflict with the
rule that triggers only charge items ([combat_model.md](../systems/combat_model.md)).

### Heal removing poison, burn and bleed

When a heal delivery lands, after healing, each of the target's poison, burn and bleed loses
`floor(value * HEAL_CLEANSE_FRACTION)` stacks. `value` is the delivery's full value, including any
part above maximum health. A status reduced to zero or below is removed.

- `HEAL_CLEANSE_FRACTION` is 0.1, as in grail.
- Add `StatusManager.reduce(target, id, amount)`. It removes stacks from any status (unlike `consume`,
  which only works on fuel), and removes the status with `on_expire` when it reaches zero.
- Regen's ticks are not heal deliveries, so they remove nothing.
- Heals from potions are heal deliveries, so they do remove stacks.

### Crit

- `ItemDef.crit_chance: float = 0.0`, from 0 to 1.
- In `CombatManager._fire_item`, after `it.fire()` returns payloads, roll once for the fire:
  `crit = it.def.crit_chance > 0.0 and rng.randf() < it.def.crit_chance`. Items with no crit chance
  draw nothing from `rng`, so existing fights and seeded autotest runs are unchanged.
- On a crit, multiply the value of every delivery spawned by that fire whose mechanic is one of the
  eight by `CRIT_MULTIPLIER`. Do this last, after enchantments, weak, empowered and both kinds of
  consume. Outside-set deliveries are not changed. Durations are not changed.
- Set `Delivery.crit = true` on those deliveries, for effects to use later.
- Publish `EventBus.Event.CRIT` with the item's def id as data, the owner as source, after
  `ITEM_FIRED`.
- Potions have no crit chance.
- `Item.display_value` never rolls, and the tooltip shows the value without crit.

## The mechanic class

**Location:** `src/content/mechanics/`

- `mechanic.gd`: `class_name Mechanic extends RefCounted`, the base.
- One file per mechanic: `attack_mechanic.gd` (`class_name AttackMechanic`), `shield_mechanic.gd`,
  `heal_mechanic.gd`, `poison_mechanic.gd`, `burn_mechanic.gd`, `bleed_mechanic.gd`,
  `regen_mechanic.gd`, `crit_mechanic.gd`. Each has `const ID := '<id>'`.
- `mechanic_registry.gd`: `class_name MechanicRegistry`, built lazily like `StatusRegistry`, with
  `has(id)`, `get_mechanic(id) -> Mechanic` (one shared instance per id) and
  `shield_multiplier(id) -> float` (1.0 for an empty or unknown id).

| Member | Purpose |
|---|---|
| `id` | The mechanic id. |
| `name_key`, `desc_key` | Set by plain assignment in `_init` (`name_key = 'Poison'`) so `tools/extract_pot.gd` finds them. Descriptions are placeholders marked `# PLACEHOLDER desc — owner writes`. |
| `icon` | A `res://` icon path. Reuse the current status or keyword icons; burn, regen and crit need icons picked from `assets/icons/` and marked as placeholders. |
| `color() -> Color` | Returns its `Colours` variable. A function, so a palette applied at runtime is read each time. |
| `status_id` | The status it applies: `'shield'`, `'poison'`, `'burn'`, `'bleed'`, `'regen'`. Empty for attack, heal and crit. |
| `shield_multiplier() -> float` | 1.0 by default; poison, burn and bleed return their constants. |
| `land(delivery: Delivery, combat: CombatManager) -> void` | What happens when a delivery lands. The base applies `status_id` to the target with `StatusManager.apply` and logs it. `AttackMechanic` and `HealMechanic` override it. Each `land` publishes and logs exactly what the matching branch of `_land` does now (the attack logs gross and net damage, the heal logs the amount healed, shield uses the shield log call). Crit has no `land`, because it is never delivered. |

`land` receives the Combat manager because landing needs its combat log, event bus and the bleed
helper. Only `_land` calls it.

The status classes for shield, poison, burn, bleed and regen keep their `name_key`, `desc_key`,
`color` and `icon` fields, because the combat log, status icons and combat summary read them. Their
`_init` copies them from their mechanic instead of setting its own text, so each is written once.

## Colours

The mechanic colours get their own section in `src/data/colours.gd`:

| Variable | Replaces | Default |
|---|---|---|
| `ATTACK` | `DAMAGE` | Current `DAMAGE` value |
| `SHIELD` | `STATUS_BLOCK` | Current `STATUS_BLOCK` value |
| `HEAL` | unchanged | Current value |
| `POISON` | `STATUS_POISON` | Current value |
| `BURN` | new | Placeholder orange |
| `BLEED` | new | Placeholder dark red (bleed currently borrows `DAMAGE`) |
| `REGEN` | new | Placeholder light green |
| `CRIT` | new | Placeholder pale yellow |

- Rename every use in code, and the names in all four palette files in `assets/palettes/new/ui/`
  (`damage` to `attack`, `status block` to `shield`, `status poison` to `poison`). Add the four new
  names to `ui-default.gpl` only; the other palettes keep the defaults for them.
- `ItemEffect.color` is not set for effects that use a mechanic. `Payload.from_effect` sets the
  payload's colour from the mechanic.
- The colour `Colours.ENEMY_CLAW` is used only by the enemy claw item (`ItemCatalog.ENEMY_CLAW`). That
  item's effect becomes an attack and takes `ATTACK`, so delete the colour variable and its palette
  entries. The item itself stays.
- `ItemDef.panel_color` is still set by hand in catalogs. Set it from the mechanic colour
  (`Colours.POISON`) for items whose first effect uses a mechanic.

## How effects name a mechanic

- `ItemEffect`, `Payload` and `Delivery` gain `mechanic: String = ''`. `Payload.from_effect` and
  `CombatManager._spawn_delivery` copy it, as they copy `status_id` now.
- `Delivery.Kind` loses `DAMAGE` and `HEAL` and gains `MECHANIC`, so it becomes
  `{ MECHANIC, APPLY_STATUS, SUMMON, CREATE_ITEM }`. The default `kind` on `ItemEffect`, `Payload`
  and `Delivery` becomes `MECHANIC`. Removing the two values makes every stale use a parse error, so
  none are missed.
- An effect using one of the eight sets `kind = Delivery.Kind.MECHANIC` (the default) and
  `mechanic`. It does not set `status_id` or `color`.
- `APPLY_STATUS` is kept only for outside-set statuses. Using it with a status id of the eight is an
  authoring mistake: `CombatManager._land` pushes an error and applies nothing when `MechanicRegistry.has(status_id)`. Because the check reads the registry, each status is converted in the step that adds its mechanic.
- `_land` calls `MechanicRegistry.get_mechanic(d.mechanic).land(d, self)` for `MECHANIC` deliveries,
  and keeps its current branches for the other kinds.
- `Item.uses(mechanic_id: String) -> bool` returns true when any effect's `mechanic` matches, and for
  `'crit'` when `crit_chance > 0`.
- Item type tags (weapon, armour, skill, spell, trinket) are unchanged and separate.

### Every current use of `Kind.DAMAGE` and `Kind.HEAL`

| File | Becomes |
|---|---|
| `src/combat/item.gd` (`display_value`, `_resolve_effect`) | The weak and empowered modifiers apply when `effect.mechanic == AttackMechanic.ID`. |
| `src/combat/combat_manager.gd` (`_fire_item`) | Blind makes a delivery evade when its mechanic is attack. |
| `src/combat/combat_manager.gd` (`_dot_visual`) | Sets `kind = MECHANIC` and `mechanic` to the status's id. |
| `src/scenes/combat/item_cell.gd` (`_effect_has_value`) | `MECHANIC` and `APPLY_STATUS` effects show a value. |
| `src/scenes/ui/tooltip/tooltip_content.gd` (`_effect_line`) | Attack and heal keep their line templates. The five status mechanics use the current "Gain {0} {chip}" / "Apply {0} {chip}" templates with the mechanic id as the chip. |
| `src/vfx/vfx_driver.gd` | The impact drawer dictionary is keyed by mechanic id for mechanic deliveries (all eight map to the current ring for now) and by kind for `APPLY_STATUS`. Numbers draw for attack and heal landings and for all `visual_only` deliveries. The big-hit check uses attack. |
| `src/vfx/drawers/damage_number_drawer.gd` | Heal styling applies when the mechanic is heal or regen. |
| `src/autotest/auto_test_driver.gd` (`_family_of`) | Families by mechanic: attack gives `'damage'`, shield gives `'shield'`, heal, poison, burn and bleed give their own names, regen gives `'heal'`. The `'block'` strategy name becomes `'shield'`, and the `'burn'` alias now targets the real burn family. |
| All catalogs (`item_catalog.gd`, `consumable_catalog.gd`) and tests | Converted to `mechanic`. |

`auto_test_driver.gd` line 142 and `tooltip_content.gd` line 121 check `APPLY_STATUS`. Extend both to
also read a mechanic effect's status (`MechanicRegistry.get_mechanic(effect.mechanic).status_id`).

## Regen and the combat log

`RegenStatus` extends `StatusEffect` directly. `setup` builds a ticker from `REGEN_TICK_INTERVAL`;
`on_step` heals the holder when the ticker crosses, resets it, and always returns false. Reapplying
adds stacks (the base default).

`CombatManager._advance_statuses_on` detects a status's health change by comparing health before and
after. It currently reacts only to a loss. Make it also react to a gain: add a visual-only delivery
for the number, and call `combat_log.on_heal` with the status's `name_key` as the source, as damage
ticks do with `on_status_damage`.

## Events

Today the Combat manager publishes `DAMAGE_DEALT`, `HEALED` and `STATUS_APPLIED` when deliveries land.
Replace all three with one event:

- `EventBus.Event.APPLIED`, published when a `MECHANIC` or `APPLY_STATUS` delivery lands and applies.
  The data is the mechanic id, or the status id for `APPLY_STATUS`. The source is the delivery's
  `source_actor`, as now.
- Ticks and bleed's own damage publish nothing, as now. `SUMMON` and `CREATE_ITEM` publish nothing,
  as now.
- `ITEM_FIRED` and `ITEM_DESTROYED` are unchanged. `CRIT` is new (see [Crit](#crit)).
- A trigger's `filter` names the id. The one current subscriber, Spite Ward (`ItemCatalog.AVENGER`),
  changes from `STATUS_APPLIED` to `APPLIED` with filter `'poison'`.
- `tooltip_content.gd`'s `_trigger_line` reads "When {0} is applied" for any filter, which covers the
  new ids.

Generic relics and enchantments written against a mechanic ("your burn items have +2 burn") are not
part of this plan.

## Health bar numbers

For each of shield, poison, burn, bleed and regen the actor has, show the stacks as a whole number in
the mechanic's colour next to the health bar. Nothing is drawn on the bar itself.

- Make one scene, `src/scenes/combat/status_numbers.tscn` with `status_numbers.gd`
  (`class_name StatusNumbers`), holding an `HBoxContainer` of labels. It reads an actor's statuses
  each frame and writes nothing.
- Add it beside the health bar in all three places that draw one: the player portrait in
  `combat_view_framed.tscn`, `enemy_hud.tscn` and `ally_slot.tscn`.
- The enemy HUD's status icons (`StatusIcon`) keep showing outside-set statuses only.
- Numbers are not translated.

## Tooltip keyword cards

- `KeywordCatalog.has` and `get_entry` check `MechanicRegistry` first, so a mechanic id returns the
  mechanic's name, description, colour and icon.
- `TooltipContent.keyword_ids` adds each effect's mechanic id (attack and heal included) and `'crit'`
  for an item with a crit chance.
- The tooltip stat block gets a crit line for an item with a crit chance, using a new translatable
  template `'Crit chance: {0}%'`.
- The `kw:unblockable` placeholder description changes "Block" to "Shield".

## Renaming block to shield

- `BlockStatus` (`block_status.gd`) becomes `ShieldStatus` (`shield_status.gd`), id `'shield'`.
  `PoolStatus` keeps its name.
- Balance constants ending in `_BLOCK` end in `_SHIELD` (`ARMOR_BLOCK`, the leather and bone item
  constants, `RELIC_STONE_WARD_BLOCK`, `RELIC_IRON_IDOL_BLOCK`).
- Relics in `relic_catalog.gd` apply `'shield'`.
- Combat log: `on_block` becomes `on_shield`, `block_by_item` becomes `shield_by_item`, `total_block`
  becomes `total_shield`, and the event record type `'block'` becomes `'shield'`. The same renames
  apply in `auto_test_logger.gd`, its report columns, and `combat_summary.gd` (including its
  translatable "+{3} block" text).
- Comments and doc text that say block mean shield. `Delivery.Flag.UNBLOCKABLE` keeps its name.
- Item display names are content and are not changed. Saves store item and relic ids, not status
  ids, so nothing is migrated.

## Content

- Convert every existing effect to the new fields. The values do not change.
- No items use burn, regen or crit. Test them with items built inside the tests. Writing items for
  them is the owner's work, so do not add any to catalogs.
- Bleed items (Bone Spear and others) now cash out on attacks received instead of the holder's
  fires. Do not re-tune them.
- If the seeded autotest stops winning because of a rule change, stop and report it with the before
  and after numbers. Do not change content values to make it pass.

## Order of work

Each step ends with the full GUT suite passing, a reimport with no script errors, and the full
headless run from [autotest.md](../systems/autotest.md#how-to-run) (`--autotest --seed 1 --speed 5
--timeout 120 --wall-timeout 30`, plus `--nosave --notutorial`) exiting 0. After adding or
changing translatable strings, run `tools/extract_pot.gd` and reimport.

| Step | Work | Tests to add |
|---|---|---|
| 1 | `Mechanic`, `MechanicRegistry`, attack, heal and shield. The `Delivery.Kind` change and the `mechanic` field. Convert all catalogs and tests. Rename block to shield everywhere. The colour renames. | Registry lookups. An attack effect deals damage and publishes nothing new yet. A shield effect applies shield. An `APPLY_STATUS` with `'shield'` applies nothing. |
| 2 | The `mechanic_id` argument through the damage pipeline and the shield multipliers. | The poison example above, with shield of 30 and 6. Unblockable skips shield. Vulnerable scales before shield. |
| 3 | Poison as a mechanic, converting poison effects from `APPLY_STATUS`. Burn and regen, with their statuses, mechanics, colours and constants. Regen's health gain in `_advance_statuses_on`. | Burn ticks and uses half shield. Regen heals each tick and never expires. A regen tick is logged as a heal. |
| 4 | Bleed as a mechanic and its new trigger, converting bleed effects from `APPLY_STATUS`. `StatusManager.reduce` and heal's removal of stacks. | Each case in the [Bleed](#bleed) list. Heal removes `floor(value * fraction)` of each of the three, and removes a status reaching zero. |
| 5 | Crit. | A crit chance of 1 doubles the eight's values and leaves outside-set values alone. A crit chance of 0 draws nothing from `rng`. `CRIT` is published. `display_value` is unchanged. |
| 6 | The `APPLIED` event replacing the three events. | Each mechanic publishes `APPLIED` with its id. Spite Ward still charges on poison. |
| 7 | Health bar numbers, keyword cards, the crit tooltip line, and panel colours from mechanics. | A keyword entry for a mechanic id. `StatusNumbers` shows one label per status of the eight and none for outside-set statuses. |

## Docs to update

Update these in the same change as the code, following [documentation.md](../documentation.md):

- A new `systems/mechanics.md` with an `index.md` row: the mechanic class, the registry, the eight and
  their rules, and how effects name a mechanic.
- `decision_log.md`: entry #38 for mechanics, the eight, shield replacing block, attack as a mechanic
  separate from damage, bleed triggering on attacks, heal removing stacks, crit, and the `APPLIED`
  event. Note in #5 and #35 that block is now shield and bleed no longer uses the fire hook.
- `systems/status_manager.md`: shield and its multipliers, the damage pipeline's mechanic argument,
  `on_holder_attacked`, `reduce`, burn, regen and bleed.
- `systems/combat_model.md`, `systems/combat_manager.md`, `systems/item.md`: `Delivery.Kind`,
  landing through mechanics, crit, the events.
- `systems/tooltips.md`, `systems/vfx_driver.md`, `systems/interface_palette.md`,
  `systems/run_screen.md`: keyword cards, drawers keyed by mechanic, colour names, health bar numbers.
- `systems/combat_log.md`, `systems/autotest.md`: the shield renames, the new strategy names and
  families.
- `design/game_design.md`, `design/armourer.md`, `design/mechanic_ideas.md`,
  `design/authoring.md`: block to shield, bleed's new trigger, and how to write an effect with
  `mechanic`.
- `handoff.md`: the "Last updated" line.
