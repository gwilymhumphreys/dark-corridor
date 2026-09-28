extends RelicDef
## Stone Ward — shield on its owner at the start of every fight. Not in the reward pool.


func _init() -> void:
  id = 'stone_ward'
  name_key = 'Stone Ward'
  icon = 'res://assets/icons/relics/skill_magic_stone_nb.png'   # placeholder picture for the owner to replace
  mechanics = [ShieldMechanic.ID]
  effects = [ItemEffect.shield(10.0)]
  trigger_subs = [{'event': EventBus.Event.FIGHT_START}]
  panel_colour_name = 'RELIC_STONE_WARD'
