extends ItemDef
## Jar of Acid — a fast item that only applies poison (owner, 2026-09-23); acid is the Smith's
## poison (docs/design/smith.md). Its whole budget goes on poison: N stacks deal N + (N-1) + ... + 1
## damage, priced at the poison rate (docs/design/item_heuristics.md). No type yet.


func _init() -> void:
  id = 'jar_of_acid'
  name_key = 'Jar of Acid'
  types = []                         # no type yet — owner's to decide
  mechanics = [PoisonMechanic.ID]
  icon = 'res://assets/icons/items/alchemy_51_fastpoison.png'   # PLACEHOLDER icon — owner's to swap
  cooldown = 2.0
  effects = [ItemEffect.make(PoisonMechanic.ID, 4.0, ItemEffect.Shape.OPPONENT_LEFTMOST)]
