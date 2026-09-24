extends Node
## The presentation-tree root (architecture → Scene tree & node model). Boots the
## game: holds the ScreenHolder and swaps the active screen on Game.phase_changed.
## It only READS Game; the screens emit intents. The logic tree is NOT mounted here
## — it stays out of the scene tree (the run screen drives the fight tick directly).
##
## Autoloads _ready before the main scene, so Game has already entered TITLE by the
## time we boot — we read Game.phase directly here and connect for later changes.

const TITLE_SCREEN: PackedScene = preload('res://src/scenes/screens/title_screen.tscn')
const RUN_SCREEN: PackedScene = preload('res://src/scenes/screens/run_screen.tscn')
const OUTCOME_SCREEN: PackedScene = preload('res://src/scenes/screens/outcome_screen.tscn')

@onready var _holder: Control = $ScreenHolder

var _current: Node = null


func _ready() -> void:
  Game.phase_changed.connect(_on_phase_changed)
  _show_for_phase(Game.phase)


func _on_phase_changed(phase: int) -> void:
  _show_for_phase(phase)


func _show_for_phase(phase: int) -> void:
  match phase:
    GameManagerAutoload.Phase.TITLE:
      _swap(TITLE_SCREEN.instantiate())
    GameManagerAutoload.Phase.RUN:
      _swap(RUN_SCREEN.instantiate())
    GameManagerAutoload.Phase.DEATH, GameManagerAutoload.Phase.WIN:
      var outcome: OutcomeScreen = OUTCOME_SCREEN.instantiate()
      _swap(outcome)   # add to the tree first, so its node refs resolve
      outcome.setup(phase == GameManagerAutoload.Phase.WIN)
    _:
      pass


func _swap(screen: Node) -> void:
  if _current != null and is_instance_valid(_current):
    _current.queue_free()
  _current = screen
  _holder.add_child(screen)
