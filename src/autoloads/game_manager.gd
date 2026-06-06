class_name GameManagerAutoload
extends Node
## The session singleton (game_manager_prd) — autoload registered `Game`. Owns the
## phase machine, the run lifecycle (create / resume / end the RunManager), and the
## save-lifecycle calls (Save.read on resume, Save.clear on death/win). Holds only a
## reference to the live run (null between runs) — never per-run state itself.
##
## Phase 3 is the thin slice: Title → Run → (Death | Win). Meta is deferred. The
## battle-speed dial is a session-level preference held here (below); pause is a
## run-screen concern (it freezes the screen's tick), deliberately NOT a Game phase.
## Headless: the autotest calls start_run() / resume_run() and drives Game.run's
## cycle; the Phase-4 run screen is the other client of the same surface.

signal phase_changed(phase: int)
signal battle_speed_changed(scale: float)

enum Phase { BOOT, TITLE, RUN, DEATH, WIN }

var phase: int = Phase.BOOT
var run: RunManager = null

# The player battle-speed dial (×1/×2/×3 — Balance.BATTLE_SPEEDS), a session-level
# PREFERENCE (not run-state, never saved): it survives across fights and runs within
# a session. The run screen applies `battle_speed` to each fight's Timekeeper base
# scale; the hover slow-mo override still *replaces* this base while inspecting
# (resolved: absolute slow-mo), returning TO it on release — not to ×1.
var battle_speed_index: int = 0
var battle_speed: float = Balance.TIMESCALE_BASE


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


## Test / session reset (TestCleanup): free any live run, return to Title, and drop
## the battle-speed preference back to ×1. Leaves the save slot alone — a reset is not
## a death (death/win clears it). Silent (no signals) — tests don't drive screens; the
## UI uses return_to_title().
func reset() -> void:
  _clear_run()
  phase = Phase.TITLE
  battle_speed_index = 0
  battle_speed = Balance.TIMESCALE_BASE


# --- battle-speed dial (a session preference; ui_layout_prd) -----------------

## Advance the dial one notch (×1 → ×2 → ×3 → ×1; Balance.BATTLE_SPEEDS) on the
## player's intent (the HUD speed button). Emits so a live fight can retime at once.
func cycle_battle_speed() -> void:
  set_battle_speed_index((battle_speed_index + 1) % Balance.BATTLE_SPEEDS.size())


func set_battle_speed_index(index: int) -> void:
  battle_speed_index = clampi(index, 0, Balance.BATTLE_SPEEDS.size() - 1)
  battle_speed = Balance.BATTLE_SPEEDS[battle_speed_index]
  battle_speed_changed.emit(battle_speed)


## Player intent (the outcome screen's "Title" button): drop the finished run and go
## back to Title, EMITTING the transition so the presentation swaps screens.
func return_to_title() -> void:
  _clear_run()
  _set_phase(Phase.TITLE)


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
