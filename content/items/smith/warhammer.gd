extends ItemDef
## Warhammer — one of the Smith's three big weapons (docs/design/smith.md). They share a per-hit
## ladder on 5s, 6s and 7s cooldowns, so the slowest is the best target for Mighty Blow's double.
## Each spends its full budget from the curve in docs/design/item_heuristics.md.
## The blow also knocks one random enemy item's cooldown bar back (owner, 2026-09-23).


func _init() -> void:
  id = 'warhammer'
  name_key = 'Warhammer'            # PLACEHOLDER name — owner's to rename
  types = [ItemType.WEAPON]
  mechanics = [AttackMechanic.ID, DechargeMechanic.ID]
  icon = 'res://assets/icons/items/war_hammer.png'
  attack_sound = 'blunt'
  cooldown = 6.0
  effects = [
    ItemEffect.attack(73.0),
    ItemEffect.make(DechargeMechanic.ID, 1.0, ItemEffect.Shape.OPPONENT_ITEM_RANDOM),
  ]
