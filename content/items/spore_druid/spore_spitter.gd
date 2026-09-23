extends ItemDef
## Spore Spitter — the fast end of the Spore Druid weapon spread (docs/design/spore_druid.md): a quick
## jab for low damage plus one Spore, the kit's fastest source of Spores. It gives up the most damage
## for that rate.


func _init() -> void:
  id = 'spore_spitter'
  name_key = 'Spore Spitter'         # PLACEHOLDER name — owner's to rename
  types = [ItemType.WEAPON]
  mechanics = [AttackMechanic.ID]
  icon = 'res://assets/icons/items/herbalism_28_stinkymushroom.png'
  cooldown = 1.0
  effects = [
    ItemEffect.attack(4.0),
    ItemEffect.apply_status('spores', 1.0, ItemEffect.Shape.OPPONENT_LEFTMOST),
  ]
