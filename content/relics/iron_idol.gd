extends RelicDef
## Iron Idol — a placeholder reward relic: more shield at the start of each fight. Stacks with Stone
## Ward.


func _init() -> void:
  id = 'iron_idol'
  name_key = 'Iron Idol'
  kind = Kind.COMBAT_START_STATUS
  status_id = 'shield'
  status_count = 6.0
  panel_colour_name = 'RELIC_IRON_IDOL'
