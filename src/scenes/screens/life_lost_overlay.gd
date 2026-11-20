class_name LifeLostOverlay
extends Control
## The panel after a lost fight with lives left (docs/systems/run_screen.md): it says a life was lost
## and how many are left, with a Continue button. The run has already taken the life and healed the
## player when the panel opens (RunManager._on_encounter_resolved); Continue emits `continued`, and
## the run screen moves on as after a won fight. Writes nothing. Text localized.

signal continued()

@onready var _lives: Label = $Panel/Lives


func setup(lives: int) -> void:
  _lives.text = tr('You lose a life. Lives left: {0}').format([lives])   # placeholder text


func _on_continue_pressed() -> void:
  continued.emit()
