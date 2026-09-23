extends ItemDef
## Dagger — the Smith's plain one-handed blade (docs/design/smith.md). Daggers lean towards bleed:
## a fast weapon sets off the bleed it applies with its own next hit. The damage and bleed together
## spend the 2s budget (docs/design/item_heuristics.md). Name from
## docs/design/item_name_reference.md.


func _init() -> void:
  id = 'dagger'
  name_key = 'Dagger'
  types = [ItemType.WEAPON]
  mechanics = [AttackMechanic.ID, BleedMechanic.ID]
  icon = 'res://assets/icons/items/dagger_06.png'   # PLACEHOLDER icon — owner's to swap
  attack_sound = 'blade'
  cooldown = 2.0
  effects = [
    ItemEffect.attack(7.0),
    ItemEffect.make(BleedMechanic.ID, 3.0, ItemEffect.Shape.OPPONENT_LEFTMOST),
  ]
