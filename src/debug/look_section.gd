class_name LookSection
extends VBoxContainer
## One section of the look panel (docs/systems/corridor_look.md): a header with an optional on/off
## switch and a title button that shows or hides the section's rows. Rows start hidden unless the
## section's effect is on.

@onready var _rows: VBoxContainer = $Rows


## Set the title. Call before adding the section to the tree.
func setup(title: String) -> void:
  var title_button: Button = $Header/Title
  title_button.text = title
  title_button.pressed.connect(_on_title_pressed)
  ($Header/Switch as CheckButton).visible = false


## Show the header switch, set to `on`, calling `changed(on: bool)` when toggled. A section that
## starts switched on starts expanded.
func set_switch(on: bool, changed: Callable) -> void:
  var switch: CheckButton = $Header/Switch
  switch.visible = true
  ($Rows as VBoxContainer).visible = on
  switch.set_pressed_no_signal(on)
  switch.toggled.connect(changed)


func add_row(row: LookRow) -> void:
  $Rows.add_child(row)


func _on_title_pressed() -> void:
  _rows.visible = not _rows.visible
