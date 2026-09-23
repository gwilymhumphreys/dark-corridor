extends ItemDef
## Venom Fang — an unpooled example of a poison applier.


func _init() -> void:
  id = 'venom_fang'
  name_key = 'Venom Fang'
  types = [ItemType.WEAPON]
  mechanics = [PoisonMechanic.ID]
  icon = 'res://assets/icons/items/loot_26_spiderteeth.png'
  cooldown = 1.6
  effects = [ItemEffect.make(PoisonMechanic.ID, 3.0, ItemEffect.Shape.OPPONENT_LEFTMOST)]
