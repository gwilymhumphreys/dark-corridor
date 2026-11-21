class_name RewardOption
extends Button
## One option in the reward overlay (docs/systems/draft.md): a button wrapping the same `ItemCell`
## the board uses, so a reward answers the pointer like every other control the player picks — the
## border on hover, the press squash, the release pulse and the click sound of `UIJuice`
## (docs/systems/control_feedback.md). The button itself draws nothing (`ButtonBare`); the juice
## draws the highlight on the cell's frame. While a `RewardSpin` spins it, the cell shows other item
## icons and no good, so it has no tooltip, until `land`: in the reel style a strip of icons scrolls
## through the frame (`RewardReel`, one inside the frame and one behind the cell for the faces above
## and below it), in the flicker style the icon changes in place. Reads the Item it is handed; writes
## nothing.

## Emitted when a spin starts hiding the good, and when the good lands and shows again.
signal spin_started()
signal landed()

@onready var cell: ItemCell = $Cell
@onready var _reel: RewardReel = $Cell/Frame/Reel
@onready var _reel_behind: RewardReel = $ReelBehind

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


## Hide the good until `land`; `show_face` or `show_reel` puts up the icons shown meanwhile.
func start_spin() -> void:
  _spinning = true
  if _bump_tween and _bump_tween.is_valid():
    _bump_tween.kill()
  cell.offset_transform_scale = Vector2.ONE
  cell.show_picture(null)
  spin_started.emit()


## The icon of the offered good, which a spin lands on, or null when it has none.
func offered_icon() -> Texture2D:
  if _offered == null or _offered.def.icon == '':
    return null
  return load(_offered.def.icon) as Texture2D


func is_spinning() -> bool:
  return _spinning


## Show `texture` with no good behind it, as one turn of the spin.
func show_face(texture: Texture2D) -> void:
  cell.show_picture(texture)


## Show the reel: `strip` with index `strip_position` at the centre of the frame. The reel behind the
## cell is as tall as the `reward_spin_window` print setting and hidden when that is 1.
func show_reel(strip: Array[Texture2D], strip_position: float) -> void:
  _reel.show_strip(strip, strip_position)
  var window: float = PrintLook.print_setting('reward_spin_window')
  if window <= 1.001:
    _reel_behind.hide_strip()
    return
  var face: Rect2 = Rect2(cell.position + _reel.get_parent_control().position + _reel.position, _reel.size)
  _reel_behind.position = Vector2(face.position.x, face.get_center().y - face.size.y * window * 0.5)
  _reel_behind.size = Vector2(face.size.x, face.size.y * window)
  _reel_behind.show_strip(strip, strip_position, face.size.y)


## The reel inside the frame, for tests.
func reel() -> RewardReel:
  return _reel


## Show the offered good again, with the cell growing to `bump` times its size and back over
## `bump_time` seconds. Does nothing when the option is not spinning.
func land(bump: float, bump_time: float) -> void:
  if not _spinning:
    return
  _spinning = false
  _reel.hide_strip()
  _reel_behind.hide_strip()
  cell.setup(_offered)
  if _bump_tween and _bump_tween.is_valid():
    _bump_tween.kill()
  cell.offset_transform_enabled = true
  cell.offset_transform_pivot_ratio = Vector2(0.5, 0.5)
  cell.offset_transform_scale = Vector2.ONE * bump
  _bump_tween = create_tween()
  _bump_tween.tween_property(cell, 'offset_transform_scale', Vector2.ONE, bump_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
  landed.emit()
