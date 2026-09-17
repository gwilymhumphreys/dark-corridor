class_name Mechanic
extends RefCounted
## A mechanic is a named combat rule with one class that holds its name, description, icon,
## colour and what it does when a delivery lands (docs/plans/mechanics.md). Item effects name
## the mechanic they use, so items, relics and enchantments can refer to them ("your poison
## items", "when you shield"). One shared instance per id lives in the MechanicRegistry.


var id: String = ''
var name_key: String = ''
var desc_key: String = ''
var icon: String = ''
var status_id: String = ''   # the status this mechanic applies; empty for direct mechanics


## Its Colours variable. A function, so a palette applied at runtime is read each time.
func color() -> Color:
  return Color.WHITE


## How much of a shield a hit of this mechanic uses (1.0 = normal). Poison, burn and bleed
## return their constants once they are converted.
func shield_multiplier() -> float:
  return 1.0


## What happens when a delivery of this mechanic lands. The next step of
## docs/plans/mechanics.md fills this in; nothing calls it yet.
func land(delivery: Delivery, combat: CombatManager) -> void:
  pass
