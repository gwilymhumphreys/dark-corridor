extends GutTest
## Stage 3 — the event overlay: prose + one button per option, and clicking an option
## emits its index (the run screen forwards it to Encounter.pick_event_option).


var _encs: Array = []


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  for e in _encs:
    if is_instance_valid(e):
      e.free()
  _encs.clear()
  TestCleanup.reset_all_managers()


func _event() -> Encounter:
  var e := Encounter.new(EncounterCatalog.get_def(EncounterCatalog.Id.EVENT_SHRINE), Actor.new(100.0))
  _encs.append(e)
  return e


func test_overlay_shows_options_and_emits_the_pick() -> void:
  var overlay: EventOverlay = preload('res://src/scenes/screens/event_overlay.tscn').instantiate()
  add_child(overlay)
  overlay.setup(_event())
  assert_eq(overlay.get_node('Panel/Options').get_child_count(), 2, 'one button per option')
  watch_signals(overlay)
  var btn: Button = overlay.get_node('Panel/Options').get_child(1)
  btn.pressed.emit()
  assert_signal_emitted_with_parameters(overlay, 'option_picked', [1], 'clicking an option emits its index')
  overlay.free()
