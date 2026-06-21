class_name CombatSummary
extends Control
## The post-fight summary (docs/systems/combat_log.md): on a won fight (before the draft) it
## shows the player's per-item damage report + the ordered event-log timeline, read from the
## fight's CombatLog. It reads the log and emits `continue_pressed` — the run screen forwards
## that to the rest of the after-beat flow. Writes no game state.

signal continue_pressed

@onready var _rows: GridContainer = $Panel/Margin/Body/Columns/Report/RowsScroll/Rows
@onready var _events: VBoxContainer = $Panel/Margin/Body/Columns/Log/EventsScroll/Events
@onready var _continue: Button = $Panel/Margin/Body/Footer/ContinueButton


func _ready() -> void:
  _continue.pressed.connect(_on_continue)


## Populate from the fight's log. Call after the screen is in the tree.
func setup(log: CombatLog) -> void:
  if log == null:
    return
  _fill_report(log)
  _fill_log(log)


# The player per-item contribution: Item · Fires · Damage · Block · Healing. The header
# cells are static in the .tscn (auto-translated); data cells are appended after them.
func _fill_report(log: CombatLog) -> void:
  for row in log.summary(CombatLog.Side.PLAYER):
    _add_cell(tr(row['name']), false)
    _add_cell('%d' % int(row['fires']), true)
    _add_cell('%.0f' % float(row['damage']), true)
    _add_cell('%.0f' % float(row['block']), true)
    _add_cell('%.0f' % float(row['healing']), true)


func _add_cell(text: String, numeric: bool) -> void:
  var label := Label.new()
  label.text = text
  if numeric:
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  _rows.add_child(label)


# The ordered timeline — one line per event, with its sim-time stamp.
func _fill_log(log: CombatLog) -> void:
  for ev in log.events:
    var label := Label.new()
    label.text = _format_event(ev)
    _events.add_child(label)


# Dynamic formatted text → tr() (docs/systems/localization.md). Names are name_keys / status
# ids resolved with tr(); a missing source/target collapses gracefully.
func _format_event(ev: Dictionary) -> String:
  var t: String = '%.1fs' % float(ev['t'])
  var src: String = tr(ev['source']) if ev['source'] != '' else ''
  # Damage/heal/block/status always have an actor target; the player actor carries no
  # display_name, so an empty target there means the player → 'You'.
  var tgt: String = tr(ev['target']) if ev['target'] != '' else tr('You')
  var amount: String = '%.0f' % float(ev['amount'])
  match ev['type']:
    'fire':
      return tr('{0}  {1} fires').format([t, src])
    'damage':
      return tr('{0}  {1} → {2}  {3}').format([t, src, tgt, amount])
    'heal':
      return tr('{0}  {1} → {2}  +{3}').format([t, src, tgt, amount])
    'block':
      return tr('{0}  {1} → {2}  +{3} block').format([t, src, tgt, amount])
    'status':
      return tr('{0}  {1} → {2}  {3}').format([t, src, tgt, tr(ev['data'])])
    'throw':
      return tr('{0}  threw {1}').format([t, tr(ev['data'])])
  return t


func _on_continue() -> void:
  continue_pressed.emit()
