class_name DevAutoload
extends Node
## The dev tools' start-up arguments for the game (docs/systems/dev_tools.md): skip saving, take a
## screenshot and quit, skip the title screen, pick fights on its own, and add allies, board items or
## potions to a new run for screenshots. Does nothing unless one of its arguments is present, and
## the screens hold no code for any of it.

const DEMO_ALLY_ID: String = 'spore_thrall'         # the ally `--allies` recruits
const DEMO_POTION_ID: String = 'healing_draught'    # the potion `--potions` gives
const DEFAULT_SHOT_DELAY: float = 1.5   # seconds; lands during the corridor approach of the first fight

var _title_handled: bool = false   # the title arguments act on the first title screen only


func _ready() -> void:
  if DevArgs.has('--nosave'):
    Save.disabled = true   # never overwrite the player's run save
  if _wants_title_action() or DevArgs.has('--autofight'):
    get_tree().node_added.connect(_on_node_added)
  if _wants_run_additions():
    Game.run_started.connect(_add_to_run)
  if DevArgs.has('--shot'):
    _capture.call_deferred()


func _exit_tree() -> void:
  if get_tree().node_added.is_connected(_on_node_added):
    get_tree().node_added.disconnect(_on_node_added)
  if Game.run_started.is_connected(_add_to_run):
    Game.run_started.disconnect(_add_to_run)


func _wants_title_action() -> bool:
  return DevArgs.has('--autostart') or DevArgs.has('--select') or DevArgs.has('--settings')


func _wants_run_additions() -> bool:
  return DevArgs.has('--allies') or DevArgs.has('--board-items') or DevArgs.has('--potions')


func _on_node_added(node: Node) -> void:
  if node is TitleScreen and not _title_handled:
    _title_handled = true
    _title_action(node as TitleScreen)
  elif node is ChoiceOverlay and DevArgs.has('--autofight'):
    _pick_first_fight.call_deferred(node)


## `--autostart` starts a run as the default character or the one named by `--character=ID`;
## `--select` opens character select; `--settings` opens the settings screen.
func _title_action(title: TitleScreen) -> void:
  if DevArgs.has('--autostart'):
    Game.start_run.call_deferred(TitleScreen.DEFAULT_SEED, _autostart_character())
  elif DevArgs.has('--select'):
    title.open_select.call_deferred()
  elif DevArgs.has('--settings'):
    title.open_settings.call_deferred()


func _autostart_character() -> String:
  var id: String = DevArgs.value('--character', CharacterCatalog.DEFAULT)
  if not CharacterCatalog.has(id):
    push_warning('[Dev] unknown --character "%s", using %s' % [id, CharacterCatalog.DEFAULT])
    return CharacterCatalog.DEFAULT
  return id


## `--autofight`: pick the first fight on every path choice, as a click on its card would. Deferred,
## so the run screen has connected to the overlay and filled it by now.
func _pick_first_fight(overlay: ChoiceOverlay) -> void:
  if not is_instance_valid(overlay) or Game.run == null:
    return
  var candidates: Array = Game.run.pending_choice()
  var index: int = 0
  for i in candidates.size():
    if EncounterCatalog.get_def(candidates[i]).type == EncounterDef.Type.FIGHT:
      index = i
      break
  overlay.picked.emit(index)


## `--allies N`, `--board-items N`, `--potions N`: add to a new run before any screen shows it.
## Board items are copies of the starting items, up to N on the board in total.
func _add_to_run(run: RunManager) -> void:
  var ally_count: int = int(DevArgs.value('--allies', '0'))
  if ally_count > 0:
    if EnemyCatalog.has(DEMO_ALLY_ID):
      for _n in ally_count:
        run.add_ally(DEMO_ALLY_ID)
    else:
      push_warning('[Dev] --allies: no enemy definition "%s"' % DEMO_ALLY_ID)
  var board_size: int = int(DevArgs.value('--board-items', '0'))
  var starting: Array = run.player.board.duplicate()
  while run.player.board.size() < board_size and not starting.is_empty():
    var def: ItemDef = (starting[run.player.board.size() % starting.size()] as Item).def
    run.player.board.append(Item.new(def, run.player))
  var potion_count: int = int(DevArgs.value('--potions', '0'))
  if potion_count > 0:
    var potion: ConsumableDef = ConsumableCatalog.get_def(DEMO_POTION_ID)   # logs an error if missing
    if potion != null:
      for _n in potion_count:
        run.potions.append(Consumable.new(potion))


## `--shot [--shot-delay SECONDS]`: save one frame of whatever scene is running, named after its
## file, then quit.
func _capture() -> void:
  var delay: float = float(DevArgs.value('--shot-delay', str(DEFAULT_SHOT_DELAY)))
  await get_tree().create_timer(delay).timeout
  await RenderingServer.frame_post_draw
  var scene: Node = get_tree().current_scene
  var scene_name: String = scene.scene_file_path.get_file().get_basename() if scene != null else 'game'
  Screenshot.save(get_viewport(), scene_name + '_shot')
  get_tree().quit()
