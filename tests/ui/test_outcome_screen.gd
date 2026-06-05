extends GutTest
## Phase 4 Step 8 — the run-end screen emits the two run-lifecycle intents: New Run
## starts a fresh run; Return to Title goes back to Title (emitting the transition so
## the presentation swaps screens).


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  TestCleanup.reset_all_managers()


func test_new_run_button_starts_a_run() -> void:
  var screen: OutcomeScreen = preload('res://src/scenes/screens/outcome_screen.tscn').instantiate()
  add_child(screen)
  screen.setup(true)
  screen._on_new_run()
  assert_eq(Game.phase, GameManagerAutoload.Phase.RUN, 'New Run starts a fresh run')
  assert_not_null(Game.run, 'a live run exists')
  screen.free()


func test_title_button_returns_to_title_with_a_signal() -> void:
  var screen: OutcomeScreen = preload('res://src/scenes/screens/outcome_screen.tscn').instantiate()
  add_child(screen)
  screen.setup(false)
  watch_signals(Game)
  screen._on_title()
  assert_eq(Game.phase, GameManagerAutoload.Phase.TITLE, 'Return to Title goes back to Title')
  assert_signal_emitted(Game, 'phase_changed', 'the transition is emitted so the screen swaps')
  screen.free()
