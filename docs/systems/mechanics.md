# Mechanics

A mechanic is a named combat rule, such as attack or shield, with one class holding its name,
description, icon, colour and what happens when a delivery using it lands. Item effects will name the
mechanic they use, so items, relics and enchantments can refer to them. The owner's decision is #38 in
[decision_log.md](../decision_log.md). The full specification and the order of work are in
`docs/plans/mechanics.md`.

**Location:** `src/content/mechanics/`

## Built so far

Attack, heal and shield exist as classes and are registered. Nothing calls them yet: items still use
`Delivery.Kind.DAMAGE`, `HEAL` and `APPLY_STATUS`, and `CombatManager._land` still handles each kind.
Poison, burn, bleed, regen and crit are not built.

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
| `land(delivery, combat)` | What happens when a delivery lands. Empty until the next step. |

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
