extends GutTest
## Step 1 — the combat clock. The dial as a cadence (steps_due), determinism of
## sim_time, the base/override semantics, and the hang cap + backlog-drop.


func test_advance_steps_sim_time() -> void:
  var tk := Timekeeper.new()
  tk.advance()
  tk.advance()
  tk.advance()
  assert_almost_eq(tk.sim_time, 3.0 * Timekeeper.STEP, 0.00001, 'sim_time = steps * STEP')


func test_base_x1_one_step_per_real_step() -> void:
  var tk := Timekeeper.new()
  assert_eq(tk.steps_due(Timekeeper.STEP), 1, 'x1: one real STEP -> one sim-step')


func test_x2_runs_two_steps() -> void:
  var tk := Timekeeper.new()
  tk.set_base_scale(2.0)
  assert_eq(tk.steps_due(Timekeeper.STEP), 2, 'x2: two sim-steps per real STEP')


func test_pause_yields_no_steps() -> void:
  var tk := Timekeeper.new()
  tk.set_base_scale(Balance.TIMESCALE_PAUSE)
  assert_eq(tk.steps_due(Timekeeper.STEP * 10.0), 0, 'paused: no steps regardless of delta')


func test_slowmo_accrues_across_frames() -> void:
  var tk := Timekeeper.new()
  tk.set_base_scale(0.25)   # one sim-step every four frames
  assert_eq(tk.steps_due(Timekeeper.STEP), 0, 'frame 1: no step')
  assert_eq(tk.steps_due(Timekeeper.STEP), 0, 'frame 2: no step')
  assert_eq(tk.steps_due(Timekeeper.STEP), 0, 'frame 3: no step')
  assert_eq(tk.steps_due(Timekeeper.STEP), 1, 'frame 4: one sim-step')


func test_override_replaces_base_then_returns_to_base() -> void:
  var tk := Timekeeper.new()
  tk.set_base_scale(2.0)
  tk.set_override(Balance.TIMESCALE_SLOWMO)
  assert_almost_eq(tk.effective_scale(), Balance.TIMESCALE_SLOWMO, 0.00001, 'override replaces base while active')
  tk.clear_override()
  assert_almost_eq(tk.effective_scale(), 2.0, 0.00001, 'clearing returns to base, not x1')


func test_hang_caps_then_drops_backlog() -> void:
  var tk := Timekeeper.new()
  var n := tk.steps_due(Timekeeper.STEP * 1000.0)
  assert_eq(n, Timekeeper.MAX_STEPS, 'a hang runs at most MAX_STEPS')
  assert_almost_eq(tk._acc, 0.0, 0.00001, 'leftover backlog dropped — game-time slips, never spirals')


func test_render_time_is_sim_plus_accumulator_only() -> void:
  var tk := Timekeeper.new()
  tk.set_base_scale(0.25)
  tk.steps_due(Timekeeper.STEP)   # a sub-step of accrual, no whole step yet
  assert_almost_eq(tk.render_time(), tk.sim_time + tk._acc, 0.000001, 'render_time = sim_time + accumulator only (no frame-varying term)')
  assert_gt(tk.render_time(), tk.sim_time, 'the sub-step accumulator glides render_time between steps')
  assert_eq(tk.render_time(), tk.render_time(), 'render_time is stable when the sim is frozen — no oscillation when paused')
