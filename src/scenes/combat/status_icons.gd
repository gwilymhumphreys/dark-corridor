class_name StatusIcons
extends HBoxContainer
## The status icons for one actor (docs/systems/run_screen.md), beside its name and health bar: one
## StatusIcon (the status's icon on its colour, its stacks in a pill) per active OUTSIDE-set status.
## The mechanic statuses are shown by the health bar instead. The icons sit in columns `rows` tall
## (status_column.tscn), filling each column top to bottom, then the next column to the right. With
## one row (the icons under the health bar), the row leaves room below the icons for their pills.
## Refreshed each frame since statuses accrue / expire during combat. A new status's icon pops in and
## an icon whose stacks rise bumps (PopAnimation). Reads the actor; writes nothing.

const STATUS_ICON: PackedScene = preload('res://src/scenes/combat/status_icon.tscn')
const STATUS_COLUMN: PackedScene = preload('res://src/scenes/combat/status_column.tscn')
const ROWS: int = 2
const PILL_HANG: float = 14.0   # the half of an icon's pill that hangs below it
const ICON_SIZE: float = 32.0   # status_icon.tscn's minimum size, until set_icon_size
const COLUMN_SEPARATION: float = 14.0   # the separation in status_column.tscn, and between columns in status_icons.tscn

var actor: Actor = null
## Icons per column: ROWS beside the health bar, 1 under it (character_panel.tscn `StatusesUnder`).
@export var rows: int = ROWS
## Keep the height of a full column even with no icons, so the first status does not make the panel
## taller (the player's panel, CharacterPanel.fixed_size).
var reserve_height: bool = false:
  set(value):
    reserve_height = value
    _fit_height()

var _icons: Array[StatusIcon] = []
var _icon_px: float = ICON_SIZE
var _counts: Dictionary = {}   # status id -> the stacks shown last frame, to spot a new status or new stacks


## Make every icon `px` square (the `status_size` print setting). Rebuilds the icons when it changes.
func set_icon_size(px: float) -> void:
  if is_equal_approx(px, _icon_px):
    return
  _icon_px = px
  _rebuild(_icons.size())
  refresh()


func _process(_delta: float) -> void:
  refresh()


func refresh() -> void:
  var outside: Array[StatusEffect] = []
  if actor != null:
    for s in actor.statuses:
      if not MechanicRegistry.has(s.id):
        outside.append(s)
  if outside.size() != _icons.size():
    _rebuild(outside.size())
  var counts: Dictionary = {}
  for i in outside.size():
    var shown: StatusEffect = outside[i]
    _icons[i].show_status(shown)
    counts[shown.id] = shown.count
    if not _counts.has(shown.id):
      PopAnimation.pop_in(_icons[i])
    elif shown.count > int(_counts[shown.id]):
      PopAnimation.bump(_icons[i])
  _counts = counts


## How many status icons are shown.
func icon_count() -> int:
  return _icons.size()


## The centre, in global coordinates, of the icon for the status `id`, or of the slot a new icon for
## it will take when that status is not shown yet: the next place in the columns, filled top to
## bottom. A row that sits at the bottom of its space (the grid beside the bar) grows upward as it
## gains rows, so the slot allows for that.
func slot_centre(id: String) -> Vector2:
  for icon in _icons:
    if icon.status != null and icon.status.id == id:
      return icon.get_global_rect().get_center()
  var index: int = _icons.size()
  var column: int = floori(float(index) / float(rows))
  var row: int = index % rows
  var step: float = _icon_px + COLUMN_SEPARATION
  var shown_rows: int = rows if reserve_height else mini(index + 1, rows)
  var height: float = shown_rows * _icon_px + (shown_rows - 1) * COLUMN_SEPARATION
  var top: float = global_position.y
  if size_flags_vertical & Control.SIZE_SHRINK_END:
    top = global_position.y + size.y - height
  return Vector2(global_position.x + column * step + _icon_px * 0.5, top + row * step + _icon_px * 0.5)


## The icon under `point` (global), or null.
func icon_at(point: Vector2) -> StatusIcon:
  if not is_visible_in_tree():
    return null
  for icon in _icons:
    if icon.get_global_rect().has_point(point):
      return icon
  return null


## Lay out `count` icons in columns of `rows`. Only runs when the number of statuses changes.
func _rebuild(count: int) -> void:
  for old_column: Node in get_children():
    # Deferred frees for nodes (CLAUDE.md) — removed from the tree now so the new columns take its place.
    remove_child(old_column)
    old_column.queue_free()
  _icons.clear()
  var column: Node = null
  for i in count:
    if i % rows == 0:
      column = STATUS_COLUMN.instantiate()
      column.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
      add_child(column)
    var icon: StatusIcon = STATUS_ICON.instantiate()
    icon.custom_minimum_size = Vector2(_icon_px, _icon_px)
    column.add_child(icon)
    _icons.append(icon)
  _fit_height()


# Under the health bar, the pills on the icons' bottom corners need room below the row. With
# reserve_height, the row or grid keeps its full height when it has no icons.
func _fit_height() -> void:
  var shown: bool = reserve_height or not _icons.is_empty()
  if rows == 1:
    custom_minimum_size.y = _icon_px + PILL_HANG if shown else 0.0
  else:
    custom_minimum_size.y = rows * _icon_px + (rows - 1) * COLUMN_SEPARATION if reserve_height else 0.0


func _exit_tree() -> void:
  _icons.clear()
  _counts.clear()
  actor = null
