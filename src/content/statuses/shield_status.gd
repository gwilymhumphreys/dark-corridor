class_name ShieldStatus
extends PoolStatus
## Shield — the absorb pool. Stacks additively, soaks incoming damage in the absorber stage (after
## Vulnerable's amplifier), and is removed once emptied. All behaviour lives in PoolStatus.

const ID := 'shield'


func _init() -> void:
  id = ID
  # Presentation is written once, in the mechanic (docs/plans/mechanics.md) — copy it here so the
  # combat log, status icons and combat summary keep reading the status's own fields.
  var mechanic: Mechanic = MechanicRegistry.get_mechanic(ID)
  name_key = mechanic.name_key
  desc_key = mechanic.desc_key
  icon = mechanic.icon
  color = Colours.SHIELD
