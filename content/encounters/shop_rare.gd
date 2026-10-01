extends EncounterDef
## Placeholder shop: only rare items. Offered only when enough of the player's items are rare
## (EncounterDef.min_items). The name is a placeholder for the owner to replace.


func _init() -> void:
  id = 'shop_rare'
  type = Type.SHOP
  name_key = 'Rare goods'   # placeholder name
  image = 'res://assets/encounters/evil_merchant.jpg'   # placeholder image
  stock = [StockEntry.items_of_rarity(Balance.SHOP_ITEM_COUNT, ItemDef.Rarity.RARE)]
