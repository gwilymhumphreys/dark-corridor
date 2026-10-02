class_name RestOverlay
extends Control
## The rest panel (docs/systems/run_screen.md): a REST encounter's name, its text and how much health
## the rest restored, with a Continue button. The heal has already been applied when the panel opens
## (Encounter.begin); Continue emits `continued`, and the run screen moves on. Reads the live
## Encounter; writes nothing. Text localized.

signal continued()

@onready var _title: Label = $Panel/Title
@onready var _prose: Label = $Panel/Prose
@onready var _healed: Label = $Panel/Healed


func setup(enc: Encounter) -> void:
  _title.text = tr(enc.def.name_key)
  _prose.text = tr(enc.def.prose_key)
  if enc.healed > 0:
    _healed.text = tr('You recover {0} health.').format([enc.healed])
  else:
    _healed.text = tr('You are already at full health.')


func _on_continue_pressed() -> void:
  continued.emit()
