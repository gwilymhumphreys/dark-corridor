extends ItemDef
## Wilt Frond — an attack that also applies Weak (decision #28). Weak is parked and unpriced
## (docs/design/item_heuristics.md), so this item stays as authored until the timed debuffs are
## decided on.


func _init() -> void:
  id = 'wilt_frond'
  name_key = 'Wilt Frond'             # PLACEHOLDER name — owner's to rename
  types = [ItemType.WEAPON]
  mechanics = [AttackMechanic.ID]
  icon = 'res://assets/icons/items/herbalism_20_sickflower.png'
  cooldown = 4.0
  effects = [
    ItemEffect.attack(20.0),
    ItemEffect.apply_status('weak', 1.0, ItemEffect.Shape.OPPONENT_LEFTMOST,
        Balance.STATUS_WEAK_DURATION),
  ]
