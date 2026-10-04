class_name DevAutoload
extends Node
## The dev tools' start-up arguments for the game (docs/systems/dev_tools.md): skip saving, take a
## screenshot and quit, skip the title screen, walk past every choice of encounters or take one card,
## and add allies, board items, potions, relics or gold to a new run for screenshots. Does nothing unless one of its arguments is present, and
## the screens hold no code for any of it.

const DEMO_ALLY_ID: String = 'spore_thrall'         # the ally `--allies` recruits
const DEMO_POTION_ID: String = 'healing_draught'    # the potion `--potions` gives
const DEMO_RELIC_IDS: Array[String] = ['iron_idol', 'stone_ward', 'vital_charm']   # `--relics` cycles these
const DEFAULT_SHOT_DELAY: float = 1.5   # seconds; lands during the corridor approach of the first fight
const PAGE_TURN_START_DELAY: float = 0.5   # seconds the title screen shows before `--page-turn-at` starts a run

var _title_handled: bool = false   # the title arguments act on the first title screen only


func _ready() -> void:
  if DevArgs.has('--nosave'):
    Save.disabled = true   # never overwrite the player's run save
  if _wants_title_action() or DevArgs.has('--autofight') or DevArgs.has('--pick'):
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
  return DevArgs.has('--autostart') or DevArgs.has('--select') or DevArgs.has('--settings') \
    or DevArgs.value('--page-turn-at') != ''


func _wants_run_additions() -> bool:
  return DevArgs.has('--allies') or DevArgs.has('--board-items') or DevArgs.has('--potions') or DevArgs.has('--relics') \
    or DevArgs.has('--square') or DevArgs.has('--gold')


func _on_node_added(node: Node) -> void:
  if node is TitleScreen and not _title_handled:
    _title_handled = true
    _title_action(node as TitleScreen)
  elif node is EncounterChoice and (DevArgs.has('--autofight') or DevArgs.has('--pick')):
    _choose.call_deferred(node)


## `--autostart` starts a run as the default character or the one named by `--character=ID`;
## `--select` opens character select, and with `--character=ID` then selects that character once the
## page turn ends; `--settings` opens the settings screen. `--page-turn-at=P`
## starts a run once the title screen has shown, and stops the page turn into it at progress P.
func _title_action(title: TitleScreen) -> void:
  if DevArgs.value('--page-turn-at') != '':
    PageTurn.held_progress = float(DevArgs.value('--page-turn-at', '0.5'))
    await get_tree().create_timer(PAGE_TURN_START_DELAY).timeout
    Game.start_run(TitleScreen.DEFAULT_SEED, _autostart_character())
  elif DevArgs.has('--autostart'):
    Game.start_run.call_deferred(TitleScreen.DEFAULT_SEED, _autostart_character())
  elif DevArgs.has('--select'):
    await get_tree().process_frame
    await title.open_select()
    if DevArgs.value('--character') != '':
      if PageTurn.can_turn():
        await PageTurn.finished
      title.character_select().select_character(_autostart_character())
  elif DevArgs.has('--settings'):
    title.open_settings.call_deferred()


func _autostart_character() -> String:
  var id: String = DevArgs.value('--character', CharacterCatalog.DEFAULT)
  if not CharacterCatalog.has(id):
    push_warning('[Dev] unknown --character "%s", using %s' % [id, CharacterCatalog.DEFAULT])
    return CharacterCatalog.DEFAULT
  return id


## `--pick N`: take card N (1 = left) at every choice of encounters once the cards are dealt, as a
## click on it would, so the picked card moves up and stays shown.
## `--autofight`: walk past every choice at once, without the cards' animation, so the run goes from
## fight to fight. Deferred, so the run screen has connected to the cards by now.
func _choose(choice: EncounterChoice) -> void:
  if not is_instance_valid(choice) or Game.run == null:
    return
  if DevArgs.has('--pick'):
    await choice.dealt
    if is_instance_valid(choice):
      choice.pick(int(DevArgs.value('--pick', '1')) - 1)
  else:
    choice.skipped.emit()


## `--allies N`, `--board-items N`, `--potions N`, `--relics N`, `--gold N`: add to a new run before
## any screen shows it. `--square N` starts the run on square N (1-based) of the first act, such as 4 for the
## first elite fight. Board items are copies of the starting items, up to N on the board in total. Relics are
## added to the run's list only, so a relic that acts when granted (more maximum HP) does not.
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
  run.gold += int(DevArgs.value('--gold', '0'))
  var square: int = int(DevArgs.value('--square', '0'))
  if square > 1:
    run.jump_to((square - 1) * 2 + 1)   # every square has its choice of encounters before it
  var relic_count: int = int(DevArgs.value('--relics', '0'))
  for n in relic_count:
    var relic: RelicDef = RelicCatalog.get_def(DEMO_RELIC_IDS[n % DEMO_RELIC_IDS.size()])
    if relic != null:
      run.relics.append(Relic.new(relic))


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
