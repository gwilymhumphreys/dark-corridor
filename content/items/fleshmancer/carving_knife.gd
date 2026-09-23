extends ItemDef
## Carving Knife — the fast end of the Fleshmancer's attacks (docs/design/character_ideas.md → Flesh
## Golem / Meat): low damage plus a Chunk of Flesh on its own board. Chunk creators have a 3s minimum
## cooldown: a chunk lives about 4s, so faster creation piles them up.


func _init() -> void:
  id = 'carving_knife'
  name_key = 'Carving Knife'
  types = [ItemType.WEAPON]
  mechanics = [AttackMechanic.ID]
  icon = 'res://assets/icons/items/dagger_01.png'
  cooldown = 3.0

  var make := ItemEffect.new()
  make.kind = Delivery.Kind.CREATE_ITEM
  make.create_item_def_id = 'chunk_of_flesh'
  make.shape = ItemEffect.Shape.SELF
  make.colour_name = 'STATUS_DECAY'
  effects = [ItemEffect.attack(3.0), make]
