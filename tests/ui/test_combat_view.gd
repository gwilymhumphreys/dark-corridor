extends GutTest
## Phase 4 Step 2 — the framed combat view components: the corridor occupant scale
## law (CorridorScaled.axis_scale), the board strip building one cell per board item
## and tracking HP, and the framed view binding a fight without error. Presentation
## reads logic + writes nothing; these confirm the bind wiring, not the visuals (those
## are the `--shot` check).

var _nodes: Array = []
var _actors: Array = []


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  for n in _nodes:
    if is_instance_valid(n):
      n.free()
  _nodes.clear()
  for a in _actors:
    if is_instance_valid(a):
      a.dissolve()
  _actors.clear()
  TestCleanup.reset_all_managers()


func _spawn(hp: float, ids: Array) -> Actor:
  var a := Actor.new(hp)
  for id in ids:
    a.board.append(Item.new(ItemCatalog.get_def(id), a))
  _actors.append(a)
  return a


func _host(node: Node) -> Node:
  add_child(node)
  _nodes.append(node)
  return node


func test_axis_scale_matches_the_wall_perspective() -> void:
  # The occupant scales by the SAME law the walls use (depth_ratio^depth), so the
  # enemy stays locked to the corridor perspective on the approach.
  var corridor := CorridorScaled.new()
  assert_almost_eq(corridor.axis_scale(0.0), 1.0, 0.0001, 'depth 0 = full scale (arrived)')
  assert_almost_eq(corridor.axis_scale(1.0), corridor.depth_ratio, 0.0001, 'one cell deep = depth_ratio')
  assert_lt(corridor.axis_scale(5.0), corridor.axis_scale(1.0), 'deeper = smaller')
  corridor.free()


func test_board_strip_builds_one_cell_per_item() -> void:
  var strip: BoardStrip = preload('res://src/scenes/combat/board_strip.tscn').instantiate()
  _host(strip)
  strip.setup(_spawn(100.0, [ItemCatalog.WEAPON, ItemCatalog.ARMOR, ItemCatalog.POISON_DAGGER]))
  assert_eq(strip.get_node('Row').get_child_count(), 3, 'one cell per board item')


func test_board_strip_hp_text_tracks_actor() -> void:
  var strip: BoardStrip = preload('res://src/scenes/combat/board_strip.tscn').instantiate()
  _host(strip)
  var a := _spawn(100.0, [ItemCatalog.WEAPON])
  strip.setup(a)
  a.take_damage(40.0)
  strip._refresh_hp()   # the per-frame refresh, called directly — deterministic, no _process race
  assert_eq(strip.get_node('HP/Label').text, '60 / 100', 'HP text tracks the actor')


func test_board_strip_mouse_over_detects_a_cell() -> void:
  # The hover hit-test (the slow-mo intent's surface) uses each cell's global rect.
  var strip: BoardStrip = preload('res://src/scenes/combat/board_strip.tscn').instantiate()
  _host(strip)
  strip.setup(_spawn(100.0, [ItemCatalog.WEAPON]))
  await get_tree().process_frame   # let the container lay the cell out
  var cell: Control = strip.get_node('Row').get_child(0)
  var centre: Vector2 = cell.global_position + cell.size * 0.5
  assert_true(strip.mouse_over(centre), 'a point over a cell is detected')
  assert_false(strip.mouse_over(centre + Vector2(10000, 10000)), 'a far point is not')


func test_view_potion_slots_emit_the_throw_intent() -> void:
  var view: CombatViewFramed = preload('res://src/scenes/combat/combat_view_framed.tscn').instantiate()
  _host(view)
  var p := _spawn(100.0, [ItemCatalog.WEAPON])
  var e := _spawn(40.0, [ItemCatalog.ENEMY_CLAW])
  var cm := CombatManager.new(p, [e])
  cm.start()
  var potions: Array = [Consumable.new(ConsumableCatalog.get_def(ConsumableCatalog.HEALING_DRAUGHT))]
  view.bind(cm, p, potions)
  assert_eq(view.get_node('PlayerSide/Potions').get_child_count(), 1, 'one slot per potion')
  watch_signals(view)
  var slot: Button = view.get_node('PlayerSide/Potions').get_child(0)
  slot.pressed.emit()
  assert_signal_emitted_with_parameters(view, 'potion_thrown', [0])
  cm.free()


func test_item_pos_handles_a_source_less_delivery() -> void:
  # A thrown consumable's Delivery has source == null. The VFX wall calls item_pos
  # with it; without a guard that dereferences null.owner and crashes mid-fight the
  # moment a content author adds a travel>0 potion. It must resolve to the thrower.
  var view: CombatViewFramed = preload('res://src/scenes/combat/combat_view_framed.tscn').instantiate()
  _host(view)
  var p := _spawn(100.0, [ItemCatalog.WEAPON])
  var e := _spawn(40.0, [ItemCatalog.ENEMY_CLAW])
  var cm := CombatManager.new(p, [e])
  cm.start()
  view.bind(cm, p, [])
  var pos: Vector2 = view.item_pos(null)
  assert_ne(pos, Vector2.INF, 'a null source resolves to a real position (the player), not a crash')
  assert_eq(pos, view.actor_pos(p), 'the source-less projectile flies from the thrower (player)')
  cm.free()


func test_target_pos_resolves_an_item_target_to_its_cell() -> void:
  # Item-targeting effects (e.g. a random silence) land on an Item; the VFX wall asks the
  # layout for the target position. It must route an Item to its board cell, not crash on
  # a non-Actor (the wall calls target_pos, not actor_pos, for the destination).
  var view: CombatViewFramed = preload('res://src/scenes/combat/combat_view_framed.tscn').instantiate()
  _host(view)
  var p := _spawn(100.0, [ItemCatalog.WEAPON])
  var e := _spawn(40.0, [ItemCatalog.ENEMY_CLAW])
  var cm := CombatManager.new(p, [e])
  cm.start()
  view.bind(cm, p, [])
  var enemy_item: Item = e.board[0]
  assert_eq(view.target_pos(enemy_item), view.item_pos(enemy_item), 'an Item target routes to its cell')
  assert_eq(view.target_pos(e), view.actor_pos(e), 'an Actor target still routes to the actor')
  cm.free()


func test_framed_view_binds_a_fight_without_error() -> void:
  var view: CombatViewFramed = preload('res://src/scenes/combat/combat_view_framed.tscn').instantiate()
  _host(view)
  var p := _spawn(100.0, [ItemCatalog.WEAPON, ItemCatalog.ARMOR, ItemCatalog.POISON_DAGGER])
  var e := _spawn(40.0, [ItemCatalog.ENEMY_CLAW])
  var cm := CombatManager.new(p, [e])
  cm.start()
  view.bind(cm, p, [])
  assert_eq(view.get_node('PlayerSide/PlayerBoard/Row').get_child_count(), 3, 'player board built')
  assert_eq(view.get_node('EnemySide/EnemyStrips').get_child_count(), 1, 'one strip for the one enemy')
  cm.free()   # after_each dissolves the actors (breaks the Actor<->Item cycles)


func test_multi_actor_view_renders_every_enemy_and_ally() -> void:
  # The reachable case (the 2-grunt elite) + allies: a strip per enemy on the enemy side,
  # a strip per ally beside the player, and actor_pos resolves each to a distinct point.
  var view: CombatViewFramed = preload('res://src/scenes/combat/combat_view_framed.tscn').instantiate()
  _host(view)
  var p := _spawn(100.0, [ItemCatalog.WEAPON])
  var e1 := _spawn(40.0, [ItemCatalog.ENEMY_CLAW])
  var e2 := _spawn(40.0, [ItemCatalog.ENEMY_CLAW])
  var ally := _spawn(15.0, [ItemCatalog.ENEMY_CLAW])
  var cm := CombatManager.new(p, [e1, e2], 0, [ally])
  cm.start()
  view.bind(cm, p, [])
  assert_eq(view.get_node('EnemySide/EnemyStrips').get_child_count(), 2, 'a strip per enemy (the elite)')
  assert_eq(view.get_node('PlayerSide/AllyStrips').get_child_count(), 1, 'a strip for the ally')
  await wait_frames(2)   # let the containers lay the strips out so strip_centre is real
  # each enemy resolves to its own strip — the second grunt no longer collapses to the player
  assert_ne(view.actor_pos(e2), view.actor_pos(p), 'the second enemy is NOT at the player portrait')
  assert_ne(view.actor_pos(e1), view.actor_pos(e2), 'the two enemies are at distinct positions')
  cm.free()
