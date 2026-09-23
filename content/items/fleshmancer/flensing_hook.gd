extends ItemDef
## Flensing Hook — the Fleshmancer's self-harm producer: it damages its own holder and makes two
## Chunks of Flesh. The self-damage is unblockable so the holder's shield cannot absorb the cost.


func _init() -> void:
  id = 'flensing_hook'
  name_key = 'Flensing Hook'         # PLACEHOLDER name — owner's to rename
  types = [ItemType.SKILL]
  mechanics = [AttackMechanic.ID]
  icon = 'res://assets/icons/items/hook.png'
  cooldown = 4.0
  panel_colour_name = 'STATUS_DECAY'   # it is a flesh producer, not an attack
  var hurt := ItemEffect.attack(2.0, ItemEffect.Shape.SELF)
  hurt.flags = Delivery.Flag.UNBLOCKABLE

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
  effects = [hurt, make, make_second]
