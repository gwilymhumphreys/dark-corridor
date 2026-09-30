extends EncounterDef
## Placeholder shop: only items that list the regen mechanic (ItemDef.mechanics). Offered only when
## enough of the player's items do (EncounterDef.min_items). The name is a placeholder for the owner
## to replace.


func _init() -> void:
  id = 'shop_regen'
  type = Type.SHOP
  name_key = 'Regen shop'   # placeholder name
  stock = [StockEntry.items_with_mechanic(Balance.SHOP_ITEM_COUNT, RegenMechanic.ID)]
