class_name InterfaceLookAutoload
extends Node
## Owns the interface look (docs/systems/interface_look.md): the material interface images are drawn
## through, its settings, defaults and reset, how they are written to and read from a look preset
## (docs/systems/look_presets.md), and copying settings to and from the corridor look. Registered as the
## `InterfaceLook` autoload, after `PrintLook` and before `DebugPanels`, which keeps the interface tab.

const EFFECTS_INCLUDE: ShaderInclude = preload('res://src/shaders/look_effects.gdshaderinc')
const PALETTE_INCLUDE: ShaderInclude = preload('res://src/shaders/palette_clamp.gdshaderinc')
## Picture wear's mark colours, set from `Colours` rather than by the look.
const COLOUR_UNIFORMS: Array[String] = ['picture_wear_dark_colour', 'picture_wear_light_colour']
## Palette clamp uniforms set from the Interface tab's palette rows and its dithering switch
## (`DebugPanels`), so they are not look settings.
const PALETTE_UNIFORMS: Array[String] = ['colour_count', 'perceptual', 'dithering']
## Effect groups in the shared include that the interface look shader does not use, so they are not
## settings.
const UNUSED_GROUPS: Array[String] = ['bloom']
## Instance uniforms set per node rather than on the material, so they are not settings either:
## `picture_zoom` is driven by `PortraitBreath` (docs/systems/ui_juice.md).
const NODE_UNIFORMS: Array[String] = ['picture_zoom']
## Switches left off on `element_material`, so an interface element keeps the colour the interface
## palette gave it. Everything else is set on every material.
const ELEMENT_OFF_UNIFORMS: Array[String] = ['grade_on', 'colour_ramp_on', 'posterize_on',
  'colour_fringe_on']
## Switches left off on `framed_material`: a picture inside a panel frame has the frame's panel wear
## around it (docs/systems/panel_wear.md), so it takes no picture wear of its own.
const FRAMED_OFF_UNIFORMS: Array[String] = ['picture_wear_on']

## The material every interface image is drawn through (interface_look.gdshader). Scenes use the same
## resource file, so changing it here changes every image.
var material: ShaderMaterial = preload('res://src/shaders/interface_look_material.tres')
## The same shader on the interface elements that are not pictures: the item value pills and the HP
## bars. It takes the same settings except `ELEMENT_OFF_UNIFORMS`, and no palette clamp colours are
## written to it, so its colours stay as the interface palette set them.
var element_material: ShaderMaterial = preload('res://src/shaders/interface_element_material.tres')
## The same shader on the pictures that sit inside a `PanelSlot` frame: the portraits and the item cell
## icons. It takes the same settings except `FRAMED_OFF_UNIFORMS`.
var framed_material: ShaderMaterial = preload('res://src/shaders/interface_framed_material.tres')
## The materials pictures are drawn through. The palette clamp and its dithering are written to these
## and not to `element_material`, whose colours stay as the interface palette set them.
var picture_materials: Array[ShaderMaterial] = [material, framed_material]

var _defaults: Dictionary = {}   # interface look uniform -> default value, read from the shader code


func _ready() -> void:
  _write_defaults()
  push_wear_colours()


## Set picture wear's mark colours from `Colours.UI_PANEL_WEAR` and `UI_PANEL_WEAR_LIGHT`, the same as
## panel wear. Called at start, and by `DebugPanels` after an interface palette is applied or reset.
func push_wear_colours() -> void:
  for look_material: ShaderMaterial in [material, element_material, framed_material]:
    look_material.set_shader_parameter('picture_wear_dark_colour', Colours.UI_PANEL_WEAR)
    look_material.set_shader_parameter('picture_wear_light_colour', Colours.UI_PANEL_WEAR_LIGHT)


## Set one interface look setting on every material. The switches in `ELEMENT_OFF_UNIFORMS` are left
## off on `element_material` and those in `FRAMED_OFF_UNIFORMS` on `framed_material`. Everything that
## changes a setting goes through here: the panel rows, presets, reset, the copy from the corridor look
## and `--interface-set=`.
func set_setting(uniform: String, value: Variant) -> void:
  material.set_shader_parameter(uniform, value)
  if not ELEMENT_OFF_UNIFORMS.has(uniform):
    element_material.set_shader_parameter(uniform, value)
  if not FRAMED_OFF_UNIFORMS.has(uniform):
    framed_material.set_shader_parameter(uniform, value)


## Every interface look setting with a default in the shared effects include, the palette clamp include
## (its dither pattern, size and supersample) or in the interface look shader's own picture wear
## (uniform name -> value), except the groups in `UNUSED_GROUPS`, the mark colours,
## `PALETTE_UNIFORMS` and `NODE_UNIFORMS`.
func defaults() -> Dictionary:
  if _defaults.is_empty():
    var code: String = EFFECTS_INCLUDE.code + '\n' + PALETTE_INCLUDE.code + '\n' + material.shader.code
    var skip: Array[String] = COLOUR_UNIFORMS.duplicate()
    skip.append_array(PALETTE_UNIFORMS)
    skip.append_array(NODE_UNIFORMS)
    var all: Dictionary = PrintLookAutoload._uniform_defaults(code, skip)
    for uniform: String in all:
      var unused: bool = false
      for group: String in UNUSED_GROUPS:
        if uniform.begins_with(group + '_'):
          unused = true
          break
      if not unused:
        _defaults[uniform] = all[uniform]
  return _defaults


## Every interface look effect back to its shader default, and the interface glow settings to theirs.
func reset() -> void:
  _write_defaults()
  InterfaceGlow.reset()


## Write every setting into a preset file, with the interface glow settings in their own section.
func write_look(file: ConfigFile) -> void:
  for uniform: String in defaults():
    file.set_value('interface_shader', uniform, material.get_shader_parameter(uniform))
  for property: String in InterfaceGlowAutoload.DEFAULTS:
    file.set_value('interface_glow', property, InterfaceGlow.setting(property))


## Set the interface look from a preset file written by `write_look`, starting from the defaults.
func read_look(file: ConfigFile) -> void:
  reset()
  var settings: Dictionary = defaults()
  for uniform: String in _section_keys(file, 'interface_shader'):
    if settings.has(uniform):
      set_setting(uniform, file.get_value('interface_shader', uniform))
  for property: String in _section_keys(file, 'interface_glow'):
    if InterfaceGlowAutoload.DEFAULTS.has(property):
      InterfaceGlow.settings[property] = file.get_value('interface_glow', property)
  InterfaceGlow.apply_settings()


## Set every interface look setting that the corridor look also has to the corridor look's current
## value.
func copy_from_corridor() -> void:
  var settings: Dictionary = defaults()
  for uniform: String in settings:
    if DebugPanels.look_defaults().has(uniform):
      set_setting(uniform, DebugPanels.world_material.get_shader_parameter(uniform))


## Set every corridor look setting that the interface look also has to the interface look's current
## value. The reverse of `copy_from_corridor`, writing into `DebugPanels.world_material`.
func copy_to_corridor() -> void:
  var settings: Dictionary = defaults()
  for uniform: String in settings:
    if DebugPanels.look_defaults().has(uniform):
      DebugPanels.world_material.set_shader_parameter(uniform, material.get_shader_parameter(uniform))


# Every uniform is set explicitly, so a saved look lists every one of them.
func _write_defaults() -> void:
  var settings: Dictionary = defaults()
  for uniform: String in settings:
    set_setting(uniform, settings[uniform])


func _section_keys(file: ConfigFile, section: String) -> PackedStringArray:
  return file.get_section_keys(section) if file.has_section(section) else PackedStringArray()
