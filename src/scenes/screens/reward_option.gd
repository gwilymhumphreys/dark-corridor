class_name RewardOption
extends Button
## One option in the reward overlay (docs/systems/draft.md): a button wrapping the same `ItemCell`
## the board uses, so a reward answers the pointer like every other control the player picks — the
## border on hover, the press squash, the release pulse and the click sound of `UIJuice`
## (docs/systems/control_feedback.md). The button itself draws nothing (`ButtonBare`); the juice
## draws the highlight on the cell's frame. While a `RewardSpin` spins it, the cell shows other item
## icons and no good, so it has no tooltip, until `land`. Reads the Item it is handed; writes nothing.

@onready var cell: ItemCell = $Cell

var _offered: Item = null
var _spinning: bool = false
var _bump_tween: Tween


func _exit_tree() -> void:
  if _bump_tween and _bump_tween.is_valid():
    _bump_tween.kill()
  _bump_tween = null
  _offered = null


## Bind the offered item, relic or potion (each offered as the Item built from its definition). Call
## after the option is in the tree.
func setup(offered: Item) -> void:
  _offered = offered
  _spinning = false
  cell.show_cooldown = false   # a reward is not in a fight, so no cooldown fill covers the icon
  cell.setup(offered)


## The live Item this option offers (a relic or potion is offered as the Item built from its def) —
## the tooltip reads it. Null while the option is spinning.
func item() -> Item:
  return cell.item


## Hide the good until `land`; `show_face` puts up the icons shown meanwhile.
func start_spin() -> void:
  _spinning = true


func is_spinning() -> bool:
  return _spinning


## Show `texture` with no good behind it, as one turn of the spin.
func show_face(texture: Texture2D) -> void:
  cell.show_picture(texture)


## Show the offered good again, with the cell growing to `bump` times its size and back over
## `bump_time` seconds. Does nothing when the option is not spinning.
func land(bump: float, bump_time: float) -> void:
  if not _spinning:
    return
  _spinning = false
  cell.setup(_offered)
  if _bump_tween and _bump_tween.is_valid():
    _bump_tween.kill()
  cell.offset_transform_enabled = true
  cell.offset_transform_pivot_ratio = Vector2(0.5, 0.5)
  cell.offset_transform_scale = Vector2.ONE * bump
  _bump_tween = create_tween()
  _bump_tween.tween_property(cell, 'offset_transform_scale', Vector2.ONE, bump_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
