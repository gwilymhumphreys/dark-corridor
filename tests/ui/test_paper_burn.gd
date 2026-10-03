extends GutTest
## PaperBurn: a burn clips its target's children to the hole and puts the target back when it ends.

var _parent: Control = null
var _target: Control = null
var _saved_duration: float = 0.0
var _saved_palette: bool = true


func before_each() -> void:
  TestCleanup.reset_all_managers()
  _saved_duration = PrintLook.print_setting('paper_burn_duration')
  _saved_palette = PrintLook.print_setting('paper_burn_palette')
  _parent = Control.new()
  add_child_autofree(_parent)
  _target = Control.new()
  _target.size = Vector2(80.0, 80.0)
  _target.add_child(ColorRect.new())
  _parent.add_child(_target)


func after_each() -> void:
  PrintLook.set_print_value('paper_burn_duration', _saved_duration)
  PrintLook.set_print_value('paper_burn_palette', _saved_palette)
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


func test_a_backwards_burn_shows_the_target_and_runs_from_nothing_to_whole() -> void:
  PrintLook.set_print_value('paper_burn_duration', 0.2)
  _target.modulate.a = 0.0
  var burn: PaperBurn = PaperBurn.burn(_target, true)
  assert_eq(_target.modulate.a, 1.0, 'the target is shown while it appears')
  assert_eq(burn.progress, 1.0, 'it starts with nothing left')
  burn._process(0.1)
  assert_almost_eq(burn.progress, 0.5, 0.001, 'half way back at half the duration')
  watch_signals(burn)
  burn._process(0.1)
  assert_signal_emitted(burn, 'finished', 'done at the end of the duration')
  assert_eq(_target.modulate.a, 1.0, 'the target stays shown at the end')
  assert_null(_target.material, 'the target has its own material back')


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


func test_the_bands_take_the_effects_palette() -> void:
  PrintLook.set_print_value('paper_burn_palette', true)
  PaperBurn.burn(_target)
  var burn_material: ShaderMaterial = _target.material as ShaderMaterial
  assert_true(burn_material.get_shader_parameter('snap'), 'the bands are snapped')
  assert_eq(burn_material.get_shader_parameter('colour_count'), InterfaceLook.effects_material.get_shader_parameter('colour_count'), 'the same palette as the combat effects')


func test_the_palette_switch_turns_the_snap_off() -> void:
  PrintLook.set_print_value('paper_burn_palette', false)
  PaperBurn.burn(_target)
  assert_false((_target.material as ShaderMaterial).get_shader_parameter('snap'), 'the bands keep their smooth colours')
