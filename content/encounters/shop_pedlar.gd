extends EncounterDef
## Placeholder shop: a few items, a relic and a potion for gold. The name and the stock are
## placeholders for the owner to replace.


func _init() -> void:
  id = 'shop_pedlar'
  type = Type.SHOP
  name_key = 'A pedlar\'s cart'   # placeholder name
  stock = [StockEntry.items(3), StockEntry.relics(1), StockEntry.potions(1)]
