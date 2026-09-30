extends EncounterDef
## Placeholder shop: only items that list the heal mechanic (ItemDef.mechanics). Offered only when
## enough of the player's items do (EncounterDef.min_items). The name is a placeholder for the owner
## to replace.


func _init() -> void:
  id = 'shop_heal'
  type = Type.SHOP
  name_key = 'Heal shop'   # placeholder name
  stock = [StockEntry.items_with_mechanic(Balance.SHOP_ITEM_COUNT, HealMechanic.ID)]
