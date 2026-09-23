extends ItemDef
## Vambraces — one of the Smith's four armour pieces (docs/design/smith.md): plain shield on the holder,
## on a ladder of 3s to 6s cooldowns. Each spends its full budget from the curve in
## docs/design/item_heuristics.md. Name from docs/design/item_name_reference.md — the owner renames.


func _init() -> void:
  id = 'vambraces'
  name_key = 'Vambraces'
  types = [ItemType.ARMOUR]
  mechanics = [ShieldMechanic.ID]
  icon = 'res://assets/icons/items/gloves_01.png'
  cooldown = 3.0
  effects = [ItemEffect.shield(15.0)]
