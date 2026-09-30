class_name ShieldDrawer
extends EffectDrawer
## The effect drawn where shield lands on a health bar (docs/systems/vfx_driver.md): the shield
## icon appears small, quickly grows and fades out. Each landing draws its own icon, so a burst of
## shield shows several at once.

const DURATION: float = 0.45     # render-time seconds the icon shows
const SIZE_START: float = 24.0   # the icon's width in pixels as it appears
const SIZE_END: float = 120.0    # the icon's width in pixels as it finishes fading

var _icon_path: String = ''
var _icon: Texture2D = null


func duration() -> float:
  return DURATION


func draw_effect(canvas: CanvasItem, delivery: Delivery, point: Vector2, age: float) -> void:
  var through: float = progress(age)
  if through < 0.0:
    return
  var icon: Texture2D = _shield_icon()
  if icon == null:
    return
  var grown: float = 1.0 - pow(1.0 - through, 3.0)   # fast at first, then slow
  # A glyph is a white shape tinted with the shield colour; any other icon keeps its own colours.
  var colour: Color = delivery.color if _icon_path.begins_with(KeywordIcon.GLYPH_DIR) else Color.WHITE
  canvas.draw_set_transform(point, 0.0, Vector2.ONE)
  draw_centred(canvas, icon, lerpf(SIZE_START, SIZE_END, grown), faded(colour, 1.0 - through * through))
  canvas.draw_set_transform_matrix(Transform2D.IDENTITY)


# The shield mechanic's current icon. Looked up each time so a change in the icon slots panel (F6)
# shows at once; the texture is only loaded again when the path changes.
func _shield_icon() -> Texture2D:
  var path: String = MechanicRegistry.get_mechanic(ShieldMechanic.ID).icon
  if path != _icon_path:
    _icon_path = path
    _icon = load(path) as Texture2D if path != '' else null
  return _icon
