class_name LifeDef
extends ItemDef
## A life as one of the goods a shop or reward encounter offers (decision #69): taking it adds one to
## RunManager.lives. It is an item definition, the way potions and relics are, so it is shown and
## bought like any good, through an Item built from it. Only the presentation fields are used; it
## never goes on the board and never fires.


func _init() -> void:
  id = 'life'
  name_key = 'Life'
  description_key = 'One more fight you can lose.'   # placeholder text for the owner to rewrite
  icon = 'res://assets/icons/mechanics/hp/hearts.png'   # placeholder picture for the owner to replace
