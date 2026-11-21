class_name EffectsPanel
extends LookPanel
## The Effects tab of the debug panel (docs/systems/debug_panel.md), opened with F6 by `DebugPanels`:
## the combat effects' look (docs/systems/interface_look.md#the-combat-effects), the hit effects being
## tried (docs/systems/vfx_driver.md), the corridor's hit lights (docs/systems/corridors/corridor_3d.md)
## and the paper burn (docs/systems/paper_burn.md). The filters the effects share with the pictures are
## on the Pictures tab.

## The paper burn's print frame settings: setting -> [min, max, step] ([] for a switch).
const PAPER_BURN_SETTINGS: Dictionary = {
  'Paper burn': {
    'paper_burn_duration': [0.2, 6.0, 0.1],
    'paper_burn_raggedness': [0.0, 40.0, 0.5],
    'paper_burn_detail': [2.0, 60.0, 0.5],
    'paper_burn_ember_width': [0.0, 12.0, 0.25],
    'paper_burn_char_width': [0.0, 20.0, 0.25],
    'paper_burn_scorch_width': [0.0, 60.0, 0.5],
    'paper_burn_brightness': [1.0, 6.0, 0.05],
    'paper_burn_dither': [],
    'paper_burn_palette': [],
    'paper_burn_particles': [],
  },
}


func rebuild() -> void:
  _built = true
  _clear_sections()
  _build_shader_sections(InterfaceLook.material, InterfaceLook.defaults(),
    func(group: String) -> bool: return group == 'effects')
  # TRIAL: the hit effects being tried (docs/systems/vfx_driver.md).
  var hits: LookSection = _add_section('Hit effect trials')
  var set_comets: Callable = func(new_value: Variant) -> void: VfxDriver.comet_projectiles = new_value
  hits.add_row(_make_row('Comet Projectiles', VfxDriver.comet_projectiles, [], set_comets))
  var set_pixel: Callable = func(new_value: Variant) -> void: VfxDriver.pixel_projectile = new_value
  hits.add_row(_make_row('Pixel Projectile', VfxDriver.pixel_projectile, ProjectilePixelDrawer.option_names(), set_pixel))
  var set_pixel_scale: Callable = func(new_value: Variant) -> void: VfxDriver.pixel_projectile_scale = new_value
  hits.add_row(_make_row('Pixel Projectile Scale', VfxDriver.pixel_projectile_scale, [1.0, 6.0, 1.0], set_pixel_scale))
  _build_property_section('Hit lights', HIT_LIGHT_PROPERTIES, DebugPanels.scene_values()[0], DebugPanels.corridor_settings)
  _build_print_sections(PAPER_BURN_SETTINGS)


func _section_title(group: String) -> String:
  if group == 'effects':
    return 'Combat effects (projectiles, impacts, damage numbers)'
  return super(group)
