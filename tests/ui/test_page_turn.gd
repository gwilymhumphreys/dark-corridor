extends GutTest
## The page turn between screens (docs/systems/page_turn.md): the page's shape as it turns, which way
## each screen change turns, and that nothing turns in a run with no screen.

const LENGTH: float = 1280.0


func _curve_length(points: PackedVector2Array) -> float:
  var total: float = 0.0
  for i: int in range(1, points.size()):
    total += points[i].distance_to(points[i - 1])
  return total


func test_the_page_starts_flat_where_it_lies() -> void:
  var points: PackedVector2Array = PageTurn.page_curve(0.0, LENGTH)
  assert_eq(points.size(), PageTurnAutoload.SEGMENTS + 1, 'one point more than the pieces')
  assert_eq(points[0], Vector2.ZERO, 'it starts at the hinge')
  assert_almost_eq(points[-1].x, LENGTH, 0.01, 'the free edge is a page width away')
  assert_almost_eq(points[-1].y, 0.0, 0.01, 'flat on the screen')


func test_the_page_ends_flat_on_the_other_side() -> void:
  var points: PackedVector2Array = PageTurn.page_curve(1.0, LENGTH)
  assert_almost_eq(points[-1].x, -LENGTH, 0.01, 'the free edge lies a page width past the hinge')
  for point: Vector2 in points:
    assert_almost_eq(point.y, 0.0, 0.01, 'flat on the screen')


func test_the_page_keeps_its_length_and_stays_above_the_screen_while_it_turns() -> void:
  for progress: float in [0.2, 0.5, 0.8]:
    var points: PackedVector2Array = PageTurn.page_curve(progress, LENGTH)
    assert_almost_eq(_curve_length(points), LENGTH, 0.01, 'the page does not stretch at %s' % progress)
    var lowest: float = 0.0
    for point: Vector2 in points:
      lowest = minf(lowest, point.y)
    assert_gte(lowest, 0.0, 'the page never goes through the screen at %s' % progress)
  assert_gt(PageTurn.page_curve(0.5, LENGTH)[-1].y, LENGTH * 0.5, 'halfway through it stands up')


func test_screen_changes_turn_the_page_the_right_way() -> void:
  var phase: Dictionary = GameManagerAutoload.Phase
  assert_eq(MainController._turn_direction(phase.TITLE, phase.RUN), PageTurnAutoload.Direction.FORWARD, 'starting a run')
  assert_eq(MainController._turn_direction(phase.DEATH, phase.RUN), PageTurnAutoload.Direction.FORWARD, 'a new run after dying')
  assert_eq(MainController._turn_direction(phase.RUN, phase.TITLE), PageTurnAutoload.Direction.BACK, 'quitting to the title')
  assert_eq(MainController._turn_direction(phase.WIN, phase.TITLE), PageTurnAutoload.Direction.BACK, 'the title after a win')
  assert_eq(MainController._turn_direction(phase.RUN, phase.DEATH), 0, 'no turn to the outcome screen')
  assert_eq(MainController._turn_direction(phase.BOOT, phase.TITLE), 0, 'no turn at start-up')


func test_nothing_is_captured_or_turned_without_a_screen() -> void:
  assert_false(PageTurn.can_turn(), 'the tests run headless')
  await PageTurn.capture()
  assert_false(PageTurn.has_capture(), 'no image is taken')
