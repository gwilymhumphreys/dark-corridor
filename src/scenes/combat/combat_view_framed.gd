class_name CombatViewFramed
extends CombatView
## The framed combat view (docs/systems/ui_layout.md) — the corridor-forward layout, placed in the
## screen sections: the corridor top left with each **enemy floating over it** (`enemy_hud`: name +
## status + HP + item cells), the potions and the player's board top right, and the **player's
## portrait + name + HP** lower left with run-scoped allies / combat-scoped summon tokens in the **slots flanking the
## player** (`ally_slot`). It reads the CombatManager's rosters each frame, so mid-fight summons (a boss
## add, a player token) appear as they spawn. Hosts the VFX wall; reads logic, writes nothing.
## The corridor stays as the mood backdrop + the lead occupant for the approach. No alpha.
## (The swappable surface — bind/release/positions + potion_thrown — is the CombatView base.)

const POTION_SLOT: PackedScene = preload('res://src/scenes/combat/potion_slot.tscn')
const ITEM_CELL: PackedScene = preload('res://src/scenes/combat/item_cell.tscn')
const ENEMY_HUD: PackedScene = preload('res://src/scenes/combat/enemy_hud.tscn')
const ALLY_SLOT: PackedScene = preload('res://src/scenes/combat/ally_slot.tscn')
const TOOLTIP_CLUSTER: PackedScene = preload('res://src/scenes/ui/tooltip/tooltip_cluster.tscn')
const SCREEN_SECTIONS: PackedScene = preload('res://src/ui/screen_sections.tscn')

const MAX_SLOTS_PER_SIDE: int = 2   # the 4 flanking slots: 2 left of the player, 2 right
const HUD_WIDTH_MARGIN: float = 0.95   # each enemy HUD's share of the corridor panel width
const PORTRAIT_MIN_SIZE: float = 40.0   # the player portrait shrinks to fit its section, down to this
const ENEMY_FADE_IN: float = 0.25       # seconds an enemy HUD takes to fade up when the fight starts
const TEMPORARY_FADE_OUT: float = 0.45  # seconds a temporary item's cell / a token's slot takes to fade away at fight end
# A big hit pauses the fight and shakes this view, both growing with VfxDriver.big_hit_strength.
const HIT_PAUSE_MIN: float = 0.05     # real seconds
const HIT_PAUSE_MAX: float = 0.15
const SHAKE_DISTANCE_MIN: float = 6.0   # pixels
const SHAKE_DISTANCE_MAX: float = 24.0
const SHAKE_DURATION_MIN: float = 0.2   # real seconds
const SHAKE_DURATION_MAX: float = 0.45

var _cm: CombatManager
var _player: Actor

@onready var _corridor_part: Control = $Corridor
@onready var _corridor: CombatCorridor = $Corridor/CorridorPanel
@onready var _enemy_huds_box: Control = $EnemyArea/EnemyHuds
@onready var _items_part: VBoxContainer = $Items
@onready var _player_items: GridContainer = $Items/PlayerItems
@onready var _potions: HBoxContainer = $Items/Potions
@onready var _portraits_part: HBoxContainer = $Portraits
@onready var _portrait: Control = $Portraits/PlayerPortrait/Portrait
@onready var _portrait_image: TextureRect = $Portraits/PlayerPortrait/Portrait/Image
@onready var _player_hp_fill: ColorRect = $Portraits/PlayerPortrait/Readout/HP/Fill
@onready var _player_hp_label: Label = $Portraits/PlayerPortrait/Readout/HP/Label
@onready var _player_status_numbers: StatusNumbers = $Portraits/PlayerPortrait/Readout/HP/StatusNumbers
@onready var _ally_left: HBoxContainer = $Portraits/AllyLeft
@onready var _ally_right: HBoxContainer = $Portraits/AllyRight
@onready var _corridor_area: Control = $CorridorArea
@onready var _vfx: VfxDriver = $VfxWall

var _enemy_huds: Dictionary = {}    # Actor -> EnemyHud
var _ally_slots: Dictionary = {}    # Actor -> AllySlot
var _player_cells: Dictionary = {}  # Item -> ItemCell (the player's right-panel board)
var _hovered_cell: ItemCell = null  # the cell the tooltip poll last reported under the pointer
var _throw_origins: Dictionary = {}  # Consumable -> the global centre of the slot it was thrown from
var _cooldowns_shown: bool = false  # whether board cells show their cooldown fill (off outside a fight)
var _cluster: TooltipCluster = null   # the floating item tooltip (its own CanvasLayer, layer 50)
var _shake_tween: Tween
var _shake_rng: RandomNumberGenerator = RandomNumberGenerator.new()   # not the fight's seeded one
var _enemies_shown: bool = false   # false through the approach: the enemy HUDs stay hidden
var _fading_out: Dictionary = {}   # Item/Actor -> true while its widget fades away at fight end; not rebuilt


func _ready() -> void:
  if sections == null:
    sections = SCREEN_SECTIONS.instantiate()
    add_child(sections)
    move_child(sections, 0)
  sections.sections_changed.connect(_place_in_sections)
  _place_in_sections()


## Put the corridor, the item column and the portrait row in their screen sections. The item columns and
## portraits are fitted to the new sizes first, so no container is held larger than its section.
func _place_in_sections() -> void:
  var corridor_rect: Rect2 = sections.section('Corridor').get_global_rect()
  var items_rect: Rect2 = sections.section('Items').get_global_rect()
  var portraits_rect: Rect2 = sections.section('Portraits').get_global_rect()
  _fit_item_columns(items_rect.size.x)
  _fit_portraits(portraits_rect.size.y)
  _place(_corridor_part, corridor_rect)
  _place(_corridor_area, corridor_rect)
  _place(_items_part, items_rect)
  _place(_portraits_part, portraits_rect)


func _place(part: Control, rect: Rect2) -> void:
  part.global_position = rect.position
  part.size = rect.size


## As many item columns as fit the section's width.
func _fit_item_columns(width: float) -> void:
  var gap: float = _player_items.get_theme_constant('h_separation')
  _player_items.columns = maxi(1, int((width + gap) / (ItemCell.CELL_SIZE.x + gap)))


## The player portrait stays square and takes the section's full height, sitting to the left of the
## name and HP bar. Each ally slot fits itself the same way.
func _fit_portraits(height: float) -> void:
  var side: float = maxf(floorf(height), PORTRAIT_MIN_SIZE)
  _portrait.custom_minimum_size = Vector2(side, side)
  for slot in _ally_slots.values():
    (slot as AllySlot).fit_height(height)


## Bind the live fight: the player's portrait + HP (lower left) and its board column (top right),
## the potion slots, a HUD per enemy / a slot per ally-or-token, and the VFX wall on this layout.
## `cm` is null outside a fight (an event beat): the player's side is shown with no enemies.
func bind(cm: CombatManager, player: Actor, potions: Array) -> void:
  _cm = cm
  _player = player
  _enemies_shown = false   # the HUDs stay hidden until show_enemies (the fight starting)
  _player_status_numbers.actor = player
  _cooldowns_shown = false   # the fight has not started yet; begin_fight turns the fills on
  if player.portrait != '':
    _portrait_image.texture = load(player.portrait)
  _build_player_items(player)
  _build_potions(potions)
  _corridor.set_enemy_depth(0.0)
  _sync_rosters()
  _refresh_player_hp()
  _vfx.setup(_cm, self)
  _vfx.big_hit.connect(_on_big_hit)
  _cluster = TOOLTIP_CLUSTER.instantiate()
  add_child(_cluster)   # a CanvasLayer — renders in screen space regardless of this Control parent


func _process(_delta: float) -> void:
  _sync_rosters()         # pick up mid-fight summons (a boss add / a player token)
  _sync_player_items()    # pick up items created or removed during the fight
  _position_enemy_huds()  # keep each HUD pinned above its enemy's corridor sprite
  _refresh_player_hp()
  if _cm != null and _vfx.combat != null and _cm.timekeeper != null:
    _corridor.show_hits(_cm.deliveries(), _cm.timekeeper.render_time())   # debug hit lights


func _refresh_player_hp() -> void:
  if _player == null:
    return
  var ratio: float = clampf(_player.hp / _player.max_hp, 0.0, 1.0)
  _player_hp_fill.anchor_right = ratio
  _player_hp_fill.offset_right = 0.0
  _player_hp_label.text = '%d / %d' % [int(round(_player.hp)), int(round(_player.max_hp))]


## Build the right-edge item column at bind. Cells get the fight's clock so their fire recoil
## rides render_time (slow-mo slows it; pause freezes it).
func _build_player_items(player: Actor) -> void:
  for item in player.board:
    _add_player_cell(item)


## Match the item column to the player's board each frame: items created during the fight gain a
## cell, and items removed (decayed, consumed, or stripped when the fight ends) lose theirs.
func _sync_player_items() -> void:
  if _player == null:
    return
  for item: Item in _player_cells.keys():
    if not item in _player.board:
      var cell: ItemCell = _player_cells[item]
      _player_cells.erase(item)
      _player_items.remove_child(cell)
      cell.queue_free()
  for item: Item in _player.board:
    if not _player_cells.has(item) and not _fading_out.has(item):
      _add_player_cell(item)


func _add_player_cell(item: Item) -> void:
  var cell: ItemCell = ITEM_CELL.instantiate()
  _player_items.add_child(cell)
  cell.setup(item, _cm.timekeeper if _cm != null else null, _cm != null and _cm.is_created_item(item))
  cell.show_cooldown = _cooldowns_shown
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
  # One corridor sprite per enemy, kept with its enemy (the corridor does nothing if the roster is unchanged).
  _corridor.set_enemies(enemies)
  for e in enemies:
    if not _enemy_huds.has(e):
      var hud: EnemyHud = ENEMY_HUD.instantiate()
      _enemy_huds_box.add_child(hud)
      # Budget each HUD a per-enemy share of the corridor panel so a multi-enemy row
      # shrinks its item cells instead of overlapping neighbours / clipping off-panel.
      hud.setup(e, _cm.timekeeper, _corridor.size.x * HUD_WIDTH_MARGIN / maxf(enemies.size(), 1.0))
      hud.visible = false   # up only once the reveal starts; a mid-fight summon fades in as it spawns
      hud.set_cooldowns_shown(_cooldowns_shown)
      if _enemies_shown:
        hud.fade_in(ENEMY_FADE_IN)
      _enemy_huds[e] = hud
  for a in player_side:
    if a != _player and not _ally_slots.has(a) and not _fading_out.has(a):   # the player keeps its centre-bottom portrait
      var slot: AllySlot = ALLY_SLOT.instantiate()
      _pick_ally_box().add_child(slot)
      slot.setup(a, _cm.timekeeper)
      slot.fit_height(sections.section('Portraits').size.y)
      slot.set_cooldowns_shown(_cooldowns_shown)
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


## Bring the enemy HUDs up when the fight starts — they stay hidden through the approach so the
## readouts appear with the boards rather than riding in with the walk.
## The fight has started: the clock is running, so the boards start showing their cooldown fills.
## Until now they were off, because a frozen fill over the icons reads as a bug during the walk.
func begin_fight() -> void:
  _set_cooldowns_shown(_cm != null)


func show_enemies(duration: float = ENEMY_FADE_IN) -> void:
  if _enemies_shown:
    return
  _enemies_shown = true
  for hud in _enemy_huds.values():
    (hud as EnemyHud).fade_in(duration)


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
    var slot: PotionSlot = POTION_SLOT.instantiate()
    _potions.add_child(slot)
    slot.setup(potions[i])
    slot.pressed.connect(_on_potion_pressed.bind(i))


## Remember the slot's centre before the throw removes the slot, so the potion's effects start there.
func _on_potion_pressed(index: int) -> void:
  var slot: PotionSlot = _potions.get_child(index)
  _throw_origins[slot.consumable] = slot.get_global_rect().get_center()
  potion_thrown.emit(index)


func refresh_potions(potions: Array) -> void:
  _build_potions(potions)


## Approach controls (docs/history/phase4_plan.md Step 7) — the run screen walks the player up to the
## waiting enemies, bringing them from a speck into full view (the mood; the per-actor widgets are
## the combat).
func corridor_area() -> Control:
  return _corridor_area


func set_enemy_depth(depth_cells: float) -> void:
  _corridor.set_enemy_depth(depth_cells)


func set_walk_distance(corridor_sections: float) -> void:
  _corridor.set_walk_distance(corridor_sections)


## Stop reading the live fight before it is torn down (the run screen calls this right before
## freeing the view + advancing). Render resources free with the view.
func release() -> void:
  _vfx.combat = null
  _corridor.show_hits([], 0.0)
  _set_cooldowns_shown(false)   # the fight is over, so clear the fills left at its last moment
  _fade_out_temporary()         # the created items and summon tokens leave with the fight
  _throw_origins.clear()
  # Drop the hovered Item ref BEFORE the run frees the CombatManager + its items (the Actor↔Item
  # cycle is broken at dissolve() — the cluster must not retain an Item across teardown).
  if _cluster != null:
    _cluster.hide_cluster()


## Fade away everything that only existed for this fight: each created item's cell on the player's
## board (CombatManager.is_created_item) and each summon token's ally slot. The logic keeps them
## until the Combat manager's teardown at the next advance, so without this they would sit on the
## board through the reward draft and then vanish with the view. The widget is dropped from the
## lookup maps at once — it is no longer hoverable or a VFX target — and `_fading_out` stops the
## per-frame sync rebuilding it while it fades.
func _fade_out_temporary() -> void:
  if _cm == null:
    return
  for item: Item in _player_cells.keys():
    if _cm.is_created_item(item):
      var cell: ItemCell = _player_cells[item]
      cell.item = null   # stop it reading an Item the fight is about to dissolve
      _player_cells.erase(item)
      _fading_out[item] = true
      _fade_out_and_free(cell)
  var allies: Array = _cm.allies
  for actor: Actor in _ally_slots.keys():
    if actor != _player and actor not in allies:   # on the player's side but not run-scoped: a summon token
      _fading_out[actor] = true
      _fade_out_and_free(_ally_slots[actor])
      _ally_slots.erase(actor)


## Fade a widget out where it stands and free it. It keeps its place in its container until it is
## freed, so the board reflows once at the end rather than snapping the moment the fade starts.
## The scale runs on the visual-only offset transform (CLAUDE.md), so the container keeps laying
## the widget out at its full size while it shrinks.
func _fade_out_and_free(widget: Control) -> void:
  widget.mouse_filter = Control.MOUSE_FILTER_IGNORE
  widget.offset_transform_enabled = true
  widget.offset_transform_pivot_ratio = Vector2(0.5, 0.5)
  var tween: Tween = create_tween()
  tween.set_parallel()
  tween.tween_property(widget, 'modulate:a', 0.0, TEMPORARY_FADE_OUT)
  tween.tween_property(widget, 'offset_transform_scale', Vector2(0.7, 0.7), TEMPORARY_FADE_OUT).set_ease(Tween.EASE_IN)
  tween.chain().tween_callback(widget.queue_free)


func _set_cooldowns_shown(shown: bool) -> void:
  _cooldowns_shown = shown
  for cell in _player_cells.values():
    (cell as ItemCell).show_cooldown = shown
  for slot in _ally_slots.values():
    (slot as AllySlot).set_cooldowns_shown(shown)
  for hud in _enemy_huds.values():
    (hud as EnemyHud).set_cooldowns_shown(shown)


func _exit_tree() -> void:
  # CLAUDE.md runtime cleanup: drop the live-fight refs + the widget maps on free.
  if _shake_tween != null:
    _shake_tween.kill()
  if _vfx.big_hit.is_connected(_on_big_hit):
    _vfx.big_hit.disconnect(_on_big_hit)
  _cm = null
  _player = null
  _portrait_image.texture = null
  if sections != null and sections.sections_changed.is_connected(_place_in_sections):
    sections.sections_changed.disconnect(_place_in_sections)
  sections = null
  _enemy_huds.clear()
  _ally_slots.clear()
  _player_cells.clear()
  _fading_out.clear()
  _throw_origins.clear()
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


func update_inspection(target: Dictionary, point: Vector2) -> void:
  _set_hovered_cell(target.get('item') as Item)
  if _cluster != null:
    _cluster.update_target(target, point)


func stop_inspection() -> void:
  _set_hovered_cell(null)
  if _cluster != null:
    _cluster.hide_cluster()


# The cell the poll reports takes the hover highlight (docs/systems/control_feedback.md). Board items
# take no mouse events of their own, so the poll is the only thing that knows which one is under the
# pointer.
func _set_hovered_cell(item: Item) -> void:
  var cell: ItemCell = _cell_for(item)
  if cell == _hovered_cell:
    return
  if is_instance_valid(_hovered_cell):
    _hovered_cell.hovered = false
  _hovered_cell = cell
  if cell != null:
    cell.hovered = true


func _cell_for(item: Item) -> ItemCell:
  if item == null:
    return null
  if _player_cells.has(item):
    return _player_cells[item] as ItemCell
  for hud in _enemy_huds.values():
    var hud_cell: ItemCell = (hud as EnemyHud).cell_at(item)
    if hud_cell != null:
      return hud_cell
  for slot in _ally_slots.values():
    var slot_cell: ItemCell = (slot as AllySlot).cell_at(item)
    if slot_cell != null:
      return slot_cell
  return null


# --- layout lookups the VFX wall reads (global / screen space) ---------------

func consumable_pos(consumable: Consumable) -> Vector2:
  if _throw_origins.has(consumable):
    return _throw_origins[consumable]
  return actor_pos(_player)


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


## An actor's on-screen point — the player at its centre-bottom portrait, every enemy on its
## corridor sprite, every ally/token at its flanking slot. The VFX wall flies projectiles + pops
## numbers here, so a hit lands on the creature rather than on the readout above it.
func actor_pos(actor) -> Vector2:
  if actor == _player:
    return _portrait.global_position + _portrait.size * 0.5
  if actor != null and _cm != null and actor in _cm.enemies:
    return _corridor.enemy_centre(_cm.enemies.find(actor))
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


## A big hit: a short pause of the fight, then a shake of this view that fades out. Both run on
## real time, so the shake plays through the pause.
func _on_big_hit(strength: float) -> void:
  if _cm != null:
    _cm.request_hit_pause(lerpf(HIT_PAUSE_MIN, HIT_PAUSE_MAX, strength))
  var distance: float = lerpf(SHAKE_DISTANCE_MIN, SHAKE_DISTANCE_MAX, strength)
  if _shake_tween != null:
    _shake_tween.kill()
  offset_transform_enabled = true
  _shake_tween = create_tween()
  _shake_tween.tween_method(_shake_step.bind(distance), 1.0, 0.0, lerpf(SHAKE_DURATION_MIN, SHAKE_DURATION_MAX, strength))
  _shake_tween.tween_callback(func() -> void: offset_transform_position = Vector2.ZERO)


func _shake_step(fade: float, distance: float) -> void:
  var direction: Vector2 = Vector2(_shake_rng.randf_range(-1.0, 1.0), _shake_rng.randf_range(-1.0, 1.0))
  offset_transform_position = direction * distance * fade
