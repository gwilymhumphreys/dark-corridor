extends GutTest
## Phase 4 Step 2 — the framed combat view components: the board strip building one cell per board item
## and tracking HP, and the framed view binding a fight without error. Presentation
## reads logic + writes nothing; these confirm the bind wiring, not the visuals (those
## are the `--shot` check).

var _nodes: Array = []
var _actors: Array = []


func before_each() -> void:
  TestCleanup.reset_all_managers()
  FixtureContent.install()   # add_item looks the created item up by id


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


func _spawn(hp: float, defs: Array) -> Actor:
  var a := Actor.new(hp)
  for def in defs:
    a.board.append(Item.new(def, a))
  _actors.append(a)
  return a


func _host(node: Node) -> Node:
  add_child(node)
  _nodes.append(node)
  return node


func test_enemy_hud_builds_one_cell_per_item() -> void:
  var hud: EnemyHud = preload('res://src/scenes/combat/enemy_hud.tscn').instantiate()
  _host(hud)
  hud.setup(_spawn(100.0, [FixtureItems.attack(), FixtureItems.shield(), FixtureItems.poison()]))
  assert_eq(hud.get_node('Items').get_child_count(), 3, 'one cell per board item')


func test_enemy_hud_hp_text_tracks_actor() -> void:
  var hud: EnemyHud = preload('res://src/scenes/combat/enemy_hud.tscn').instantiate()
  _host(hud)
  var a := _spawn(100.0, [FixtureItems.attack()])
  hud.setup(a)
  a.take_damage(40.0)
  hud._refresh_hp()   # the per-frame refresh, called directly — deterministic, no _process race
  assert_eq(hud.get_node('HpRow/HP/Label').text, '60 / 100', 'HP text tracks the actor')


func test_enemy_hud_status_icons_show_outside_set_statuses_only() -> void:
  # The mechanic statuses (shield, poison, …) read off the StatusNumbers beside the HP bar; the
  # status-icon row keeps showing only the outside-set statuses.
  var hud: EnemyHud = preload('res://src/scenes/combat/enemy_hud.tscn').instantiate()
  _host(hud)
  var a := _spawn(100.0, [FixtureItems.attack()])
  StatusManager.apply(a, ShieldStatus.ID, 5.0)
  StatusManager.apply(a, 'weak', 1.0)
  hud.setup(a)
  hud._refresh_statuses()
  assert_eq(hud.get_node('HpRow/Statuses').get_child_count(), 1,
      'shield is a mechanic (its number shows beside the HP bar), only weak gets an icon')


func test_ally_slot_builds_one_cell_per_item() -> void:
  var slot: AllySlot = preload('res://src/scenes/combat/ally_slot.tscn').instantiate()
  _host(slot)
  slot.setup(_spawn(15.0, [FixtureItems.attack()]))
  assert_eq(slot.get_node('Readout/Items').get_child_count(), 1, 'one cell per board item')


func test_ally_slot_mouse_over_detects_a_cell() -> void:
  # The hover hit-test (the slow-mo intent's surface) uses each cell's global rect.
  var slot: AllySlot = preload('res://src/scenes/combat/ally_slot.tscn').instantiate()
  _host(slot)
  slot.setup(_spawn(15.0, [FixtureItems.attack()]))
  await get_tree().process_frame   # let the container lay the cell out
  var cell: Control = slot.get_node('Readout/Items').get_child(0)
  var centre: Vector2 = cell.global_position + cell.size * 0.5
  assert_true(slot.mouse_over(centre), 'a point over a cell is detected')
  assert_false(slot.mouse_over(centre + Vector2(10000, 10000)), 'a far point is not')


func test_view_potion_slots_emit_the_throw_intent() -> void:
  var view: CombatViewFramed = preload('res://src/scenes/combat/combat_view_framed.tscn').instantiate()
  _host(view)
  var p := _spawn(100.0, [FixtureItems.attack()])
  var e := _spawn(40.0, [FixtureItems.attack()])
  var cm := CombatManager.new(p, [e])
  cm.start()
  var potions: Array = [Consumable.new(FixtureKit.potion())]
  view.bind(cm, p, potions)
  assert_eq(view.get_node('Items/Potions').get_child_count(), 1, 'one slot per potion')
  watch_signals(view)
  var slot: Button = view.get_node('Items/Potions').get_child(0)
  slot.pressed.emit()
  assert_signal_emitted_with_parameters(view, 'potion_thrown', [0])
  cm.free()


func test_item_pos_handles_a_source_less_delivery() -> void:
  # A thrown consumable's Delivery has source == null. The VFX wall calls item_pos
  # with it; without a guard that dereferences null.owner and crashes mid-fight the
  # moment a content author adds a travel>0 potion. It must resolve to the thrower.
  var view: CombatViewFramed = preload('res://src/scenes/combat/combat_view_framed.tscn').instantiate()
  _host(view)
  var p := _spawn(100.0, [FixtureItems.attack()])
  var e := _spawn(40.0, [FixtureItems.attack()])
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
  var p := _spawn(100.0, [FixtureItems.attack()])
  var e := _spawn(40.0, [FixtureItems.attack()])
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
  var p := _spawn(100.0, [FixtureItems.attack(), FixtureItems.shield(), FixtureItems.poison()])
  var e := _spawn(40.0, [FixtureItems.attack()])
  var cm := CombatManager.new(p, [e])
  cm.start()
  view.bind(cm, p, [])
  assert_eq(view.get_node('Items/Board/PlayerItems').get_child_count(), 3, 'player board built (the right-edge column)')
  assert_eq(view.get_node('EnemyArea/EnemyHuds').get_child_count(), 1, 'one HUD for the one enemy')
  cm.free()   # after_each dissolves the actors (breaks the Actor<->Item cycles)


func test_a_full_player_board_shrinks_its_cells() -> void:
  var view: CombatViewFramed = preload('res://src/scenes/combat/combat_view_framed.tscn').instantiate()
  _host(view)
  var items: Array = []
  for i in 60:
    items.append(FixtureItems.attack())
  var p := _spawn(100.0, items)
  var e := _spawn(40.0, [FixtureItems.attack()])
  var cm := CombatManager.new(p, [e])
  cm.start()
  view.bind(cm, p, [])
  var grid: GridContainer = view.get_node('Items/Board/PlayerItems')
  var cell: ItemCell = grid.get_child(0)
  assert_lt(cell.cell_size.x, ItemCell.CELL_SIZE.x, 'the cells shrink to fit 60 items')
  assert_eq((grid.get_child(59) as ItemCell).cell_size, cell.cell_size, 'every cell takes the same size')
  cm.free()


func test_enemy_huds_stay_hidden_until_the_fight_starts() -> void:
  # The HUDs are hidden through the approach and fade up when the run screen calls show_enemies.
  var view: CombatViewFramed = preload('res://src/scenes/combat/combat_view_framed.tscn').instantiate()
  _host(view)
  var p := _spawn(100.0, [FixtureItems.attack()])
  var e := _spawn(40.0, [FixtureItems.attack()])
  var cm := CombatManager.new(p, [e])
  cm.start()
  view.bind(cm, p, [])
  var hud: EnemyHud = view._enemy_huds[e]
  assert_false(hud.visible, 'the HUD is down while the enemy is still approaching')
  view.show_enemies()
  assert_true(hud.visible, 'the fight starting brings it up')
  cm.free()


func test_release_clears_the_cooldown_fills() -> void:
  # When the fight ends the board keeps its items, but the fills left at the last moment are cleared.
  var view: CombatViewFramed = preload('res://src/scenes/combat/combat_view_framed.tscn').instantiate()
  _host(view)
  var p := _spawn(100.0, [FixtureItems.attack()])
  var e := _spawn(40.0, [FixtureItems.attack()])
  var ally := _spawn(15.0, [FixtureItems.attack()])
  var cm := CombatManager.new(p, [e], 0, [ally])
  cm.start()
  view.bind(cm, p, [])
  var cell: ItemCell = view.get_node('Items/Board/PlayerItems').get_child(0)
  cell.item.cooldown.accum = cell.item.cooldown.threshold * 0.5   # part-way through its cooldown
  cell._update_cooldown()
  assert_false(cell.get_node('Cooldown').visible, 'no fill while the player is still walking in')
  view.begin_fight()   # the run screen calls this on arrival
  cell._update_cooldown()
  assert_true(cell.get_node('Cooldown').visible, 'a part-charged item shows its fill during the fight')
  view.release()
  cell._update_cooldown()
  assert_false(cell.get_node('Cooldown').visible, 'the fill is cleared once the fight is over')
  var ally_slot: AllySlot = view.get_node('Portraits/AllyLeft').get_child(0)
  for ally_cell in ally_slot._cells.values():
    assert_false((ally_cell as ItemCell).show_cooldown, 'ally item fills are cleared too')
  cm.free()


func test_view_without_a_fight_shows_no_cooldown_fills() -> void:
  var view: CombatViewFramed = preload('res://src/scenes/combat/combat_view_framed.tscn').instantiate()
  _host(view)
  var p := _spawn(100.0, [FixtureItems.attack()])
  view.bind(null, p, [])
  var cell: ItemCell = view.get_node('Items/Board/PlayerItems').get_child(0)
  assert_false(cell.get_node('Cooldown').visible, 'an event beat shows the board with no fill')


func test_multi_actor_view_renders_every_enemy_and_ally() -> void:
  # The reachable case (the 2-grunt elite) + an ally: a HUD per enemy over the corridor, an
  # ally slot flanking the player, and actor_pos resolves each to a distinct point.
  var view: CombatViewFramed = preload('res://src/scenes/combat/combat_view_framed.tscn').instantiate()
  _host(view)
  var p := _spawn(100.0, [FixtureItems.attack()])
  var e1 := _spawn(40.0, [FixtureItems.attack()])
  var e2 := _spawn(40.0, [FixtureItems.attack()])
  var ally := _spawn(15.0, [FixtureItems.attack()])
  var cm := CombatManager.new(p, [e1, e2], 0, [ally])
  cm.start()
  view.bind(cm, p, [])
  assert_eq(view.get_node('EnemyArea/EnemyHuds').get_child_count(), 2, 'a HUD per enemy (the elite)')
  assert_eq(view.get_node('Portraits/AllyLeft').get_child_count(), 1, 'the first ally fills the left slot')
  await wait_physics_frames(2)   # let the containers lay the widgets out so the centres are real
  # each enemy resolves to its own HUD — the second grunt no longer collapses to the player
  assert_ne(view.actor_pos(e2), view.actor_pos(p), 'the second enemy is NOT at the player portrait')
  assert_ne(view.actor_pos(e1), view.actor_pos(e2), 'the two enemies are at distinct positions')
  cm.free()


func test_corridor_backdrop_is_not_inspectable() -> void:
  # The corridor now fills most of the screen (corridor-forward layout). Hovering its backdrop
  # must NOT count as inspectable — otherwise the resting mouse holds the hover slow-mo on and
  # the whole fight crawls. Only the entities (HUDs / items / potions / ally slots) are.
  var view: CombatViewFramed = preload('res://src/scenes/combat/combat_view_framed.tscn').instantiate()
  _host(view)
  var p := _spawn(100.0, [FixtureItems.attack()])
  var e := _spawn(40.0, [FixtureItems.attack()])
  var cm := CombatManager.new(p, [e])
  cm.start()
  view.bind(cm, p, [])
  await wait_physics_frames(2)
  assert_false(view.mouse_over_inspectable(Vector2(200.0, 600.0)),
    'a point in the corridor backdrop (away from any HUD/item) is not inspectable — no perma-slow-mo')
  cm.free()


func test_reaped_enemy_drops_its_hud() -> void:
  # A slain enemy leaves combat (CombatManager reaps it); the view must drop its HUD, not keep
  # a stale one — every frame it reconciles the widget set against the live roster.
  var view: CombatViewFramed = preload('res://src/scenes/combat/combat_view_framed.tscn').instantiate()
  _host(view)
  var p := _spawn(1000.0, [FixtureItems.attack()])
  var e1 := _spawn(40.0, [FixtureItems.attack()])
  var e2 := _spawn(1000.0, [FixtureItems.attack()])
  var cm := CombatManager.new(p, [e1, e2])
  cm.start()
  view.bind(cm, p, [])
  assert_eq(view._enemy_huds.size(), 2, 'two HUDs at fight start')
  e1.take_damage(50.0)
  cm.sim_step()          # the CombatManager reaps the slain e1
  view._process(0.0)     # the view reconciles its widgets to the roster
  assert_eq(view._enemy_huds.size(), 1, 'the reaped enemy\'s HUD is dropped')
  assert_false(e1 in view._enemy_huds, 'and it was the dead one (the living enemy keeps its HUD)')
  cm.free()


func test_an_item_created_during_the_fight_gets_a_cell_marked_temporary() -> void:
  var view: CombatViewFramed = preload('res://src/scenes/combat/combat_view_framed.tscn').instantiate()
  _host(view)
  var p := _spawn(100.0, [FixtureItems.attack()])
  var e := _spawn(1000.0, [FixtureItems.attack()])
  var cm := CombatManager.new(p, [e])
  cm.start()
  view.bind(cm, p, [])
  cm.add_item(p, FixtureItems.attack().id)
  view._process(0.0)
  var chunk: Item = p.board[1]
  assert_true(view._player_cells.has(chunk), 'the created item has a cell')
  assert_true((view._player_cells[chunk] as ItemCell).get_node('TemporaryTag').visible, 'and it is marked temporary')
  assert_false((view._player_cells[p.board[0]] as ItemCell).get_node('TemporaryTag').visible, 'a drafted item is not')
  cm.remove_item(chunk)
  view._process(0.0)
  assert_false(view._player_cells.has(chunk), 'a removed item loses its cell')
  assert_eq(view._player_cells.size(), 1, 'the drafted item keeps its cell')
  cm.free()


func test_temporary_things_fade_off_the_board_when_the_fight_ends() -> void:
  # release() (the run screen's call at the end of a fight) starts the fade on everything that
  # only existed for this fight: a created item's cell and a summon token's slot. The logic keeps
  # both until the Combat manager's teardown, so the view drops them itself.
  var view: CombatViewFramed = preload('res://src/scenes/combat/combat_view_framed.tscn').instantiate()
  _host(view)
  var p := _spawn(100.0, [FixtureItems.attack()])
  var e := _spawn(1000.0, [FixtureItems.attack()])
  var cm := CombatManager.new(p, [e])
  cm.start()
  view.bind(cm, p, [])
  cm.add_item(p, FixtureItems.attack().id)
  cm.add_actor(_spawn(20.0, [FixtureItems.attack()]), true)   # a combat-scoped summon token
  view._process(0.0)
  var chunk: Item = p.board[1]
  assert_true(view._player_cells.has(chunk), 'the created item has a cell during the fight')
  assert_eq(view._ally_slots.size(), 1, 'the token has a slot during the fight')
  view.release()
  assert_false(view._player_cells.has(chunk), 'the created item loses its cell at the end of the fight')
  assert_eq(view._ally_slots.size(), 0, 'and the token loses its slot')
  assert_true(chunk in p.board, 'the item itself is still on the board until the fight is torn down')
  view._process(0.0)
  assert_false(view._player_cells.has(chunk), 'the per-frame sync does not rebuild a faded cell')
  assert_true(view._player_cells.has(p.board[0]), 'the drafted item keeps its cell')
  cm.free()


func test_a_thrown_consumable_starts_from_its_slot() -> void:
  var view: CombatViewFramed = preload('res://src/scenes/combat/combat_view_framed.tscn').instantiate()
  _host(view)
  var p := _spawn(100.0, [FixtureItems.attack()])
  var e := _spawn(40.0, [FixtureItems.attack()])
  var cm := CombatManager.new(p, [e])
  cm.start()
  var potion := Consumable.new(FixtureKit.potion())
  view.bind(cm, p, [potion])
  var slot: PotionSlot = view.get_node('Items/Potions').get_child(0)
  var centre: Vector2 = slot.get_global_rect().get_center()
  slot.pressed.emit()
  view.refresh_potions([])   # the throw removes the slot; its position is remembered
  assert_eq(view.consumable_pos(potion), centre, 'the effect starts from the slot it was thrown from')
  cm.throw_consumable(potion, p)
  assert_eq((cm.deliveries()[0] as Delivery).consumable, potion, 'the delivery carries the thrown consumable')
  cm.free()
