extends ItemDef
## Warhammer — the Smith's one-handed weapon (docs/design/smith.md), at the slow end of the one-hand
## range of 1s to 4s cooldowns (docs/design/item_heuristics.md → Weapon cooldowns). The blow also
## knocks one random enemy item's cooldown bar back (owner, 2026-09-23). Damage is the 4s budget
## less the decharge's points.


func _init() -> void:
  id = 'warhammer'
  name_key = 'Warhammer'            # PLACEHOLDER name — owner's to rename
  types = [ItemType.WEAPON]
  mechanics = [AttackMechanic.ID, DechargeMechanic.ID]
  icon = 'res://assets/icons/items/war_hammer.png'
  attack_sound = 'blunt'
  cooldown = 4.0
  effects = [
    ItemEffect.attack(24.0),
    ItemEffect.make(DechargeMechanic.ID, 1.0, ItemEffect.Shape.OPPONENT_ITEM_RANDOM),
  ]
