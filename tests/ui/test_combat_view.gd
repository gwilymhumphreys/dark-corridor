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
  strip.setup(_spawn(100.0, [ItemCatalog.Id.WEAPON, ItemCatalog.Id.ARMOR, ItemCatalog.Id.POISON_DAGGER]))
  assert_eq(strip.get_node('Row').get_child_count(), 3, 'one cell per board item')


func test_board_strip_hp_text_tracks_actor() -> void:
  var strip: BoardStrip = preload('res://src/scenes/combat/board_strip.tscn').instantiate()
  _host(strip)
  var a := _spawn(100.0, [ItemCatalog.Id.WEAPON])
  strip.setup(a)
  a.take_damage(40.0)
  await get_tree().process_frame   # let _process refresh the label
  assert_eq(strip.get_node('HP/Label').text, '60 / 100', 'HP text tracks the actor')


func test_framed_view_binds_a_fight_without_error() -> void:
  var view: CombatViewFramed = preload('res://src/scenes/combat/combat_view_framed.tscn').instantiate()
  _host(view)
  var p := _spawn(100.0, [ItemCatalog.Id.WEAPON, ItemCatalog.Id.ARMOR, ItemCatalog.Id.POISON_DAGGER])
  var e := _spawn(40.0, [ItemCatalog.Id.ENEMY_CLAW])
  var cm := CombatManager.new(p, [e])
  cm.start()
  view.bind(cm, p, e, [])
  assert_eq(view.get_node('PlayerSide/PlayerBoard/Row').get_child_count(), 3, 'player board built')
  assert_eq(view.get_node('EnemySide/EnemyBoard/Row').get_child_count(), 1, 'enemy board built')
  cm.free()   # after_each dissolves the actors (breaks the Actor<->Item cycles)
