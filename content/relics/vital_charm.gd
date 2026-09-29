extends RelicDef
## Vital Charm — a placeholder reward relic that raises maximum health once, when granted.


func _init() -> void:
  id = 'vital_charm'
  name_key = 'Vital Charm'
  icon = 'res://assets/icons/relics/necklace_04_love.png'   # placeholder picture for the owner to replace
  run_triggers = [
    {'event': RunManager.RunEvent.PICKED_UP, 'effects': [RunEffect.max_hp(20)]},
  ]
  panel_colour_name = 'RELIC_VITAL_CHARM'
