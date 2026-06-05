extends GutTest
## Phase 4 Step 6 — the map strip reads the run's beats and tracks the position marker.


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  TestCleanup.reset_all_managers()


func test_map_strip_reads_beats_and_tracks_position() -> void:
  var strip: MapStrip = preload('res://src/scenes/screens/map_strip.tscn').instantiate()
  add_child(strip)
  strip.setup(RunManager.MAP, 0)
  assert_eq(strip._types.size(), RunManager.MAP.size(), 'one node per beat')
  assert_eq(strip._position, 0, 'starts at the first beat')
  strip.mark_position(2)
  assert_eq(strip._position, 2, 'the marker tracks the position')
  strip.free()
