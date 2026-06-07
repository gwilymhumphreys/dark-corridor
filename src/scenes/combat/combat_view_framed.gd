class_name CombatViewFramed
extends Control
## The framed combat view (ui_layout_prd) — now MULTI-ACTOR. It binds the live fight and
## renders a BoardStrip (board + HP) per actor on BOTH sides: every enemy in a column on the
## right, the player's prominent board bottom-left, and run-scoped allies / combat-scoped
## summon tokens in a column beside it. It reads the CombatManager's rosters each frame, so
## mid-fight summons (a boss add, a player token) appear as they spawn. Hosts the VFX wall;
## reads logic, writes nothing. The corridor stays as the mood backdrop + the lead occupant
## for the approach. The framed-vs-fullscreen open is isolated to this swappable CombatView.

## Emitted when a potion slot is clicked — a throw-potion intent the run screen
## forwards to RunManager.throw_potion (which activates it through the Combat manager).
signal potion_thrown(index: int)

const POTION_SLOT: PackedScene = preload('res://src/scenes/combat/potion_slot.tscn')
const BOARD_STRIP: PackedScene = preload('res://src/scenes/combat/board_strip.tscn')

var _cm: CombatManager
var _player: Actor

@onready var _corridor: CombatCorridor = $CorridorPanel
@onready var _player_strip: BoardStrip = $PlayerSide/PlayerBoard
@onready var _enemy_strips: VBoxContainer = $EnemySide/EnemyStrips
@onready var _ally_strips: VBoxContainer = $PlayerSide/AllyStrips
@onready var _portrait: Control = $PlayerSide/Portrait
@onready var _potions: HBoxContainer = $PlayerSide/Potions
@onready var _vfx: VfxDriver = $VfxWall

var _strips: Dictionary = {}   # Actor -> BoardStrip (incl. the player → the prominent board)
var _roster_count: int = -1


## Bind the live fight: the player's prominent board + a strip per enemy / ally / token,
## the potion slots, and the VFX wall pointed at this layout.
func bind(cm: CombatManager, player: Actor, potions: Array) -> void:
  _cm = cm
  _player = player
  _player_strip.setup(player)
  _strips[player] = _player_strip   # the player's strip is the prominent PlayerBoard
  _build_potions(potions)
  _corridor.set_enemy_depth(0.0)
  _sync_strips()
  _vfx.setup(_cm, self)


func _process(_delta: float) -> void:
  _sync_strips()   # pick up mid-fight summons (a boss add / a player token)


## Ensure every roster actor has a BoardStrip — enemies in the right column, player-side
## allies/tokens beside the player's board. Cheap: only rebuilds when the roster grew.
func _sync_strips() -> void:
  if _cm == null:
    return
  var enemies: Array = _cm.enemies
  var player_side: Array = _cm.player_side()
  var count: int = enemies.size() + player_side.size()
  if count == _roster_count:
    return
  _roster_count = count
  for e in enemies:
    if not _strips.has(e):
      _strips[e] = _new_strip(e, _enemy_strips)
  for a in player_side:
    if a != _player and not _strips.has(a):   # the player keeps the prominent PlayerBoard
      _strips[a] = _new_strip(a, _ally_strips)


func _new_strip(actor: Actor, parent: Node) -> BoardStrip:
  var strip: BoardStrip = BOARD_STRIP.instantiate()
  parent.add_child(strip)
  strip.setup(actor)
  return strip


## (Re)build the potion slots from the reserve. Each slot is a clickable button that
## emits potion_thrown(index). Call refresh_potions after a throw consumes one.
func _build_potions(potions: Array) -> void:
  for child in _potions.get_children():
    _potions.remove_child(child)   # drop now so the new slots lay out at once
    child.queue_free()
  for i in potions.size():
    var slot: Button = POTION_SLOT.instantiate()
    _potions.add_child(slot)
    slot.pressed.connect(_on_potion_pressed.bind(i))


func _on_potion_pressed(index: int) -> void:
  potion_thrown.emit(index)


func refresh_potions(potions: Array) -> void:
  _build_potions(potions)


## Approach controls (phase4_plan Step 7) — the run screen tweens the corridor's lead
## occupant from depth into full view (the mood; the per-actor boards are the combat).
func set_enemy_depth(depth_cells: float) -> void:
  _corridor.set_enemy_depth(depth_cells)


func set_gliding(on: bool) -> void:
  _corridor.set_gliding(on)


## Stop reading the live fight before it is torn down (the run screen calls this right
## before freeing the view + advancing, so the VFX wall never samples a CombatManager
## that's about to free). Render resources free with the view.
func release() -> void:
  _vfx.combat = null


func _exit_tree() -> void:
  # CLAUDE.md runtime cleanup: drop the live-fight refs + the Actor->strip map on free
  # (the VFX wall is already detached by release(); child strips clean themselves up).
  _cm = null
  _player = null
  _strips.clear()


## The hover surface for the slow-mo intent: any board item (any actor, either side), any
## potion slot, or the corridor occupant. Hovering any of these slows the clock to inspect.
func mouse_over_inspectable(point: Vector2) -> bool:
  for strip in _strips.values():
    if (strip as BoardStrip).mouse_over(point):
      return true
  if _corridor.get_global_rect().has_point(point):
    return true
  for slot in _potions.get_children():
    if (slot as Control).get_global_rect().has_point(point):
      return true
  return false


# --- layout lookups the VFX wall reads (global / screen space) ---------------

func item_pos(item: Item) -> Vector2:
  # A source-less Delivery (a thrown consumable: Delivery.source is null) flies from the
  # player who threw it — and never deref a null item/owner.
  if item == null:
    return actor_pos(_player)
  for strip in _strips.values():
    var centre: Vector2 = (strip as BoardStrip).cell_centre(item)
    if centre != Vector2.INF:
      return centre
  return actor_pos(item.owner) if item.owner != null else actor_pos(_player)


## An actor's on-screen point — the player at its portrait (its identity anchor), every
## other actor (enemy / ally / token) at its board strip's centre. The VFX wall flies
## projectiles + pops numbers here.
func actor_pos(actor) -> Vector2:
  if actor == _player:
    return _portrait.global_position + _portrait.size * 0.5
  if actor != null and _strips.has(actor):
    return (_strips[actor] as BoardStrip).strip_centre()
  return _portrait.global_position + _portrait.size * 0.5


## A Delivery's landing point — an Actor (above) OR an Item (its board cell, for
## item-targeting effects like a random silence).
func target_pos(target) -> Vector2:
  if target is Item:
    return item_pos(target)
  return actor_pos(target)
