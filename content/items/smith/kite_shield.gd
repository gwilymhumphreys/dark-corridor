extends ItemDef
## Kite Shield — one of the Smith's four armour pieces (docs/design/smith.md): plain shield on the holder,
## on a ladder of 3s to 6s cooldowns. Each spends its full budget from the curve in
## docs/design/item_heuristics.md. Name from docs/design/item_name_reference.md — the owner renames.


func _init() -> void:
  id = 'kite_shield'
  name_key = 'Kite Shield'
  types = [ItemType.ARMOUR]
  mechanics = [ShieldMechanic.ID]
  icon = 'res://assets/icons/items/metal_shield_1.png'
  cooldown = 5.0
  effects = [ItemEffect.shield(40.0)]
