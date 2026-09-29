extends Control
## Dev scene for judging the paper burn effect (`PaperBurn`, docs/systems/paper_burn.md) without
## winning fights. The top two rows are tokens held partway through a burn, at the map token size and
## the item token size, for screenshots. The bottom row burns a map token, an item token and a wide
## panel over and over. The `paper_burn_*` settings on the F7 tab are read again each time the burns
## start, so they can be tuned while watching. Run it directly:
##   <godot> --path . res://src/debug/scenes/paper_burn_preview.tscn

const HELD: Array[float] = [0.0, 0.15, 0.3, 0.45, 0.6, 0.75, 0.9]
const ROW_TOPS: Array[float] = [140.0, 420.0]
const LIVE_TOP: float = 820.0
const LEFT: float = 200.0
const STEP: float = 300.0
const PAUSE: float = 0.8          # seconds between the end of a live burn and the next
const MAP_ICON: String = 'res://assets/icons/map/elite.png'
const ITEM_ID: String = 'dagger'

var _held_cells: Array[ItemCell] = []
var _live_targets: Array[Control] = []
var _live_burns: Array[PaperBurn] = []
var _restart_in: float = 0.0


func _ready() -> void:
  var item_icon: Texture2D = load(ItemCatalog.get_def(ITEM_ID).icon) as Texture2D
  var map_icon: Texture2D = load(MAP_ICON) as Texture2D
  var map_size: float = PrintLook.print_setting('medium_token_size')
  for row in ROW_TOPS.size():
    var cell_px: float = map_size if row == 0 else ItemCell.CELL_SIZE.x
    for i in HELD.size():
      var cell: ItemCell = _make_cell(cell_px, map_icon if row == 0 else item_icon, row == 0)
      cell.position = Vector2(LEFT + STEP * float(i), ROW_TOPS[row]) - Vector2(cell_px, cell_px) * 0.5
      _held_cells.append(cell)
  var live_map: ItemCell = _make_cell(map_size, map_icon, true)
  live_map.position = Vector2(LEFT + 100.0, LIVE_TOP)
  var live_item: ItemCell = _make_cell(ItemCell.CELL_SIZE.x, item_icon, false)
  live_item.position = Vector2(LEFT + 500.0, LIVE_TOP)
  # A panel burns inside a plain Control that holds it, as an item cell holds its frame: the node that
  # burns should draw nothing itself (docs/systems/paper_burn.md).
  var holder: Control = Control.new()
  holder.size = Vector2(520.0, 260.0)
  holder.position = Vector2(LEFT + 900.0, LIVE_TOP - 40.0)
  add_child(holder)
  var panel: PanelContainer = PanelContainer.new()
  panel.theme_type_variation = &'PanelTokenWide'
  panel.size = holder.size
  var label: Label = Label.new()
  label.theme_type_variation = &'LabelLarge'
  label.text = 'A wide panel burning'
  label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
  panel.add_child(label)
  holder.add_child(panel)
  _live_targets = [live_map, live_item, holder]
  _start()


func _process(delta: float) -> void:
  if _restart_in > 0.0:
    _restart_in -= delta
    if _restart_in <= 0.0:
      _start()
  queue_redraw()


func _draw() -> void:
  draw_rect(Rect2(Vector2.ZERO, size), Colours.UI_BACKGROUND)
  var font: Font = ThemeDB.fallback_font
  for i in HELD.size():
    draw_string(font, Vector2(LEFT + STEP * float(i) - 30.0, ROW_TOPS[1] + 110.0), '%.2f' % HELD[i], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24, Colours.UI_TEXT_DIM)
  draw_string(font, Vector2(24.0, LIVE_TOP - 80.0), 'Live (repeats; F7 Paper burn settings apply on each repeat)', HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24, Colours.UI_TEXT_DIM)


func _make_cell(cell_px: float, icon: Texture2D, tinted: bool) -> ItemCell:
  var cell: ItemCell = preload('res://src/scenes/combat/item_cell.tscn').instantiate()
  add_child(cell)
  cell.set_cell_size(cell_px)
  cell.show_picture(icon)
  if tinted:
    cell.tint_picture(Colours.UI_TEXT_DIM, PrintLook.print_setting('map_icons_as_pictures'))
  cell.set_askew(PrintLook.print_setting('token_tilt'), PrintLook.print_setting('token_shift'))
  return cell


# Burn every held cell again at its progress and start the live burns, all with the current settings.
func _start() -> void:
  for cell: ItemCell in _held_cells:
    for child: Node in cell.get_children():
      if child is PaperBurn:
        child.free()
  for i in _held_cells.size():
    PaperBurn.burn(_held_cells[i]).hold(HELD[i % HELD.size()])
  _live_burns.clear()
  for target: Control in _live_targets:
    target.modulate.a = 1.0
    var live: PaperBurn = PaperBurn.burn(target)
    live.finished.connect(_on_live_finished)
    _live_burns.append(live)


func _on_live_finished() -> void:
  _restart_in = PAUSE + 0.05   # the last of the three to finish sets the pause
