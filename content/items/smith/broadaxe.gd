extends ItemDef
## Broadaxe — one of the Smith's three big weapons (docs/design/smith.md). They share a per-hit
## ladder on 5s, 6s and 7s cooldowns, so the slowest is the best target for Mighty Blow's double.
## Each spends its full budget from the curve in docs/design/item_heuristics.md.


func _init() -> void:
  id = 'broadaxe'
  name_key = 'Broadaxe'              # PLACEHOLDER name — owner's to rename
  types = [ItemType.WEAPON]
  mechanics = [AttackMechanic.ID]
  icon = 'res://assets/icons/items/axe_hard_2.png'
  cooldown = 5.0
  effects = [ItemEffect.attack(44.0)]
