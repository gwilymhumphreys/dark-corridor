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

@onready var _holder: Control = $ScreenHolder

var _current: Node = null


func _ready() -> void:
  Game.phase_changed.connect(_on_phase_changed)
  _show_for_phase(Game.phase)
  # Dev hook (mirrors the sandbox): `--shot` captures a frame then quits — combine
  # with the title's `--autostart` to screenshot a live fight.
  if _has_flag('--shot'):
    _auto_shot()


func _on_phase_changed(phase: int) -> void:
  _show_for_phase(phase)


func _show_for_phase(phase: int) -> void:
  match phase:
    GameManagerAutoload.Phase.TITLE:
      _swap(TITLE_SCREEN.instantiate())
    GameManagerAutoload.Phase.RUN:
      _swap(RUN_SCREEN.instantiate())
    GameManagerAutoload.Phase.DEATH, GameManagerAutoload.Phase.WIN:
      _swap(_outcome_placeholder(phase))   # Step 8 replaces these with real screens
    _:
      pass


func _swap(screen: Node) -> void:
  if _current != null and is_instance_valid(_current):
    _current.queue_free()
  _current = screen
  _holder.add_child(screen)


func _has_flag(flag: String) -> bool:
  return flag in OS.get_cmdline_args() or flag in OS.get_cmdline_user_args()


## `--shot-delay <seconds>` overrides the default capture delay (e.g. to grab a later
## fight or the win screen). Defaults to 1.5s (mid first-fight).
func _shot_delay() -> float:
  var args: Array = []
  args.append_array(OS.get_cmdline_args())
  args.append_array(OS.get_cmdline_user_args())
  var i: int = args.find('--shot-delay')
  if i >= 0 and i + 1 < args.size():
    return float(args[i + 1])
  return 1.5


func _auto_shot() -> void:
  await get_tree().create_timer(_shot_delay()).timeout   # mid-fight when paired with --autostart
  await RenderingServer.frame_post_draw
  var image: Image = get_viewport().get_texture().get_image()
  var path: String = 'user://run_shot.png'
  image.save_png(path)
  print('SHOT_SAVED:', ProjectSettings.globalize_path(path))
  get_tree().quit()


## Temporary win/death readout until Step 8 builds the real screens.
func _outcome_placeholder(phase: int) -> Control:
  var label := Label.new()
  label.set_anchors_preset(Control.PRESET_FULL_RECT)
  label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
  label.add_theme_font_size_override('font_size', 80)
  label.text = tr('Victory') if phase == GameManagerAutoload.Phase.WIN else tr('Defeat')
  return label
