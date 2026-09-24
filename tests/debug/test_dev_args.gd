extends GutTest
## DevArgs reads start-up arguments in both value forms (docs/systems/dev_tools.md).


func test_value_reads_the_equals_form() -> void:
  assert_eq(DevArgs.value_in(['--character=smith'], '--character'), 'smith')


func test_value_reads_the_space_form() -> void:
  assert_eq(DevArgs.value_in(['--allies', '2', '--shot'], '--allies'), '2')


func test_value_does_not_take_the_next_flag() -> void:
  assert_eq(DevArgs.value_in(['--allies', '--shot'], '--allies', '0'), '0')


func test_value_falls_back_when_absent_or_last() -> void:
  assert_eq(DevArgs.value_in(['--shot'], '--shot-delay', '1.5'), '1.5')
  assert_eq(DevArgs.value_in(['--shot-delay'], '--shot-delay', '1.5'), '1.5')


func test_value_does_not_match_a_longer_name() -> void:
  assert_eq(DevArgs.value_in(['--shot-delay=6'], '--shot', 'none'), 'none')


func test_values_collects_every_repeat() -> void:
  var found: PackedStringArray = DevArgs.values_in(['--set=a=1', '--settings', '--set=b=2', '--corridor-set=c=3'], '--set')
  assert_eq(Array(found), ['a=1', 'b=2'])
