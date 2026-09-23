extends EnemyDef
## Corridor Warden — the placeholder boss (decision #1): more health and two items, with no signature
## mechanic yet. The final act's boss ends the run because of where it sits, not because of this
## definition.


func _init() -> void:
  id = 'boss'
  name_key = 'Corridor Warden'
  portrait = 'res://assets/portraits/enemies/undead_07_soulhunter.png'   # PLACEHOLDER portrait — owner's to swap
  max_hp = 575.0
  item_ids = ['claw', 'claw']
