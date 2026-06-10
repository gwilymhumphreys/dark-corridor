class_name BlockStatus
extends PoolStatus
## Block — the absorb pool. Stacks additively, soaks incoming damage in the absorber stage (after
## Vulnerable's amplifier), and is removed once emptied. All behaviour lives in PoolStatus.

const ID := 'block'


func _init() -> void:
  id = ID
  name_key = 'Block'
  color = Colours.STATUS_BLOCK
