extends ItemDef
## Mighty Blow — the Smith's empower skill (docs/design/smith.md → The empower engine). Each fire
## adds one Empowered stack to the holder, and each stack raises the next attack by
## Balance.EMPOWER_MULT. Each stack costs Balance.POINTS_PER_EMPOWERED_STACK
## (docs/design/item_heuristics.md → The Smith against the curve).


func _init() -> void:
  id = 'mighty_blow'
  name_key = 'Mighty Blow'           # PLACEHOLDER name — owner's to rename
  types = [ItemType.SKILL]
  mechanics = []
  icon = 'res://assets/icons/items/skill_strong_attack_nb.png'
  cooldown = 5.0
  effects = [ItemEffect.apply_status('empowered', 1.0, ItemEffect.Shape.SELF)]
