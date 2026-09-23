extends EnemyDef
## Corridor Brute — a placeholder tougher regular enemy (decision #1).


func _init() -> void:
  id = 'brute'
  name_key = 'Corridor Brute'
  portrait = 'res://assets/portraits/enemies/gigant_06_ogre_warrior.png'   # PLACEHOLDER portrait — owner's to swap
  max_hp = 290.0
  item_ids = ['claw']
