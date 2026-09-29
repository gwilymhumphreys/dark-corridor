extends GutTest
## PaperBurn: a burn clips its target's children to the hole and puts the target back when it ends.

var _parent: Control = null
var _target: Control = null


func before_each() -> void:
  TestCleanup.reset_all_managers()
  _parent = Control.new()
  add_child_autofree(_parent)
  _target = Control.new()
  _target.size = Vector2(80.0, 80.0)
  _target.add_child(ColorRect.new())
  _parent.add_child(_target)


func after_each() -> void:
  TestCleanup.reset_all_managers()


func test_a_burn_clips_the_target_while_it_runs() -> void:
  PaperBurn.burn(_target)
  assert_eq(_target.clip_children, CanvasItem.CLIP_CHILDREN_ONLY, 'the target clips its children to the burn')
  assert_true(_target.material is ShaderMaterial, 'the target draws through the burn shader')


func test_the_end_puts_the_target_back_and_hides_it() -> void:
  var burn: PaperBurn = PaperBurn.burn(_target)
  watch_signals(burn)
  burn.finish()
  assert_signal_emitted(burn, 'finished')
  assert_eq(_target.clip_children, CanvasItem.CLIP_CHILDREN_DISABLED, 'the clip is switched off again')
  assert_null(_target.material, 'the target has its own material back')
  assert_eq(_target.modulate.a, 0.0, 'the target is hidden but keeps its place')


func test_the_target_is_left_shown_when_asked() -> void:
  var burn: PaperBurn = PaperBurn.burn(_target)
  burn.hide_when_done = false
  burn.finish()
  assert_eq(_target.modulate.a, 1.0, 'the preview scene repeats burns on the same target')


func test_the_burn_runs_to_the_end_over_its_duration() -> void:
  PrintLook.set_print_value('paper_burn_duration', 0.2)
  var burn: PaperBurn = PaperBurn.burn(_target)
  watch_signals(burn)
  burn._process(0.1)
  assert_almost_eq(burn.progress, 0.5, 0.001, 'half way through at half the duration')
  burn._process(0.1)
  assert_signal_emitted(burn, 'finished', 'done at the end of the duration')


func test_hold_stops_it_at_a_progress() -> void:
  var burn: PaperBurn = PaperBurn.burn(_target)
  burn.hold(0.4)
  burn._process(10.0)
  assert_eq(burn.progress, 0.4, 'a held burn does not move')


func test_removing_the_burn_early_puts_the_target_back() -> void:
  var burn: PaperBurn = PaperBurn.burn(_target)
  burn.free()
  assert_eq(_target.clip_children, CanvasItem.CLIP_CHILDREN_DISABLED, 'the clip is switched off')
  assert_null(_target.material, 'the material is put back')
  assert_eq(_target.modulate.a, 1.0, 'an unfinished burn does not hide the target')
