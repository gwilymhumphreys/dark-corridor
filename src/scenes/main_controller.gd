class_name MainController
extends Node
## The presentation-tree root (architecture → Scene tree & node model). Boots the
## game: holds the ScreenHolder and swaps the active screen on Game.phase_changed.
## It only READS Game; the screens emit intents. The logic tree is NOT mounted here
## — it stays out of the scene tree (the run screen drives the fight tick directly).
##
## Autoloads _ready before the main scene, so Game has already entered TITLE by the
## time we boot — we read Game.phase directly here and connect for later changes.
##
## Going into a run turns the page forward and going back to the title screen turns it back
## (`PageTurn`, docs/systems/page_turn.md): the screen being left is captured, the new screen is
## swapped in under the still image, and the page turns over onto it.

const TITLE_SCREEN: PackedScene = preload('res://src/scenes/screens/title_screen.tscn')
const RUN_SCREEN: PackedScene = preload('res://src/scenes/screens/run_screen.tscn')
const OUTCOME_SCREEN: PackedScene = preload('res://src/scenes/screens/outcome_screen.tscn')

@onready var _holder: Control = $ScreenHolder

var _current: Node = null
var _phase: int = GameManagerAutoload.Phase.BOOT
var _shown_at_frame: int = 0   # frames drawn when the current screen was added


func _ready() -> void:
  Game.phase_changed.connect(_on_phase_changed)
  _show_for_phase(Game.phase)


func _on_phase_changed(phase: int) -> void:
  _show_for_phase(phase)


func _show_for_phase(phase: int) -> void:
  var direction: int = _turn_direction(_phase, phase)
  _phase = phase
  # A screen swapped out before it was ever drawn has nothing to turn over (a start-up argument that
  # skips the title screen).
  var turning: bool = direction != 0 and PageTurn.can_turn() and Engine.get_frames_drawn() > _shown_at_frame
  if turning and not PageTurn.has_capture():
    await PageTurn.capture()
  _swap_for_phase(phase)
  if turning:
    PageTurn.play(direction as PageTurnAutoload.Direction)


# Forward into a run from the title or outcome screen, back to the title from a run or the outcome
# screen, and no turn to the outcome screen.
static func _turn_direction(from: int, to: int) -> int:
  var menus: Array[int] = [GameManagerAutoload.Phase.TITLE, GameManagerAutoload.Phase.DEATH, GameManagerAutoload.Phase.WIN]
  if to == GameManagerAutoload.Phase.RUN and from in menus:
    return PageTurnAutoload.Direction.FORWARD
  if to == GameManagerAutoload.Phase.TITLE and from != GameManagerAutoload.Phase.BOOT and from != GameManagerAutoload.Phase.TITLE:
    return PageTurnAutoload.Direction.BACK
  return 0


func _swap_for_phase(phase: int) -> void:
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
  _shown_at_frame = Engine.get_frames_drawn()
  _holder.add_child(screen)
