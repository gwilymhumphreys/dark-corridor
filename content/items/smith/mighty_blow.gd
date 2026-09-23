extends ItemDef
## Mighty Blow — the Smith's empower skill (docs/design/smith.md → The empower engine). Each fire
## banks one Empowered charge on the holder, and each charge doubles the next weapon attack. Its
## cooldown matches the Greatsword's, which puts it on budget: one cycle adds one weapon hit, and the
## Greatsword's hit is the budget at that cooldown (docs/design/item_heuristics.md).


func _init() -> void:
  id = 'mighty_blow'
  name_key = 'Mighty Blow'           # PLACEHOLDER name — owner's to rename
  types = [ItemType.SKILL]
  mechanics = []
  icon = 'res://assets/icons/items/skill_strong_attack_nb.png'
  cooldown = 7.0
  effects = [ItemEffect.apply_status('empowered', 1.0, ItemEffect.Shape.SELF)]
