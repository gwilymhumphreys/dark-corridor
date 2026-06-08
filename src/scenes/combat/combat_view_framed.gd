class_name CombatViewFramed
extends Control
## The framed combat view (ui_layout_prd) — the corridor-forward layout: the corridor large
## top-left with each **enemy floating over it** (`enemy_hud`: name + status + HP + item cells),
## the **player's portrait + HP centre-bottom** with its board as a **column down the right edge**,
## and run-scoped allies / combat-scoped summon tokens in the **slots flanking the player**
## (`ally_slot`). It reads the CombatManager's rosters each frame, so mid-fight summons (a boss
## add, a player token) appear as they spawn. Hosts the VFX wall; reads logic, writes nothing.
## The corridor stays as the mood backdrop + the lead occupant for the approach. No alpha.

## Emitted when a potion slot is clicked — a throw-potion intent the run screen forwards to
## RunManager.throw_potion (which activates it through the Combat manager).
signal potion_thrown(index: int)

const POTION_SLOT: PackedScene = preload('res://src/scenes/combat/potion_slot.tscn')
const ITEM_CELL: PackedScene = preload('res://src/scenes/combat/item_cell.tscn')
const ENEMY_HUD: PackedScene = preload('res://src/scenes/combat/enemy_hud.tscn')
const ALLY_SLOT: PackedScene = preload('res://src/scenes/combat/ally_slot.tscn')

const MAX_LEFT_SLOTS: int = 2   # ally slots fill left-to-right: 2 left of the player, then right

var _cm: CombatManager
var _player: Actor

@onready var _corridor: CombatCorridor = $CorridorPanel
@onready var _enemy_huds_box: Control = $EnemyArea/EnemyHuds
@onready var _player_items: GridContainer = $RightPanel/PlayerItems
@onready var _potions: HBoxContainer = $RightPanel/Potions
@onready var _portrait: Control = $BottomBar/PlayerPortrait/Portrait
@onready var _player_hp_fill: ColorRect = $BottomBar/PlayerPortrait/HP/Fill
@onready var _player_hp_label: Label = $BottomBar/PlayerPortrait/HP/Label
@onready var _ally_left: HBoxContainer = $BottomBar/AllyLeft
@onready var _ally_right: HBoxContainer = $BottomBar/AllyRight
@onready var _vfx: VfxDriver = $VfxWall

var _enemy_huds: Dictionary = {}    # Actor -> EnemyHud
var _ally_slots: Dictionary = {}    # Actor -> AllySlot
var _player_cells: Dictionary = {}  # Item -> ItemCell (the player's right-panel board)
var _roster_count: int = -1


## Bind the live fight: the player's portrait + HP (centre-bottom) and its board column (right),
## the potion slots, a HUD per enemy / a slot per ally-or-token, and the VFX wall on this layout.
func bind(cm: CombatManager, player: Actor, potions: Array) -> void:
  _cm = cm
  _player = player
  _build_player_items(player)
  _build_potions(potions)
  _corridor.set_enemy_depth(0.0)
  _sync_rosters()
  _refresh_player_hp()
  _vfx.setup(_cm, self)


func _process(_delta: float) -> void:
  _sync_rosters()         # pick up mid-fight summons (a boss add / a player token)
  _position_enemy_huds()  # keep each HUD pinned above its enemy's corridor sprite
  _refresh_player_hp()


func _refresh_player_hp() -> void:
  if _player == null:
    return
  var ratio: float = clampf(_player.hp / _player.max_hp, 0.0, 1.0)
  _player_hp_fill.anchor_right = ratio
  _player_hp_fill.offset_right = 0.0
  _player_hp_label.text = '%d / %d' % [int(round(_player.hp)), int(round(_player.max_hp))]


## The player's board is fixed during a fight (drafts happen between beats), so build the
## right-edge item column once at bind.
func _build_player_items(player: Actor) -> void:
  for item in player.board:
    var cell: ItemCell = ITEM_CELL.instantiate()
    _player_items.add_child(cell)
    cell.setup(item)
    _player_cells[item] = cell


## Ensure every roster actor has its widget — enemies as HUDs over the corridor, player-side
## allies/tokens as slots flanking the player. Cheap: only rebuilds when the roster grew.
func _sync_rosters() -> void:
  if _cm == null:
    return
  var enemies: Array = _cm.enemies
  var player_side: Array = _cm.player_side()
  var count: int = enemies.size() + player_side.size()
  if count == _roster_count:
    return
  _roster_count = count
  _corridor.set_enemy_count(enemies.size())   # one corridor occupant sprite per enemy, side by side
  for e in enemies:
    if not _enemy_huds.has(e):
      var hud: EnemyHud = ENEMY_HUD.instantiate()
      _enemy_huds_box.add_child(hud)
      hud.setup(e)
      _enemy_huds[e] = hud
  for a in player_side:
    if a != _player and not _ally_slots.has(a):   # the player keeps its centre-bottom portrait
      var slot: AllySlot = ALLY_SLOT.instantiate()
      var box: HBoxContainer = _ally_left if _ally_slots.size() < MAX_LEFT_SLOTS else _ally_right
      box.add_child(slot)
      slot.setup(a)
      _ally_slots[a] = slot


## Pin each enemy HUD's bottom-centre just above its corridor sprite (enemy_anchor), so the HUD
## stays visually attached to its enemy as the roster + layout settle. Runs each frame.
func _position_enemy_huds() -> void:
  if _cm == null:
    return
  var enemies: Array = _cm.enemies
  var base: Vector2 = _enemy_huds_box.global_position
  for i in enemies.size():
    var e: Actor = enemies[i]
    if not _enemy_huds.has(e):
      continue
    var hud: EnemyHud = _enemy_huds[e]
    var anchor: Vector2 = _corridor.enemy_anchor(i)            # global, the HUD's bottom-centre target
    hud.position = anchor - base - Vector2(hud.size.x * 0.5, hud.size.y)


## (Re)build the potion slots from the reserve. Each is a clickable button emitting
## potion_thrown(index). Call refresh_potions after a throw consumes one.
func _build_potions(potions: Array) -> void:
  for child in _potions.get_children():
    _potions.remove_child(child)
    child.queue_free()
  for i in potions.size():
    var slot: Button = POTION_SLOT.instantiate()
    _potions.add_child(slot)
    slot.pressed.connect(_on_potion_pressed.bind(i))


func _on_potion_pressed(index: int) -> void:
  potion_thrown.emit(index)


func refresh_potions(potions: Array) -> void:
  _build_potions(potions)


## Approach controls (phase4_plan Step 7) — the run screen tweens the corridor's lead occupant
## from depth into full view (the mood; the per-actor widgets are the combat).
func set_enemy_depth(depth_cells: float) -> void:
  _corridor.set_enemy_depth(depth_cells)


func set_gliding(on: bool) -> void:
  _corridor.set_gliding(on)


## Stop reading the live fight before it is torn down (the run screen calls this right before
## freeing the view + advancing). Render resources free with the view.
func release() -> void:
  _vfx.combat = null


func _exit_tree() -> void:
  # CLAUDE.md runtime cleanup: drop the live-fight refs + the widget maps on free.
  _cm = null
  _player = null
  _enemy_huds.clear()
  _ally_slots.clear()
  _player_cells.clear()


## The hover surface for the slow-mo intent: any board item (enemy HUD, ally slot, or the
## player's column), any potion slot, or the corridor occupant.
func mouse_over_inspectable(point: Vector2) -> bool:
  for hud in _enemy_huds.values():
    if (hud as EnemyHud).mouse_over(point):
      return true
  for slot in _ally_slots.values():
    if (slot as AllySlot).mouse_over(point):
      return true
  for cell in _player_cells.values():
    if (cell as ItemCell).get_global_rect().has_point(point):
      return true
  if _corridor.get_global_rect().has_point(point):
    return true
  for slot in _potions.get_children():
    if (slot as Control).get_global_rect().has_point(point):
      return true
  return false


# --- layout lookups the VFX wall reads (global / screen space) ---------------

func item_pos(item: Item) -> Vector2:
  # A source-less Delivery (a thrown consumable: Delivery.source is null) flies from the player
  # who threw it — and never deref a null item/owner.
  if item == null:
    return actor_pos(_player)
  if _player_cells.has(item):
    return (_player_cells[item] as ItemCell).cell_centre()
  for hud in _enemy_huds.values():
    var c: Vector2 = (hud as EnemyHud).cell_centre(item)
    if c != Vector2.INF:
      return c
  for slot in _ally_slots.values():
    var c2: Vector2 = (slot as AllySlot).cell_centre(item)
    if c2 != Vector2.INF:
      return c2
  return actor_pos(item.owner) if item.owner != null else actor_pos(_player)


## An actor's on-screen point — the player at its centre-bottom portrait, every enemy at its
## HUD over the corridor, every ally/token at its flanking slot. The VFX wall flies projectiles
## + pops numbers here.
func actor_pos(actor) -> Vector2:
  if actor == _player:
    return _portrait.global_position + _portrait.size * 0.5
  if actor != null and _enemy_huds.has(actor):
    return (_enemy_huds[actor] as EnemyHud).hud_centre()
  if actor != null and _ally_slots.has(actor):
    return (_ally_slots[actor] as AllySlot).slot_centre()
  return _portrait.global_position + _portrait.size * 0.5


## A Delivery's landing point — an Actor (above) OR an Item (its board cell, for item-targeting
## effects like a random silence).
func target_pos(target) -> Vector2:
  if target is Item:
    return item_pos(target)
  return actor_pos(target)
