extends EnemyDef
## Spore Thrall — a placeholder summon (docs/systems/spore_engine.md): low health and one weak attack.
## Usable as a boss add, a player-side summon or a recruited ally.


func _init() -> void:
  id = 'spore_thrall'
  name_key = 'Spore Thrall'
  portrait = 'res://assets/portraits/enemies/monster_flower3.png'   # PLACEHOLDER portrait — owner's to swap
  max_hp = 15.0
  item_ids = ['claw']
