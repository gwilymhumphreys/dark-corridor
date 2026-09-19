class_name CombatSummary
extends Control
## The combat report (docs/systems/combat_log.md): the player's per-item damage report + the
## ordered event-log timeline of the last finished fight, read from its CombatLog. The run
## screen raises and dismisses it from the Report button on the HUD; Close emits
## `close_pressed`. It reads the log and writes no game state.

signal close_pressed

@onready var _rows: GridContainer = $Panel/Margin/Body/Columns/Report/RowsScroll/Rows
@onready var _status_section: VBoxContainer = $Panel/Margin/Body/Columns/Report/StatusDamage
@onready var _status_rows: GridContainer = $Panel/Margin/Body/Columns/Report/StatusDamage/StatusRows
@onready var _events: VBoxContainer = $Panel/Margin/Body/Columns/Log/EventsScroll/Events
@onready var _close: Button = $Panel/Margin/Body/Footer/CloseButton


func _ready() -> void:
  _close.pressed.connect(_on_close)


## Populate from the fight's log. Call after the screen is in the tree.
func setup(log: CombatLog) -> void:
  if log == null:
    return
  _fill_report(log)
  _fill_status_damage(log)
  _fill_log(log)


# The player per-item contribution: Item · Fires · Damage · Shield · Healing. Damage is
# DIRECT hits only — status (DoT / cash-out) damage is bucketed by status (see
# _fill_status_damage), not credited to the applier. The header cells are static in the
# .tscn (auto-translated); data cells are appended after them.
func _fill_report(log: CombatLog) -> void:
  for row in log.summary(CombatLog.Side.PLAYER):
    _add_cell(_rows, tr(row['name']), false)
    _add_cell(_rows, '%d' % int(row['fires']), true)
    _add_cell(_rows, '%.0f' % float(row['damage']), true)
    _add_cell(_rows, '%.0f' % float(row['shield']), true)
    _add_cell(_rows, '%.0f' % float(row['healing']), true)


# The player's status damage, bucketed by status (Poison / Bleed / …) — the DoT / cash-out
# output the per-item table no longer carries. Hidden when no status dealt damage.
func _fill_status_damage(log: CombatLog) -> void:
  var rows: Array = log.status_damage(CombatLog.Side.PLAYER)
  if rows.is_empty():
    _status_section.hide()
    return
  for row in rows:
    _add_cell(_status_rows, tr(row['name']), false)
    _add_cell(_status_rows, '%.0f' % float(row['damage']), true)


func _add_cell(grid: GridContainer, text: String, numeric: bool) -> void:
  var label := Label.new()
  label.text = text
  if numeric:
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  grid.add_child(label)


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
  # Damage/heal/shield/status always have an actor target; the player actor carries no
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
    'shield':
      return tr('{0}  {1} → {2}  +{3} shield').format([t, src, tgt, amount])
    'status':
      return tr('{0}  {1} → {2}  {3}').format([t, src, tgt, tr(ev['data'])])
    'charge':
      return tr('{0}  {1} → {2}  {3}s').format([t, src, tgt, '%+.1f' % float(ev['amount'])])
    'throw':
      return tr('{0}  threw {1}').format([t, tr(ev['data'])])
  return t


func _on_close() -> void:
  close_pressed.emit()
