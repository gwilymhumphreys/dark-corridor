class_name TooltipCluster
extends CanvasLayer
## The tooltip cluster (docs/systems/tooltips.md): a main item panel plus a stacked column of keyword
## cards, shown/hidden as a unit beside the hovered board item. Lives on its own CanvasLayer
## (layer 50, below the pause menu's 100). Owned by the combat view, which feeds it a target every
## frame via update_target; the cluster runs the item↔cluster hide-bridge, positions + clamps the
## cluster, and rebuilds content when the target item changes. Opaque (no alpha) — a scale reveal.
##
## Coordinate space: positions with the cell's global rect and clamps to the viewport rect, assuming
## the run-screen UI has NO custom canvas transform (it has no camera). If a transform is ever added,
## convert via get_viewport().get_canvas_transform() (a-machine's BuildingTooltip precedent).

const TOOLTIP_PANEL: PackedScene = preload('res://src/scenes/ui/tooltip/tooltip_panel.tscn')
const KEYWORD_CARD: PackedScene = preload('res://src/scenes/ui/tooltip/keyword_card.tscn')

const GAP: float = 16.0          # item↔cluster and panel↔column gap
const MARGIN: float = 12.0       # screen-edge clamp
const HIDE_DELAY: float = 0.12   # the mouse-bridge hide-timer (seconds)
const REVEAL_SCALE: float = 0.92

enum Side { LEFT, RIGHT }

var _body: Control = null
var _panel: TooltipPanel = null
var _column: VBoxContainer = null

var _current_item: Item = null
var _side: int = Side.LEFT
var _anchor_rect: Rect2 = Rect2()    # the hovered cell's global rect (re-read each frame; cells move)
var _cluster_rect: Rect2 = Rect2()   # the placed, UNSCALED cluster rect — the bridge reads this
var _hide_timer: float = -1.0
var _pending_show: bool = false      # rebuilt this frame; reveal next frame once wrapped sizes settle
var _reveal: Tween = null


func _ready() -> void:
  _body = $Body
  _panel = TOOLTIP_PANEL.instantiate()
  _body.add_child(_panel)
  _column = VBoxContainer.new()
  _column.add_theme_constant_override('separation', 8)
  _column.mouse_filter = Control.MOUSE_FILTER_IGNORE
  _body.add_child(_column)
  visible = false


func _exit_tree() -> void:
  # CLAUDE.md runtime cleanup: drop the live Item ref + stop the tween on free (the Actor↔Item
  # cycle is broken at dissolve() — the cluster must not retain an Item across teardown).
  _current_item = null
  if _reveal != null and _reveal.is_valid():
    _reveal.kill()


## Fed every frame by the view. `target` is {} (no cell under the cursor) or {item, rect, side}.
## Drives show / retarget / the hide-bridge. `mouse` is the global cursor (the bridge hold test).
func update_target(target: Dictionary, mouse: Vector2) -> void:
  if not target.is_empty() and is_instance_valid(target['item']):
    var item: Item = target['item']
    _anchor_rect = target['rect']
    _side = target.get('side', Side.LEFT)
    if item != _current_item:
      # New item: rebuild + lock the fixed panel width now, but DON'T show this frame. The
      # HFlowContainer / RichTextLabel wrapped HEIGHT is only correct after one layout pass
      # (measuring the same frame reports a too-tall size), so reveal next frame at the settled
      # size — avoids a one-frame position jump.
      _current_item = item
      _rebuild(item)
      _panel.reset_size()
      _column.reset_size()
      _pending_show = true
      visible = false
    elif _pending_show:
      _pending_show = false
      _reposition(_side)   # sizes have settled → final placement, then reveal
      _play_reveal()
      visible = true
    else:
      _reposition(_side)   # same item — track a moving cell (enemy HUDs reposition every frame)
    _hide_timer = -1.0
    return
  # No cell under the cursor: hold while the mouse is over the cell-or-cluster span (the bridge,
  # so the cursor can travel onto the panel to hover chips); otherwise tick the hide-timer.
  if not visible:
    _current_item = null   # don't retain an Item ref while hidden (e.g. mouse left mid-reveal-defer)
    _pending_show = false
    return
  if _anchor_rect.merge(_cluster_rect).has_point(mouse):
    _hide_timer = -1.0
    return
  if _hide_timer < 0.0:
    _hide_timer = HIDE_DELAY
  _hide_timer -= get_process_delta_time()
  if _hide_timer <= 0.0:
    hide_cluster()


func hide_cluster() -> void:
  visible = false
  _current_item = null
  _pending_show = false
  _hide_timer = -1.0


func _rebuild(item: Item) -> void:
  var content: Dictionary = TooltipContent.new().build(item)
  _panel.set_content(content)
  for child in _column.get_children():
    _column.remove_child(child)
    child.queue_free()
  var keyword_ids: Array = content['keyword_ids']
  for id: String in keyword_ids:
    var wrap := PanelContainer.new()
    wrap.theme_type_variation = 'PanelFramed'
    var card: KeywordCard = KEYWORD_CARD.instantiate()
    wrap.add_child(card)
    _column.add_child(wrap)
    card.setup(id)
  _column.visible = not keyword_ids.is_empty()


## Default side first (LEFT — the player board is the right-edge column), screen-half flip as the
## fallback when the cluster won't fit, then clamp into the viewport.
func _reposition(side: int) -> void:
  _panel.reset_size()
  _column.reset_size()
  var screen: Vector2 = get_viewport().get_visible_rect().size
  var main_size: Vector2 = _panel.get_combined_minimum_size()
  var col_size: Vector2 = _column.get_combined_minimum_size() if _column.visible else Vector2.ZERO
  var col_span: float = (GAP + col_size.x) if _column.visible else 0.0
  var cluster_w: float = main_size.x + col_span
  var cluster_h: float = maxf(main_size.y, col_size.y)

  var room_left: float = _anchor_rect.position.x
  var room_right: float = screen.x - _anchor_rect.end.x
  var needed: float = cluster_w + GAP + MARGIN
  var place_left: bool
  if side == Side.LEFT:
    place_left = room_left >= needed or room_left >= room_right
  else:
    place_left = not (room_right >= needed or room_right >= room_left)

  var x: float = (_anchor_rect.position.x - GAP - cluster_w) if place_left else (_anchor_rect.end.x + GAP)
  x = clampf(x, MARGIN, maxf(MARGIN, screen.x - cluster_w - MARGIN))
  var y: float = _anchor_rect.get_center().y - cluster_h * 0.5
  y = clampf(y, MARGIN, maxf(MARGIN, screen.y - cluster_h - MARGIN))

  _body.position = Vector2(x, y)
  _body.size = Vector2(cluster_w, cluster_h)
  _cluster_rect = Rect2(_body.position, _body.size)

  # Main panel nearest the item; keyword column on the outer side.
  if place_left:   # item is to the RIGHT of the cluster
    _column.position = Vector2.ZERO
    _panel.position = Vector2(col_span, 0.0)
  else:            # item is to the LEFT of the cluster
    _panel.position = Vector2.ZERO
    _column.position = Vector2(main_size.x + GAP, 0.0)


func _play_reveal() -> void:
  _body.pivot_offset = _body.size * 0.5
  _body.scale = Vector2(REVEAL_SCALE, REVEAL_SCALE)
  if _reveal != null and _reveal.is_valid():
    _reveal.kill()
  _reveal = create_tween()
  _reveal.tween_property(_body, 'scale', Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
