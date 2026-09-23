extends ItemDef
## Hex Bolt — an unpooled example of targeting an enemy item (decisions #14 and #20): silences one
## random enemy item, picked on the fight's seeded random numbers.


func _init() -> void:
  id = 'hex_bolt'
  name_key = 'Hex Bolt'
  types = [ItemType.SPELL]
  mechanics = []
  icon = 'res://assets/icons/items/skill_shadow_curse_nb.png'
  cooldown = 2.5
  panel_colour_name = 'ARCANE'
  var hex := ItemEffect.apply_status('silence', 1.0, ItemEffect.Shape.OPPONENT_ITEM_RANDOM)
  hex.colour_name = 'ARCANE'
  effects = [hex]
