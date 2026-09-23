extends ItemDef
## Capped Cudgel — the middle of the Spore Druid weapon spread (docs/design/spore_druid.md): plain
## damage and no Spores, so it gets the full damage rate the Spore carriers give up. It is also the
## anchor the points curve is measured from (docs/design/item_heuristics.md).


func _init() -> void:
  id = 'capped_cudgel'
  name_key = 'Capped Cudgel'         # PLACEHOLDER name — owner's to rename
  types = [ItemType.WEAPON]
  mechanics = [AttackMechanic.ID]
  icon = 'res://assets/icons/items/club_v2_02.png'
  cooldown = 2.0
  effects = [ItemEffect.attack(10.0)]
