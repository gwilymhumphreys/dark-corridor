extends ItemDef
## Skin Graft — a flesh consumer: each fire eats one Chunk of Flesh from its own board to heal. All
## of the healing comes from the chunk, so with no chunk it heals nothing. Eating a chunk destroys it,
## so it also fills Flesh Explosion. With Flensing Hook this is a net health gain; the heal per chunk
## is the value to watch.


func _init() -> void:
  id = 'skin_graft'
  name_key = 'Skin Graft'            # PLACEHOLDER name — owner's to rename
  types = [ItemType.SKILL]
  mechanics = [HealMechanic.ID]
  icon = 'res://assets/icons/items/loot_99_needle.png'
  cooldown = 4.0
  var graft := ItemEffect.heal(0.0)
  graft.consume_item_def_id = 'chunk_of_flesh'
  graft.consume_item_amount = 1
  graft.consume_item_scale = 4.0     # healing per chunk eaten
  effects = [graft]
