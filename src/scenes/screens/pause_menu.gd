class_name PauseMenu
extends CanvasLayer
## The in-run pause overlay (ui_layout_prd). A CanvasLayer ABOVE the HUD: an opaque
## centered panel over the frozen run — no translucent scrim (alpha breaks the
## pixel-art aesthetic; CLAUDE.md). Its full-rect Catcher (mouse_filter STOP) swallows
## input so the paused combat/HUD can't be clicked through. It emits the two intents;
## the run screen owns the actual pause/resume gate + the quit routing.

signal resume_pressed
signal settings_pressed
signal quit_pressed

@onready var _resume_button: Button = $Catcher/Panel/Menu/ResumeButton
@onready var _settings_button: Button = $Catcher/Panel/Menu/SettingsButton
@onready var _quit_button: Button = $Catcher/Panel/Menu/QuitButton


func _ready() -> void:
  _resume_button.pressed.connect(func() -> void: resume_pressed.emit())
  _settings_button.pressed.connect(func() -> void: settings_pressed.emit())
  _quit_button.pressed.connect(func() -> void: quit_pressed.emit())
