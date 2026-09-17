# Mechanics

A mechanic is a named combat rule, such as attack or shield, with one class holding its name,
description, icon, colour and what happens when a delivery using it lands. Item effects will name the
mechanic they use, so items, relics and enchantments can refer to them. The owner's decision is #38 in
[decision_log.md](../decision_log.md). The full specification and the order of work are in
`docs/plans/mechanics.md`.

**Location:** `src/content/mechanics/`

## Built so far

Attack, heal and shield are built. Poison, burn, bleed, regen and crit are not; poison and bleed
effects still use `APPLY_STATUS`.

The damage pipeline carries a mechanic id (`take_damage` / `resolve_incoming_damage` / `absorb`
take `mechanic_id`, default `''`), and the shield pool spends the dealing mechanic's multiplier
(`MechanicRegistry.shield_multiplier`). Only registered mechanic ids change
the multiplier, so nothing behaves differently until poison, burn and bleed are converted.

## How effects name a mechanic

`ItemEffect`, `Payload` and `Delivery` have a `mechanic` id. `Delivery.Kind` is `{ MECHANIC,
APPLY_STATUS, SUMMON, CREATE_ITEM }`, and `MECHANIC` is the default. An effect using a mechanic sets
only `mechanic` (plus value, shape, travel, flags), not `status_id` or `color`:
`Payload.from_effect` takes the colour from the mechanic.

- `CombatManager._land` calls `MechanicRegistry.get_mechanic(d.mechanic).land(d, self)` for a
  `MECHANIC` delivery. It keeps its own branches for the other kinds.
- `APPLY_STATUS` is for statuses that are not mechanics. Using it with a mechanic's status id
  (`'shield'`) pushes an error and applies nothing.
- `Item.uses(mechanic_id)` is true when any of the item's effects uses that mechanic.
- Weak and empower modify effects whose mechanic is attack, and blind makes attacks miss.

## The Mechanic class

`Mechanic` (`mechanic.gd`) is the base. Each mechanic is a subclass in its own file with `const ID`.

| Member | Purpose |
|---|---|
| `id` | The mechanic id, such as `'attack'`. |
| `name_key`, `desc_key` | Translatable name and description, set by plain assignment in `_init` so `tools/extract_pot.gd` finds them. |
| `icon` | A `res://` icon path. |
| `status_id` | The status the mechanic applies (`'shield'`), or empty for mechanics that act directly (attack, heal). |
| `color() -> Color` | Returns the mechanic's `Colours` variable. It is a function so a palette applied at runtime is read each time. |
| `shield_multiplier() -> float` | How much shield a hit of this mechanic uses. 1.0 by default. |
| `land(delivery, combat)` | What happens when a delivery lands. The base applies the mechanic's `status_id` (shield); `AttackMechanic` and `HealMechanic` override it for their direct effects. |

`ShieldStatus` copies its `name_key`, `desc_key` and `icon` from `ShieldMechanic`, so the text is
written once. The status keeps these fields because the combat log, status icons and combat summary
read them.

## MechanicRegistry

`mechanic_registry.gd` builds one shared instance per id the first time it is used, like
`StatusRegistry`. A new mechanic is a class file plus one line in `_build`.

| Function | Returns |
|---|---|
| `has(id)` | Whether the id is a registered mechanic. |
| `get_mechanic(id)` | The shared instance. Pushes an error and returns null for an unknown id. |
| `shield_multiplier(id)` | The mechanic's shield multiplier, or 1.0 for an empty or unknown id. |

## Colours

Each mechanic has a variable in the "Mechanics" section of `src/data/colours.gd`: `ATTACK`, `SHIELD`,
`HEAL`, `POISON`, `BURN`, `BLEED`, `REGEN` and `CRIT`. Burn, bleed, regen and crit are placeholders for
the owner to re-tint. Interface palette files name them in lower case (`attack`, `poison`); see
[interface_palette.md](interface_palette.md).
