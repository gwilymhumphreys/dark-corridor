extends ItemDef
## Sallet — one of the Smith's four armour pieces (docs/design/smith.md): plain shield on the holder,
## on a ladder of 3s to 6s cooldowns. Each spends its full budget from the curve in
## docs/design/item_heuristics.md. Name from docs/design/item_name_reference.md — the owner renames.


func _init() -> void:
  id = 'sallet'
  name_key = 'Sallet'
  types = [ItemType.ARMOUR]
  mechanics = [ShieldMechanic.ID]
  icon = 'res://assets/icons/items/helm_footman_1.png'
  cooldown = 4.0
  effects = [ItemEffect.shield(24.0)]
