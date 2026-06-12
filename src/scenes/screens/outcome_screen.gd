class_name OutcomeScreen
extends Control
## The run-end screen (docs/systems/game_manager.md phases WIN / DEATH): the outcome + a choice to
## start a New Run or return to Title. One scene for both endings — the title text is
## set from the outcome (dynamic → tr()). It only emits the two run-lifecycle intents.

# Fixed for prototype dev (matches the title screen); a real seed/character pick later.
const NEW_RUN_SEED: int = 1

@onready var _title: Label = $Title


func _ready() -> void:
  $Menu/NewRunButton.pressed.connect(_on_new_run)
  $Menu/TitleButton.pressed.connect(_on_title)


## Set the outcome wording. Call after the screen is in the tree.
func setup(won: bool) -> void:
  _title.text = tr('Victory') if won else tr('You Died')


func _on_new_run() -> void:
  Game.start_run(NEW_RUN_SEED)


func _on_title() -> void:
  Game.return_to_title()
