extends CombatView
## Throwaway host (like corridor_testbed) to WATCH the combat spine: builds one
## player vs one enemy, runs a real CombatManager (its _physics_process drives
## the tick), and composes the placeholder boards + VFX over it. Not the main
## scene — run it directly:
##   ...console.exe --path . res://src/scenes/combat_sandbox.tscn
## `--shot` captures a mid-fight frame then quits.

const PLAYER_ANCHOR := Vector2(620, 640)
const ENEMY_ANCHOR := Vector2(1940, 640)

var _cm: CombatManager
var _player: Actor
var _enemy: Actor
var _player_board: BoardView
var _enemy_board: BoardView
var _vfx: VfxDriver
var _result: Label


func _ready() -> void:
  _result = $Result
  _build_fight()
  if '--shot' in OS.get_cmdline_args() or '--shot' in OS.get_cmdline_user_args():
    _auto_shot()


func _build_fight() -> void:
  _player = _spawn(Balance.PLAYER_START_HP, [
    ItemCatalog.WEAPON, ItemCatalog.ARMOR, ItemCatalog.POISON_DAGGER,
  ])
  _enemy = _spawn(Balance.ENEMY_PLACEHOLDER_HP, [ItemCatalog.ENEMY_CLAW])

  _cm = CombatManager.new(_player, [_enemy])
  add_child(_cm)
  _cm.resolved.connect(_on_resolved)
  _cm.start()

  _player_board = BoardView.new()
  add_child(_player_board)
  _player_board.setup(_player, PLAYER_ANCHOR, true)

  _enemy_board = BoardView.new()
  add_child(_enemy_board)
  _enemy_board.setup(_enemy, ENEMY_ANCHOR, false)

  _vfx = VfxDriver.new()
  add_child(_vfx)
  _vfx.setup(_cm, self)

  _result.text = ''


func _spawn(max_hp: float, item_ids: Array) -> Actor:
  var a := Actor.new(max_hp)
  for id in item_ids:
    a.board.append(Item.new(ItemCatalog.get_def(id), a))
  return a


func _process(_delta: float) -> void:
  if _cm == null:
    return
  var m: Vector2 = get_global_mouse_position()
  var over: bool = _player_board.mouse_over(m) or _enemy_board.mouse_over(m)
  _cm.request_slowmo(over)


func _on_resolved(player_won: bool) -> void:
  _result.text = 'VICTORY' if player_won else 'DEFEAT'


func _unhandled_key_input(event: InputEvent) -> void:
  if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
    _restart()


func _restart() -> void:
  if _cm != null:
    _cm.teardown()
    _cm.queue_free()
  _player_board.queue_free()
  _enemy_board.queue_free()
  _vfx.queue_free()
  _build_fight()


# --- layout lookups the VFX wall reads --------------------------------------

func item_pos(item: Item) -> Vector2:
  var p: Vector2 = _player_board.icon_center(item)
  if p != Vector2.INF:
    return p
  p = _enemy_board.icon_center(item)
  if p != Vector2.INF:
    return p
  return actor_pos(item.owner)


func actor_pos(actor) -> Vector2:
  return PLAYER_ANCHOR if actor == _player else ENEMY_ANCHOR


## A Delivery's landing point — an Actor anchor OR an Item's icon (item-target effects).
func target_pos(target) -> Vector2:
  if target is Item:
    return item_pos(target)
  return actor_pos(target)


func _auto_shot() -> void:
  await get_tree().create_timer(2.0).timeout
  await RenderingServer.frame_post_draw
  var img: Image = get_viewport().get_texture().get_image()
  var path: String = 'user://combat_shot.png'
  img.save_png(path)
  print('SHOT_SAVED:', ProjectSettings.globalize_path(path))
  get_tree().quit()
