extends EnemyDef
## Corridor Grunt — the placeholder regular enemy. Its health is the points curve's beat 0 target less
## what its Claw spends (docs/design/item_heuristics.md).


func _init() -> void:
  id = 'grunt'
  name_key = 'Corridor Grunt'
  portrait = 'res://assets/portraits/enemies/goblin_01.png'   # PLACEHOLDER portrait — owner's to swap
  max_hp = 168.0
  item_ids = ['claw']
