class_name ShieldMechanic
extends Mechanic
## Shield — the mechanic for the absorb pool (docs/systems/mechanics.md). Replaces block: a pool
## that absorbs incoming damage before health and stays until used up. How much shield a hit
## uses depends on the mechanic that dealt it.

const ID := 'shield'


func _init() -> void:
  id = ID
  name_key = 'Shield'
  desc_key = 'Absorbs incoming damage, then wears off.'   # PLACEHOLDER desc — owner writes
  icon = 'res://assets/icons/statuses/skill_shield_block_nb.png'
  status_id = 'shield'


func color() -> Color:
  return Colours.SHIELD
