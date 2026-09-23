extends RelicDef
## Vital Charm — a placeholder reward relic that raises maximum health once, when granted.


func _init() -> void:
  id = 'vital_charm'
  name_key = 'Vital Charm'
  kind = Kind.MAX_HP_BONUS
  max_hp_bonus = 20.0
  panel_colour_name = 'RELIC_VITAL_CHARM'
