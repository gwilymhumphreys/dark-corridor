extends ItemDef
## Bone Saw — the slow end of the Fleshmancer's attacks: low damage and two Chunks of Flesh in one
## swing, the same chunk rate as the Carving Knife but in bursts.


func _init() -> void:
  id = 'bone_saw'
  name_key = 'Bone Saw'             # PLACEHOLDER name — owner's to rename
  types = [ItemType.WEAPON]
  mechanics = [AttackMechanic.ID]
  icon = 'res://assets/icons/items/loot_12_saw.png'
  cooldown = 6.0

  var make := ItemEffect.new()
  make.kind = Delivery.Kind.CREATE_ITEM
  make.create_item_def_id = 'chunk_of_flesh'
  make.shape = ItemEffect.Shape.SELF
  make.colour_name = 'STATUS_DECAY'
  var make_second := ItemEffect.new()
  make_second.kind = Delivery.Kind.CREATE_ITEM
  make_second.create_item_def_id = 'chunk_of_flesh'
  make_second.shape = ItemEffect.Shape.SELF
  make_second.colour_name = 'STATUS_DECAY'
  effects = [ItemEffect.attack(4.0), make, make_second]
