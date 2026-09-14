class_name PaletteLoader
extends RefCounted
## Reads a palette file into a list of colours, for the palette clamp (docs/systems/palette_clamp.md).
##
## Two formats:
##   - Lospec PNG strips: square swatches in one row. The swatch size is the image height, and
##     each swatch's centre pixel is its colour.
##   - GIMP `.gpl` text files: a header, then one `R G B name` line per colour. Lines starting
##     with `#` are comments.
##
## Files are read with FileAccess, which works in debug runs. Exported builds are not supported.


## The colours in the palette file at `path` (a `.png` or `.gpl`), or an empty array if the file
## is missing or in an unknown format.
static func load_palette(path: String) -> PackedColorArray:
  var extension: String = path.get_extension().to_lower()
  if extension == 'png':
    return _load_png_strip(path)
  if extension == 'gpl':
    return _load_gpl(path)
  push_warning('[PaletteLoader] unknown palette format: ' + path)
  return PackedColorArray()


## Every palette file under `root`, as paths. Files directly in `root` come first, then each
## subfolder's files under that subfolder's name. Returns {folder name: Array[String]}, with ''
## for `root` itself; keys are in display order.
static func find_palettes(root: String) -> Dictionary:
  var groups: Dictionary = {'': _palette_files_in(root)}
  var dir: DirAccess = DirAccess.open(root)
  if dir == null:
    return groups
  var folders: PackedStringArray = dir.get_directories()
  folders.sort()
  for folder: String in folders:
    var files: Array[String] = _palette_files_in(root.path_join(folder))
    if not files.is_empty():
      groups[folder] = files
  return groups


static func _palette_files_in(folder: String) -> Array[String]:
  var files: Array[String] = []
  var dir: DirAccess = DirAccess.open(folder)
  if dir == null:
    return files
  var names: PackedStringArray = dir.get_files()
  names.sort()
  for file_name: String in names:
    var extension: String = file_name.get_extension().to_lower()
    if extension == 'png' or extension == 'gpl':
      files.append(folder.path_join(file_name))
  return files


static func _load_png_strip(path: String) -> PackedColorArray:
  var colours: PackedColorArray = PackedColorArray()
  var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
  if bytes.is_empty():
    push_warning('[PaletteLoader] cannot read ' + path)
    return colours
  var image: Image = Image.new()
  if image.load_png_from_buffer(bytes) != OK:
    push_warning('[PaletteLoader] not a PNG: ' + path)
    return colours
  var swatch: int = image.get_height()
  if swatch <= 0:
    return colours
  var count: int = image.get_width() / swatch
  for i in count:
    var colour: Color = image.get_pixel(i * swatch + swatch / 2, swatch / 2)
    colour.a = 1.0
    colours.append(colour)
  return colours


static func _load_gpl(path: String) -> PackedColorArray:
  var colours: PackedColorArray = PackedColorArray()
  var file: FileAccess = FileAccess.open(path, FileAccess.READ)
  if file == null:
    push_warning('[PaletteLoader] cannot read ' + path)
    return colours
  while not file.eof_reached():
    var line: String = file.get_line().strip_edges()
    if line.is_empty() or line.begins_with('#'):
      continue
    var fields: PackedStringArray = line.replace('\t', ' ').split(' ', false)
    if fields.size() < 3:
      continue
    if not (fields[0].is_valid_int() and fields[1].is_valid_int() and fields[2].is_valid_int()):
      continue   # header lines: 'GIMP Palette', 'Name: ...', 'Columns: ...'
    colours.append(Color8(fields[0].to_int(), fields[1].to_int(), fields[2].to_int()))
  return colours


## `colour` in the OKLab perceptual colour space (lightness, green-red, blue-yellow). The palette
## clamp shader has the same conversion for screen pixels; keep the two in step.
static func to_oklab(colour: Color) -> Vector3:
  var r: float = _srgb_to_linear(colour.r)
  var g: float = _srgb_to_linear(colour.g)
  var b: float = _srgb_to_linear(colour.b)
  var l: float = pow(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b, 1.0 / 3.0)
  var m: float = pow(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b, 1.0 / 3.0)
  var s: float = pow(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b, 1.0 / 3.0)
  return Vector3(
    0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
    1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
    0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
  )


static func _srgb_to_linear(channel: float) -> float:
  if channel <= 0.04045:
    return channel / 12.92
  return pow((channel + 0.055) / 1.055, 2.4)
