class_name ShieldStatus
extends PoolStatus
## Shield — the absorb pool. Stacks additively, soaks incoming damage in the absorber stage (after
## Vulnerable's amplifier), and is removed once emptied. All behaviour lives in PoolStatus.

const ID := 'shield'


func _init() -> void:
  id = ID
  name_key = 'Shield'
  desc_key = 'Absorbs incoming damage, then wears off.'   # PLACEHOLDER desc — owner writes
  color = Colours.SHIELD
  icon = 'res://assets/icons/statuses/skill_shield_block_nb.png'
