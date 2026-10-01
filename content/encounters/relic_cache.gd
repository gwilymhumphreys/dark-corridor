extends EncounterDef
## Placeholder reward encounter: no fight; the player picks one of three relics. The name is a
## placeholder for the owner to rename.


func _init() -> void:
  id = 'relic_cache'
  type = Type.REWARD
  name_key = 'A forgotten reliquary'   # placeholder name
  image = 'res://assets/encounters/treasure_box.jpg'   # placeholder image
  stock = [StockEntry.relics(3)]
