extends EncounterDef
## The normal shop: any items from the player's pool (owner, 2026-09-30). The name is a placeholder
## for the owner to replace.


func _init() -> void:
  id = 'shop_pedlar'
  type = Type.SHOP
  name_key = 'A pedlar\'s cart'   # placeholder name
  image = 'res://assets/encounters/goblin_merchant.jpg'   # placeholder image
  stock = [StockEntry.items(Balance.SHOP_ITEM_COUNT)]
