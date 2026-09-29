extends GutTest
## KeywordIcon.bbcode: an icon inside a line of rich text is drawn at the size asked for.

var _label: RichTextLabel = null


func after_each() -> void:
  if is_instance_valid(_label):
    _label.free()
  _label = null


func test_bbcode_icon_takes_the_size_asked_for() -> void:
  _label = RichTextLabel.new()
  _label.bbcode_enabled = true
  _label.fit_content = true
  _label.custom_minimum_size = Vector2(320, 0)
  add_child(_label)
  _label.text = 'a' + KeywordIcon.bbcode('attack', 20) + 'b'
  await get_tree().process_frame
  await get_tree().process_frame
  assert_lt(_label.get_content_height(), 48, 'the icon is about a line tall, not its full texture size')
