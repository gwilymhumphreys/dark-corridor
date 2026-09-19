class_name LookSection
extends VBoxContainer
## One section of a look tab of the debug panel (docs/systems/corridor_look.md): a header with an optional on/off
## switch and a title button that shows or hides the section's rows. Rows always start hidden; the
## title button shows and hides them.

@onready var _rows: VBoxContainer = $Rows


## Set the title. Call before adding the section to the tree.
func setup(title: String) -> void:
  var title_button: Button = $Header/Title
  title_button.text = title
  title_button.pressed.connect(_on_title_pressed)
  ($Header/Switch as CheckButton).visible = false


## Show the header switch, set to `on`, calling `changed(on: bool)` when toggled.
func set_switch(on: bool, changed: Callable) -> void:
  var switch: CheckButton = $Header/Switch
  switch.visible = true
  switch.set_pressed_no_signal(on)
  switch.toggled.connect(changed)


## Show or hide the section's rows without clicking the title. A tab with only one short section
## (the Icons tab) opens it, so there is nothing to click before its rows are usable.
func set_open(open: bool) -> void:
  ($Rows as VBoxContainer).visible = open


func add_row(row: LookRow) -> void:
  $Rows.add_child(row)


func _on_title_pressed() -> void:
  _rows.visible = not _rows.visible
