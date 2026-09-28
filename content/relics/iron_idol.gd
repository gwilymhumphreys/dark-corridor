extends RelicDef
## Iron Idol — a placeholder reward relic: more shield at the start of each fight. Stacks with Stone
## Ward.


func _init() -> void:
  id = 'iron_idol'
  name_key = 'Iron Idol'
  icon = 'res://assets/icons/relics/statue_warrior_nb.png'   # placeholder picture for the owner to replace
  mechanics = [ShieldMechanic.ID]
  effects = [ItemEffect.shield(6.0)]
  trigger_subs = [{'event': EventBus.Event.FIGHT_START}]
  panel_colour_name = 'RELIC_IRON_IDOL'
