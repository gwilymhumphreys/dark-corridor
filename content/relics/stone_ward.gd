extends RelicDef
## Stone Ward — starts every fight with shield on the player. Not in the reward pool.


func _init() -> void:
  id = 'stone_ward'
  name_key = 'Stone Ward'
  icon = 'res://assets/icons/relics/skill_magic_stone_nb.png'   # placeholder picture for the owner to replace
  kind = Kind.COMBAT_START_STATUS
  status_id = 'shield'
  status_count = 10.0
  panel_colour_name = 'RELIC_STONE_WARD'
