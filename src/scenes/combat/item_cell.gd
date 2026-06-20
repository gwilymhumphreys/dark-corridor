class_name ItemCell
extends Control
## One board item in the framed combat view (docs/systems/ui_layout.md): a themed item-slot
## frame (PanelSlot) holding a placeholder icon, a row of effect-coloured value pills straddling
## the top edge (one per value-bearing effect), a cooldown wipe (a horizontal line rising from the
## bottom edge to the top as the item recharges), and a scale-punch recoil when it fires. Structure
## is authored in item_cell.tscn; this binds the data, builds the pills, and draws the wipe + recoil.
## Reads the live Item; writes nothing. No alpha.
##
## The recoil is a pure function of the COMBAT clock (render_time − fire_time, the
## vfx_driver.md rule) — under hover slow-mo it glides with everything else, and pause
## freezes it. The Timekeeper is RefCounted, so holding it here outlives the fight's
## teardown safely.

const CELL_SIZE := Vector2(120, 120)   # the default (the player's prominent board); HUDs shrink it
const VALUE_PILL: PackedScene = preload('res://src/scenes/combat/value_pill.tscn')
const RECOIL_SCALE: float = 1.3
const RECOIL_DURATION: float = 0.18    # combat-clock seconds

var item: Item
var cell_size: Vector2 = CELL_SIZE

@onready var _pills: HBoxContainer = $Pills

var _timekeeper: Timekeeper = null     # the fight's clock; null = no recoil (sandbox/tests)
var _last_progress: float = 0.0        # a fresh fight starts at 0 — no spurious recoil on bind
var _recoil_start: float = -1.0        # render_time at the last fire; -1 = idle


func _ready() -> void:
  pivot_offset = cell_size * 0.5   # recoil / hover scale from the centre


## Shrink the cell (the enemy HUDs / ally slots use smaller cells than the player's board).
## Call after the cell is in the tree, before setup() — setup() sizes the pills to `cell_size`.
func set_cell_size(px: float) -> void:
  cell_size = Vector2(px, px)
  custom_minimum_size = cell_size
  size = cell_size
  pivot_offset = cell_size * 0.5


func _exit_tree() -> void:
  # CLAUDE.md runtime cleanup: drop the live refs on free.
  item = null
  _timekeeper = null


## Bind to an item. Call after the cell is in the tree (so the node refs exist).
## `timekeeper` is the fight's clock for the recoil; null (default) disables it.
func setup(target_item: Item, timekeeper: Timekeeper = null) -> void:
  item = target_item
  _timekeeper = timekeeper
  _build_pills()
  queue_redraw()


## A pill per value-bearing effect (damage / heal / status amount), tinted by the effect's family
## colour, in a centred row straddling the top edge (vertical centre on the frame's top border).
func _build_pills() -> void:
  for child: Node in _pills.get_children():
    child.queue_free()
  if item == null:
    return
  var ratio: float = cell_size.x / CELL_SIZE.x
  _pills.add_theme_constant_override('separation', int(round(4.0 * ratio)))  # scales with the cell
  for effect: ItemEffect in item.def.effects:
    if not _effect_has_value(effect):
      continue
    var pill: ValuePill = VALUE_PILL.instantiate()
    _pills.add_child(pill)
    pill.setup(TooltipContent.fmt(item.display_value(effect)), effect.color, ratio)
  var pills_size: Vector2 = _pills.get_combined_minimum_size()
  _pills.size = pills_size
  _pills.position = Vector2((cell_size.x - pills_size.x) * 0.5, -pills_size.y * 0.5)


func _effect_has_value(effect: ItemEffect) -> bool:
  match effect.kind:
    Delivery.Kind.DAMAGE, Delivery.Kind.HEAL, Delivery.Kind.APPLY_STATUS:
      return true
  return false


func _process(_delta: float) -> void:
  if item == null:
    return
  var progress: float = item.cooldown.progress()
  if progress < _last_progress - 0.2:   # cooldown reset -> it just fired
    _recoil_start = _timekeeper.render_time() if _timekeeper != null else -1.0
  _last_progress = progress
  _update_recoil()
  queue_redraw()


## Scale = f(render_time − fire_time): the same stateless pattern as the projectiles,
## so the recoil honours slow-mo and pause instead of popping at wall speed.
func _update_recoil() -> void:
  if _recoil_start < 0.0 or _timekeeper == null:
    scale = Vector2.ONE
    return
  var since: float = _timekeeper.render_time() - _recoil_start
  if since >= RECOIL_DURATION:
    scale = Vector2.ONE
    _recoil_start = -1.0
    return
  var s: float = Tween.interpolate_value(
      RECOIL_SCALE, 1.0 - RECOIL_SCALE, since, RECOIL_DURATION, Tween.TRANS_BACK, Tween.EASE_OUT)
  scale = Vector2(s, s)


func _draw() -> void:
  # The PanelSlot frame (item_cell.tscn) supplies the border; this only adds the cooldown wipe:
  # a horizontal line that rises from the bottom edge (just fired) to the top edge (ready).
  if item == null:
    return
  var progress: float = item.cooldown.progress()
  if progress < 1.0:
    var y: float = cell_size.y * (1.0 - progress)
    draw_line(Vector2(0.0, y), Vector2(cell_size.x, y), Colours.COOLDOWN_RING, Consts.COOLDOWN_RING_WIDTH)


## Centre of the cell in global (screen) space — the VFX wall reads it. With a centre
## pivot, scaling keeps the visual centre fixed, so scale plays no part here.
func cell_centre() -> Vector2:
  return global_position + cell_size * 0.5
