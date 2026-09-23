extends ItemDef
## Sundering Bolt — an unpooled example of a damage-taken status (decision #6): makes the leftmost
## enemy Vulnerable, so the next hits on it land harder.


func _init() -> void:
  id = 'sundering_bolt'
  name_key = 'Sundering Bolt'
  types = [ItemType.SKILL]
  mechanics = []
  icon = 'res://assets/icons/items/skill_break_medium_armor_nb.png'
  cooldown = 3.0
  effects = [
    ItemEffect.apply_status('vulnerable', 1.0, ItemEffect.Shape.OPPONENT_LEFTMOST,
        Balance.STATUS_VULNERABLE_DURATION),
  ]
