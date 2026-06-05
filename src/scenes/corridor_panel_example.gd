extends Control
## Worked example: how to drop corridor_panel.tscn into a real UI and drive it.
##
## The corridor lives inside corridor_panel.tscn (a SubViewportContainer that
## clips its overflow), framed by a themed Panel. Themed Buttons drive it through
## the CorridorRenderer interface — set_forward_held / set_back_held / set_blur —
## so nothing here knows or cares which renderer is inside the panel. Each button
## carries a UIJuice child for hover/press life. See docs/corridors/common.md.

# Reach into the instanced panel: panel root -> SubViewport -> the renderer.
@onready var _corridor: CorridorRenderer = $Frame/CorridorPanel/SubViewport/CorridorScaled
@onready var _blur_button: Button = $Controls/ButtonRow/BlurButton

var _blur_on: bool = false


func _ready() -> void:
  var back: Button = $Controls/ButtonRow/BackButton
  var fwd: Button = $Controls/ButtonRow/ForwardButton
  # button_down/up (not `pressed`) so HOLDING a button glides continuously.
  back.button_down.connect(func() -> void: _corridor.set_back_held(true))
  back.button_up.connect(func() -> void: _corridor.set_back_held(false))
  fwd.button_down.connect(func() -> void: _corridor.set_forward_held(true))
  fwd.button_up.connect(func() -> void: _corridor.set_forward_held(false))
  _blur_button.pressed.connect(_toggle_blur)

  # Verification helper: `--shot` captures a mid-glide frame then quits.
  if '--shot' in OS.get_cmdline_args() or '--shot' in OS.get_cmdline_user_args():
    _auto_shot()


func _toggle_blur() -> void:
  _blur_on = not _blur_on
  _corridor.set_blur(1.0 if _blur_on else 0.0)
  _blur_button.text = tr('Blur: On') if _blur_on else tr('Blur: Off')


func _auto_shot() -> void:
  _corridor.set_forward_held(true)  # engage motion so the corridor shows mid-glide
  await get_tree().create_timer(0.6).timeout
  await RenderingServer.frame_post_draw
  var img: Image = get_viewport().get_texture().get_image()
  img.save_png('user://shot.png')
  print('SHOT_SAVED:', ProjectSettings.globalize_path('user://shot.png'))
  get_tree().quit()
