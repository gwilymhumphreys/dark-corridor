extends SceneTree
## Cuts the painted monster samples out of their black backgrounds (docs/systems/run_screen.md,
## "Enemy-in-corridor occupant"). Run with:
##
##   godot --headless --path . --script res://tools/cut_out_monsters.gd -- [--cutoff=0.04] [--ramp=0.12] [--out=res://assets/monsters/cut_out]
##
## then `godot --headless --path . --import`.
##
## For each image in `assets/monsters/`, a pixel's opacity comes from its brightest colour channel:
## transparent at or below `cutoff`, fully opaque at `cutoff + ramp` (both 0 to 1). The paintings
## were drawn over black, so a partly transparent pixel is brightened by the same factor, which
## stops edges and glows from getting a dark outline. Each image is cropped to its visible pixels
## plus `MARGIN` and saved as a PNG. A new PNG also gets an `.import` file with mipmaps on, like the
## originals.

const SOURCE_FOLDER: String = 'res://assets/monsters'
const DEFAULT_OUT: String = 'res://assets/monsters/cut_out'
const MARGIN: int = 8


func _init() -> void:
  var cutoff: float = 0.04
  var ramp: float = 0.12
  var out: String = DEFAULT_OUT
  for arg: String in OS.get_cmdline_user_args():
    if arg.begins_with('--cutoff='):
      cutoff = float(arg.get_slice('=', 1))
    elif arg.begins_with('--ramp='):
      ramp = float(arg.get_slice('=', 1))
    elif arg.begins_with('--out='):
      out = arg.get_slice('=', 1)
  DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
  for file_name: String in DirAccess.get_files_at(SOURCE_FOLDER):
    if not (file_name.ends_with('.png') or file_name.ends_with('.jpg')):
      continue
    var image: Image = Image.load_from_file(ProjectSettings.globalize_path(SOURCE_FOLDER.path_join(file_name)))
    if image == null:
      push_error('Could not load %s' % file_name)
      continue
    cut_out(image, cutoff, ramp)
    var used: Rect2i = image.get_used_rect()
    if used.has_area():
      image = image.get_region(used.grow(MARGIN).intersection(Rect2i(Vector2i.ZERO, image.get_size())))
    var target: String = out.path_join(file_name.get_basename() + '.png')
    image.save_png(ProjectSettings.globalize_path(target))
    _write_import_file(target)
    print('CUT_OUT %s %dx%d' % [target, image.get_width(), image.get_height()])
  quit()


## Set each pixel's opacity from its brightest channel and brighten partly transparent pixels.
## `image` is converted to RGBA8 in place.
static func cut_out(image: Image, cutoff: float, ramp: float) -> void:
  image.convert(Image.FORMAT_RGBA8)
  var data: PackedByteArray = image.get_data()
  var low: float = cutoff * 255.0
  var span: float = maxf(ramp * 255.0, 1.0)
  for i in range(0, data.size(), 4):
    var brightest: int = maxi(data[i], maxi(data[i + 1], data[i + 2]))
    var alpha: float = clampf((float(brightest) - low) / span, 0.0, 1.0)
    if alpha <= 0.0:
      data[i] = 0
      data[i + 1] = 0
      data[i + 2] = 0
      data[i + 3] = 0
      continue
    if alpha < 1.0:
      data[i] = mini(roundi(data[i] / alpha), 255)
      data[i + 1] = mini(roundi(data[i + 1] / alpha), 255)
      data[i + 2] = mini(roundi(data[i + 2] / alpha), 255)
    data[i + 3] = roundi(alpha * 255.0)
  image.set_data(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8, data)


# Mipmaps on, as for the originals (distant enemies are drawn small). Godot fills in the rest on
# import. An existing file is left alone.
static func _write_import_file(target: String) -> void:
  var path: String = ProjectSettings.globalize_path(target + '.import')
  if FileAccess.file_exists(path):
    return
  var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
  file.store_string('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\nmipmaps/generate=true\n')
  file.close()
