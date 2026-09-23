# Mechanics

A mechanic is a named combat rule, such as attack or shield, with one class holding its name,
description, icon, colour, sound and what happens when a delivery using it lands. Item effects name the
mechanic they use, so items, relics and enchantments can refer to them ("your poison items", "when
you shield"). The owner's decision is #38 in [decision_log.md](../decision_log.md); the model is the
card battler grail, which has a small fixed set of keywords that most of its cards are written in
terms of.

**Location:** `src/content/mechanics/`

All ten are built: attack, heal, shield, poison, burn, bleed, regen, crit, charge and decharge.

## Sound

`Mechanic.sound_key(delivery)` returns the folder of recordings played when a delivery of the
mechanic lands, which is `mechanics/` followed by the mechanic id. A new mechanic gets a sound
by existing: make a folder of that name under `assets/sound-effects/` and it plays. A mechanic
with no folder falls back to a shared default rather than going silent. The
[VFX wall](vfx_driver.md) plays it on the landing frame. See [audio.md](audio.md) for the
folder scheme.

Attack overrides it, because a hit varies by what swung and what it struck: the firing item's
`attack_sound` picks the folder and a shielded target adds `shielded` below it. A landing attack
also plays a second sound for the target itself, and a projectile plays a third while it is in
flight. The three layers are described in [audio.md](audio.md#the-three-layers-of-an-attack).

It takes the delivery so a mechanic can vary its sound by what landed. Attack is the only one
that does: a hit on a target holding shield plays `mechanics/attack/shielded` instead of
`mechanics/attack`, so the player hears whether they are still working through shield. The
shield is read when the sound plays rather than when the hit landed, so the hit that empties a
shield plays the plain sound. Reading it at landing time would mean recording the result on the
delivery and threading it through the damage pipeline, for a difference of one hit per shield.

A variant lives in a subfolder of the mechanic's own folder. The folder loader ignores
subdirectories, so the two do not read each other's files, and an empty variant folder falls
back to its parent, which means a variant can be added or removed without touching code.

## Words used here

- **Attack** is the mechanic for a direct hit from an item or potion.
- **Damage** is health or shield lost from any source. Poison, burn and bleed deal damage but are
  not attacks.
- **Stacks** is a status's `count`.
- **The set** means the ten mechanics below. **Outside the set** means every other status and
  delivery kind (weak, vulnerable, blind, silence, spores, decay, empowered, summon, item creation),
  all unchanged by this system.

Every number these rules use is a constant in `src/data/balance.gd`.

## The ten

| Mechanic | Id | What it is | What it does |
|---|---|---|---|
| **Attack** | `'attack'` | Direct | Deals damage to the target. |
| **Shield** | `'shield'` | Status on an actor | A pool that absorbs incoming damage before health and stays until used up. How much shield a hit uses depends on the mechanic that dealt it. Replaced block. |
| **Heal** | `'heal'` | Direct | Restores health up to maximum, then removes some poison, burn and bleed from the healed actor. |
| **Poison** | `'poison'` | Status on an actor, ticks | Every interval, deals its stacks times its per-tick damage to the holder, then loses a stack. Uses double shield. |
| **Burn** | `'burn'` | Status on an actor, ticks | The same as poison with its own constants, except that it uses half shield. Shield is the only rule that differs so far. |
| **Bleed** | `'bleed'` | Status on an actor, triggered by attacks | Each time the holder is hit by an attack, deals damage equal to its stacks to the holder, then loses a stack. Uses half shield. |
| **Regen** | `'regen'` | Status on an actor, ticks | Every interval, heals the holder by its stacks times its per-tick heal. Never loses stacks, so it lasts the whole fight. |
| **Crit** | `'crit'` | A chance on an item | When the item fires, rolls its crit chance. On a crit, that fire's mechanic values are multiplied. |
| **Charge** | `'charge'` | Direct, on an item | Adds seconds of progress to the target item's cooldown bar, so it fires sooner. |
| **Decharge** | `'decharge'` | Direct, on an item | Takes seconds of progress off the target item's cooldown bar, so it fires later. |

Poison, burn, bleed and regen are statuses that are also mechanics: their effects are delivered as
`MECHANIC` naming the mechanic, and their status classes copy their `name_key` / `desc_key` / `icon`
from their mechanic so the text is written once. Burn and poison extend `PeriodicStatus` (a tick
damage-over-time, and Mass fuel); regen and bleed extend `StatusEffect` directly and are not fuel.

**The descriptions are placeholders**, marked `# PLACEHOLDER desc` in the mechanic classes. They
are the text the tooltip keyword cards show the player, so the player is not yet told the real
rules. Writing them is the owner's work. The icons come from `IconSlots` (see below), so they
can be changed at runtime.

## Shield

When damage reaches shield, the shield loses the damage times the dealing mechanic's shield
multiplier (`MechanicRegistry.shield_multiplier`, 1.0 for an empty or unknown id). If the shield runs
out, the damage it could not cover goes to health unchanged. Poison drains shield double; burn and
bleed drain it half (`Balance.SHIELD_MULTIPLIER_*`). The calculation lives in `PoolStatus.absorb` —
see [status_manager.md](status_manager.md).

Worked example with the current constants: a 10 damage poison tick against 30 shield removes 20
shield and no health; against 6 shield, the shield covers 3 damage and is used up, and 7 goes to
health.

- The `unblockable` flag still skips shield entirely.
- Vulnerable still scales damage up before shield absorbs it (`modify_incoming` runs first).
- The damage pipeline carries the mechanic id: `Actor.take_damage`,
  `StatusManager.resolve_incoming_damage` and `StatusEffect.absorb` all take `mechanic_id`
  (default `''`). Every caller passes its own: the attack mechanic passes `'attack'`,
  `PeriodicStatus` passes its own id, and bleed passes `'bleed'`.

## Bleed

Bleed triggers only when an attack delivery lands on its holder, through the
`StatusEffect.on_holder_attacked` hook, which `AttackMechanic.land` runs after the damage resolves.
It bites the holder for its stacks and loses one.

- Poison and burn ticks, bleed's own damage and outside-set damage never trigger it, so it cannot
  repeat within a step.
- It triggers even when shield absorbs the whole attack.
- An attack that is evaded or fizzles does not land, so it does not trigger bleed.
- An attack that kills the holder does not trigger bleed.
- An attack with shape `ALL_OPPONENTS` triggers each target's bleed separately.
- Item type tags play no part: an attack from an item not tagged weapon still triggers it.
- Bleed keeps the flags it was applied with, so an unblockable bleed still skips shield.

This is a reaction inside the damage step, not an item trigger, so it does not conflict with the rule
that triggers only charge items ([combat_model.md](combat_model.md)).

## Heal

A heal delivery, after healing, removes `floor(value × Balance.HEAL_CLEANSE_FRACTION)` stacks of the
target's poison, burn and bleed via `StatusManager.reduce` (which works on any status, not only fuel,
and removes a status reduced to zero with `on_expire`). `value` is the full heal, including overheal.

- Regen's ticks are not heal deliveries, so they remove nothing.
- Heals from potions are heal deliveries, so they do remove stacks.

The Combat manager's status pass reacts to a status's health **gain** as well as its loss: a regen
tick spawns the same visual-only number (drawn with the heal `+` styling, since its mechanic is the
status id) and logs a heal.

## Crit

Crit is a chance on an item, not a delivery: `ItemDef.crit_chance` (0 to 1). When the item fires, the
Combat manager rolls once on the seeded per-fight RNG — items with no crit chance draw nothing from
it, so existing fights and seeded autotest runs are unchanged. On a crit, the values of that fire's
mechanic deliveries are multiplied by `Balance.CRIT_MULTIPLIER` (after enchant, weak, empower and
both kinds of consume) and flagged `Delivery.crit`; outside-set deliveries and durations are
untouched. `EventBus.Event.CRIT` is published with the item's def id as data, the owner as source,
straight after `ITEM_FIRED`. Thrown consumables never crit, and `Item.display_value` never rolls (the
tooltip shows the value without crit). `CritMechanic` has no `land` override — it is never delivered.
A landing flagged `crit` plays `mechanics/crit` on top of its own sound ([vfx_driver.md](vfx_driver.md)).

## Charge and decharge

Charge and decharge move an **item's** cooldown bar. An `Item` owns a `Ticker` whose `accum` fills
one step at a time until it reaches `threshold`, then the item fires. Charge adds the delivery's
value in seconds of progress to the target item's bar; decharge takes the same away. The effect's
value is always authored positive — the mechanic applies the sign — and one second of progress is
`1.0 / Balance.STEP` steps.

Both are `MECHANIC` deliveries whose target is an `Item`, so an effect using them needs an item
target shape ([item.md](item.md#targeting-declare-a-shape-dont-resolve-a-target)). The two
own-board shapes, `own-item-random` and `all-own-items`, were added for them; the two opponent-item
shapes work as well, and a decharge on the enemy's board is what they are for.

- The shift is **clamped to the bar** — never below empty, never past full. A charge can therefore
  never bank more than one fire, which is the same rule decision #30 applies to a gate.
- A **gated** item (silenced) is unaffected by either. Its bar is frozen while the gate sits on it
  and even trigger pushes are dropped (decision #30), so a charge must bank nothing there either.
- A land that shifts the bar by nothing — charging a full bar, decharging an empty one — publishes
  no event and writes no log entry.
- A delivery aimed at an `Actor` instead of an `Item` is an authoring mistake: it pushes an error
  and does nothing.
- The **firing item is left out** of both own-board shapes. An item that could charge itself with
  travel 0 would refill its own bar the step it fired, then fire every step after that.
- `ChargeMechanic.shift_cooldown(item, seconds)` holds the shared arithmetic; `DechargeMechanic`
  calls it with a negative value. It returns the seconds actually applied, which is what the log
  records.

The combat log gets a `charge` event through `CombatLog.on_charge`, holding the seconds applied
(negative for a decharge) and the affected item's `name_key`. There is no per-item tally — charge
moves no health, shield or status. The combat summary draws it as a signed number of seconds.

**Scoping which items they pick is built.** An effect can carry a target filter that narrows the
pool by item type tag and by mechanic before the pick, so a charge can be aimed at your weapons or
at the enemy's poison items rather than at any item on the board. It lives with the target shapes,
not with the mechanics — see [item.md](item.md#targeting-declare-a-shape-dont-resolve-a-target).
Naming a specific item definition as the target is still not built.

## The APPLIED event

Landing publishes one event, `EventBus.Event.APPLIED`, when a `MECHANIC` or `APPLY_STATUS` delivery
lands and applies. It replaced `DAMAGE_DEALT`, `HEALED` and `STATUS_APPLIED`. The data is the
mechanic id (attack, heal, shield, poison, burn, bleed, regen, charge, decharge) or the status id
for `APPLY_STATUS`;
the source is the delivery's `source_actor`. Ticks, bleed's own damage, `SUMMON` and `CREATE_ITEM`
publish nothing. A trigger's `filter` names the id — Spite Ward (`content/items/examples/spite_ward.gd`) subscribes to
`APPLIED` filtered to `'poison'`.

## How effects name a mechanic

`ItemEffect`, `Payload` and `Delivery` have a `mechanic` id. `Delivery.Kind` is `{ MECHANIC,
APPLY_STATUS, SUMMON, CREATE_ITEM }`, and `MECHANIC` is the default. An effect using a mechanic sets
only `mechanic` (plus value, shape, travel, flags), not `status_id` or `color`:
`Payload.from_effect` takes the colour from the mechanic.

- `CombatManager._land` calls `MechanicRegistry.get_mechanic(d.mechanic).land(d, self)` for a
  `MECHANIC` delivery. It keeps its own branches for the other kinds.
- `APPLY_STATUS` is for statuses that are not mechanics. Using it with a mechanic's status id
  (`'shield'`, `'poison'`, `'burn'`, `'bleed'`, `'regen'`) pushes an error and applies nothing.
- `Item.uses(mechanic_id)` is true when any of the item's effects uses that mechanic; for `'crit'`
  it is true when the item has a crit chance (`ItemDef.crit_chance > 0`).
- Weak and empower modify effects whose mechanic is attack, and blind makes attacks miss.
- Item type tags (weapon, armour, skill, spell, trinket) are unchanged and separate.

## The Mechanic class

`Mechanic` (`mechanic.gd`) is the base. Each mechanic is a subclass in its own file with `const ID`.

| Member | Purpose |
|---|---|
| `id` | The mechanic id, such as `'attack'`. |
| `name_key`, `desc_key` | Translatable name and description, set by plain assignment in `_init` so `tools/extract_pot.gd` finds them. |
| `icon` | A `res://` icon path, set from `IconSlots.icon_for(ID)` in `_init`. |
| `status_id` | The status the mechanic applies (`'shield'`), or empty for mechanics that act directly (attack, heal). |
| `color() -> Color` | Returns the mechanic's `Colours` variable. It is a function so a palette applied at runtime is read each time. |
| `shield_multiplier() -> float` | How much shield a hit of this mechanic uses. 1.0 by default. |
| `land(delivery, combat)` | What happens when a delivery lands. The base applies the mechanic's `status_id` (shield); `AttackMechanic` and `HealMechanic` override it for their direct effects. Each `land` publishes the `APPLIED` event and writes the combat log entry for its mechanic. Only `CombatManager._land` calls it. |

`ShieldStatus`, `PoisonStatus`, `BurnStatus`, `BleedStatus` and `RegenStatus` each copy their
`name_key`, `desc_key` and `icon` from their mechanic. The statuses keep these fields because the
combat log, status icons and combat summary read them.

## MechanicRegistry

`mechanic_registry.gd` builds one shared instance per id the first time it is used, like
`StatusRegistry`. A new mechanic is a class file plus one line in `_build`.

| Function | Returns |
|---|---|
| `has(id)` | Whether the id is a registered mechanic. |
| `get_mechanic(id)` | The shared instance. Pushes an error and returns null for an unknown id. |
| `shield_multiplier(id)` | The mechanic's shield multiplier, or 1.0 for an empty or unknown id. |
| `refresh_icons()` | Sets `icon` on every already-built instance from `IconSlots.icon_for(id)`. Does nothing if nothing is built yet. |

## IconSlots

`IconSlots` (`icon_slots.gd`) is a static class that owns the game's icon slots. Each mechanic id
is a slot, plus three non-mechanic slots (`charge_time`, `card`, `hp`). Each slot has a folder of candidate
icons and a default. A chosen icon is saved to `chosen.cfg` and read back lazily on first use; a
missing file is not an error, so every slot falls back to its default.

| Function | Returns |
|---|---|
| `icon_for(slot)` | The chosen path if one is set, else the slot's default, else `''` for an unknown slot. |
| `candidates(slot)` | Every `.png` in the slot's folder, sorted by file name. In an exported build returns the default alone. |
| `display_name(slot)` | The slot's display name, first letter upper-cased. |
| `set_icon(slot, path)` | Records the chosen icon and saves `chosen.cfg`. |
| `reset()` | Drops in-memory choices so the next read re-reads `chosen.cfg`. |

The five statuses that copy a mechanic's icon in `_init` need no special handling: a status built
after a change already has the new icon.

## Colours

Each mechanic has a variable in the "Mechanics" section of `src/data/colours.gd`. The owner set them
on 2026-09-18:

| Mechanic | Colour |
|---|---|
| Attack | Red |
| Shield | Yellow |
| Heal | Green |
| Regen | Light green — the heal green lifted, since regen is heal over time |
| Poison | Dark green — held away from the heal green |
| Burn | Orange |
| Bleed | Maroon leaning purple |
| Crit | Placeholder pale yellow, not yet chosen |
| Charge | White |
| Decharge | Grey |

Interface palette files name them in lower case (`attack`, `poison`); see
[interface_palette.md](interface_palette.md). `ui-default.gpl` carries the same values, and the other
palettes in `assets/palettes/new/ui/` carry all ten fitted to their own schemes.

## Health bar numbers

`StatusNumbers` (`src/scenes/combat/status_numbers.tscn` / `.gd`) sits beside the health bar in all
three places that draw one (the player portrait in `combat_view_framed.tscn`, `enemy_hud.tscn` and
`ally_slot.tscn`). It holds one `Label` per mechanic status — shield, poison, burn, bleed, regen —
and each frame shows the actor's stack count for that status in the mechanic's colour (the numbers
are not translated). It reads the actor's statuses; writes nothing. The enemy HUD's status-icon row
(`StatusIcon`) shows only the OUTSIDE-set statuses — the mechanic statuses read off the numbers
instead.

## Tooltip keyword cards

`KeywordCatalog.has` / `get_entry` resolve a **mechanic** id from its `Mechanic` class (name /
desc / colour / icon), so all ten mechanics have cards
([tooltips.md](tooltips.md)). `TooltipContent.keyword_ids` adds each effect's mechanic id (attack and
heal included) and `crit` for an item with a crit chance, and such an item gets an extra effect
line reading its chance as a percentage beside the crit glyph.

## Content

No items use burn, regen, crit or charge yet — they are covered by items built inside the tests.
The Smith's Warhammer is the first item to use decharge. Writing items for them is the owner's
work. Bleed items cash out on attacks received rather than on the
holder's own fires, and were not re-tuned for the change.

## Lineage

The original specification and the order of work are in
[`plans/mechanics.md`](../plans/mechanics.md), kept for rationale. Everything still true of the built
system is on this page; the plan is history and is not maintained.
