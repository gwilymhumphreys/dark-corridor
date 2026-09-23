extends ItemDef
## Pocket Shrooms — an attack that also blinds the struck enemy, so its attacks miss for the
## duration while its other effects still land. Rare for the access to blinding rather than for
## bigger numbers (rarity is complexity; docs/design/game_design.md).


func _init() -> void:
  id = 'pocket_shrooms'
  name_key = 'Pocket Shrooms'
  types = [ItemType.WEAPON]
  mechanics = [AttackMechanic.ID]
  icon = 'res://assets/icons/items/herbalism_24_stinkymushroom.png'
  rarity = Rarity.RARE
  cooldown = 3.0
  effects = [
    ItemEffect.attack(10.0),
    ItemEffect.apply_status('blind', 1.0, ItemEffect.Shape.OPPONENT_LEFTMOST,
        Balance.STATUS_BLIND_DURATION),
  ]
