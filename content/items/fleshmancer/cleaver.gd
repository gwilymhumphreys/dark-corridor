extends ItemDef
## Cleaver — the middle of the Fleshmancer's attacks: makes a Chunk of Flesh more slowly than the
## Carving Knife but hits harder, so neither dominates.


func _init() -> void:
  id = 'cleaver'
  name_key = 'Cleaver'               # PLACEHOLDER name — owner's to rename
  types = [ItemType.WEAPON]
  mechanics = [AttackMechanic.ID]
  icon = 'res://assets/icons/items/dagger_38.png'
  cooldown = 4.0

  var make := ItemEffect.new()
  make.kind = Delivery.Kind.CREATE_ITEM
  make.create_item_def_id = 'chunk_of_flesh'
  make.shape = ItemEffect.Shape.SELF
  make.colour_name = 'STATUS_DECAY'
  effects = [ItemEffect.attack(6.0), make]
