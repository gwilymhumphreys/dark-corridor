class_name GameManagerAutoload
extends Node
## The session singleton (game_manager_prd) — autoload registered `Game`. Owns the
## phase machine, the run lifecycle (create / resume / end the RunManager), and the
## save-lifecycle calls (Save.read on resume, Save.clear on death/win). Holds only a
## reference to the live run (null between runs) — never per-run state itself.
##
## Phase 3 is the thin slice: Title → Run → (Death | Win). Meta / settings / pause
## are deferred. Headless: the autotest calls start_run() / resume_run() and drives
## Game.run's cycle; the Phase-4 run screen will be the other client of the same
## surface.

signal phase_changed(phase: int)

enum Phase { BOOT, TITLE, RUN, DEATH, WIN }

var phase: int = Phase.BOOT
var run: RunManager = null


func _ready() -> void:
  _set_phase(Phase.TITLE)


## Start a fresh, seeded run, replacing any existing one.
func start_run(seed_value: int) -> void:
  _clear_run()
  run = RunManager.new()
  run.run_ended.connect(_on_run_ended)
  run.start(seed_value)
  _set_phase(Phase.RUN)


## Resume from the save slot. Returns false (and stays put) if there is no usable
## save — no migration, so Save returns {} for absent / corrupt / old formats.
func resume_run() -> bool:
  var snap: Dictionary = Save.read()
  if snap.is_empty():
    return false
  _clear_run()
  run = RunManager.new()
  run.run_ended.connect(_on_run_ended)
  run.rehydrate(snap)
  _set_phase(Phase.RUN)
  return true


## End the live run: clear the save and move to Death / Win. The run REFERENCE is
## kept (so its outcome + final state stay readable) until the next start / resume
## / reset — freeing it here would free the run from inside its own run_ended emit.
func end_run(outcome: int) -> void:
  Save.clear()
  _set_phase(Phase.WIN if outcome == RunManager.Outcome.WON else Phase.DEATH)


## Test / session reset (TestCleanup): free any live run, return to Title. Leaves
## the save slot alone — a reset is not a death (death/win clears it).
func reset() -> void:
  _clear_run()
  phase = Phase.TITLE


func _on_run_ended(outcome: int) -> void:
  end_run(outcome)


func _set_phase(new_phase: int) -> void:
  phase = new_phase
  phase_changed.emit(new_phase)


func _clear_run() -> void:
  if run != null:
    run.teardown()
    run.free()
    run = null
