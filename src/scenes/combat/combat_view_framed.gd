class_name CombatViewFramed
extends CombatView
## The framed combat view (docs/systems/ui_layout.md) — the corridor-forward layout: the corridor large
## top-left with each **enemy floating over it** (`enemy_hud`: name + status + HP + item cells),
## the **player's portrait + HP centre-bottom** with its board as a **column down the right edge**,
## and run-scoped allies / combat-scoped summon tokens in the **slots flanking the player**
## (`ally_slot`). It reads the CombatManager's rosters each frame, so mid-fight summons (a boss
## add, a player token) appear as they spawn. Hosts the VFX wall; reads logic, writes nothing.
## The corridor stays as the mood backdrop + the lead occupant for the approach. No alpha.
## (The swappable surface — bind/release/positions + potion_thrown — is the CombatView base.)

const POTION_SLOT: PackedScene = preload('res://src/scenes/combat/potion_slot.tscn')
const ITEM_CELL: PackedScene = preload('res://src/scenes/combat/item_cell.tscn')
const ENEMY_HUD: PackedScene = preload('res://src/scenes/combat/enemy_hud.tscn')
const ALLY_SLOT: PackedScene = preload('res://src/scenes/combat/ally_slot.tscn')
const TOOLTIP_CLUSTER: PackedScene = preload('res://src/scenes/ui/tooltip/tooltip_cluster.tscn')

const MAX_SLOTS_PER_SIDE: int = 2   # the 4 flanking slots: 2 left of the player, 2 right
const HUD_WIDTH_MARGIN: float = 0.95   # each enemy HUD's share of the corridor panel width

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
var _enemy_sprite_count: int = -1   # last count handed to the corridor (re-arrange only on change)
var _cluster: TooltipCluster = null   # the floating item tooltip (its own CanvasLayer, layer 50)


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
  _cluster = TOOLTIP_CLUSTER.instantiate()
  add_child(_cluster)   # a CanvasLayer — renders in screen space regardless of this Control parent


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
## right-edge item column once at bind. Cells get the fight's clock so their fire recoil
## rides render_time (slow-mo slows it; pause freezes it).
func _build_player_items(player: Actor) -> void:
  for item in player.board:
    var cell: ItemCell = ITEM_CELL.instantiate()
    _player_items.add_child(cell)
    cell.setup(item, _cm.timekeeper)
    _player_cells[item] = cell


## Ensure every roster actor has its widget — enemies as HUDs over the corridor, player-side
## allies/tokens as slots flanking the player. Cheap: only rebuilds when the roster grew.
func _sync_rosters() -> void:
  if _cm == null:
    return
  var enemies: Array = _cm.enemies
  var player_side: Array = _cm.player_side()
  # Drop widgets whose actor left the roster — reaped dead enemies / summon tokens. A downed
  # run-scoped ally stays in player_side (kept on the roster), so its slot survives (shown dimmed).
  _drop_missing(_enemy_huds, enemies)
  _drop_missing(_ally_slots, player_side)
  # One corridor occupant sprite per enemy — re-arranged only when the count changes.
  if enemies.size() != _enemy_sprite_count:
    _corridor.set_enemy_count(enemies.size())
    _enemy_sprite_count = enemies.size()
  for e in enemies:
    if not _enemy_huds.has(e):
      var hud: EnemyHud = ENEMY_HUD.instantiate()
      _enemy_huds_box.add_child(hud)
      # Budget each HUD a per-enemy share of the corridor panel so a multi-enemy row
      # shrinks its item cells instead of overlapping neighbours / clipping off-panel.
      hud.setup(e, _cm.timekeeper, _corridor.size.x * HUD_WIDTH_MARGIN / maxf(enemies.size(), 1.0))
      _enemy_huds[e] = hud
  for a in player_side:
    if a != _player and not _ally_slots.has(a):   # the player keeps its centre-bottom portrait
      var slot: AllySlot = ALLY_SLOT.instantiate()
      _pick_ally_box().add_child(slot)
      slot.setup(a, _cm.timekeeper)
      _ally_slots[a] = slot


## Fill the 4 flanking slots left-first (2 left of the player, then 2 right — the documented
## layout); past 4 (summon tokens), alternate to the emptier side so overflow never marches
## one-sidedly into the player's board column.
func _pick_ally_box() -> HBoxContainer:
  if _ally_left.get_child_count() < MAX_SLOTS_PER_SIDE:
    return _ally_left
  if _ally_right.get_child_count() < MAX_SLOTS_PER_SIDE:
    return _ally_right
  return _ally_left if _ally_left.get_child_count() <= _ally_right.get_child_count() else _ally_right


## Free + forget any widget whose actor is no longer present in the roster (reaped from combat).
func _drop_missing(widgets: Dictionary, present: Array) -> void:
  for actor in widgets.keys():
    if actor not in present:
      (widgets[actor] as Node).queue_free()
      widgets.erase(actor)


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
    # Keep the HUD on the panel — an edge occupant's wide HUD clamps in rather than clipping off.
    hud.position.x = clampf(hud.position.x, 0.0, maxf(_enemy_huds_box.size.x - hud.size.x, 0.0))


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


## Approach controls (docs/history/phase4_plan.md Step 7) — the run screen tweens the corridor's lead occupant
## from depth into full view (the mood; the per-actor widgets are the combat).
func set_enemy_depth(depth_cells: float) -> void:
  _corridor.set_enemy_depth(depth_cells)


func set_gliding(on: bool) -> void:
  _corridor.set_gliding(on)


## Stop reading the live fight before it is torn down (the run screen calls this right before
## freeing the view + advancing). Render resources free with the view.
func release() -> void:
  _vfx.combat = null
  # Drop the hovered Item ref BEFORE the run frees the CombatManager + its items (the Actor↔Item
  # cycle is broken at dissolve() — the cluster must not retain an Item across teardown).
  if _cluster != null:
    _cluster.hide_cluster()


func _exit_tree() -> void:
  # CLAUDE.md runtime cleanup: drop the live-fight refs + the widget maps on free.
  _cm = null
  _player = null
  _enemy_huds.clear()
  _ally_slots.clear()
  _player_cells.clear()
  _cluster = null


## The hover surface for the slow-mo intent: a board item on any HUD / ally slot / the player's
## column, or a potion slot. NOT the corridor backdrop — it now fills most of the screen
## (corridor-forward layout), so hovering it must not hold slow-mo on; the enemy reads off its
## HUD, which IS inspectable.
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
  for slot in _potions.get_children():
    if (slot as Control).get_global_rect().has_point(point):
      return true
  return false


# --- tooltip cluster (docs/systems/tooltips.md) ------------------------------

## The board item under `point` — enemy-HUD cells, ally-slot cells, then the player's column —
## as {item, rect (global), side} for the cluster, or {} if the point is over no cell. The rect is
## re-read each frame so the cluster tracks a moving cell (enemy HUDs reposition every frame).
func inspectable_at(point: Vector2) -> Dictionary:
  for hud in _enemy_huds.values():
    var hud_item: Item = (hud as EnemyHud).item_at(point)
    if hud_item != null:
      return {'item': hud_item, 'rect': (hud as EnemyHud).cell_rect(hud_item), 'side': TooltipCluster.Side.LEFT}
  for slot in _ally_slots.values():
    var slot_item: Item = (slot as AllySlot).item_at(point)
    if slot_item != null:
      return {'item': slot_item, 'rect': (slot as AllySlot).cell_rect(slot_item), 'side': TooltipCluster.Side.LEFT}
  for item in _player_cells:
    var cell: ItemCell = _player_cells[item]
    if cell.get_global_rect().has_point(point):
      return {'item': item, 'rect': cell.get_global_rect(), 'side': TooltipCluster.Side.LEFT}
  return {}


func update_inspection(point: Vector2) -> void:
  if _cluster != null:
    _cluster.update_target(inspectable_at(point), point)


func stop_inspection() -> void:
  if _cluster != null:
    _cluster.hide_cluster()


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
