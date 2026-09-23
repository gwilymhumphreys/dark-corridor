extends ItemDef
## Acid Bath — a slow item that only applies poison (owner, 2026-09-23); acid is the Smith's poison
## (docs/design/smith.md). Its whole budget goes on poison, priced at the poison rate
## (docs/design/item_heuristics.md). No type yet.


func _init() -> void:
  id = 'acid_bath'
  name_key = 'Acid Bath'
  types = []                         # no type yet — owner's to decide
  mechanics = [PoisonMechanic.ID]
  icon = 'res://assets/icons/items/campfire_cauldron.png'   # PLACEHOLDER icon — owner's to swap
  cooldown = 7.0
  effects = [ItemEffect.make(PoisonMechanic.ID, 12.0, ItemEffect.Shape.OPPONENT_LEFTMOST)]
