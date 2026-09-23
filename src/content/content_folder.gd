class_name ContentFolder
## Loads authored content: every script under a `content/<kind>/` folder, subfolders included, is
## one definition (docs/design/authoring.md). Each script extends its def class and sets its fields
## in `_init()`, so creating it gives the definition. The catalogs call this to build themselves.


## Every definition under `root`, keyed by its `id`. A script that does not create an object with an
## `id`, or a second definition with an id already taken, pushes an error and is left out.
static func load_defs(root: String) -> Dictionary:
  var defs: Dictionary = {}
  for path: String in _script_paths(root):
    var script: Script = load(path)
    var def: Object = script.new() if script != null else null
    if def == null or not ('id' in def) or def.id == '':
      push_error('ContentFolder: %s does not make a definition with an id' % path)
      continue
    if defs.has(def.id):
      push_error('ContentFolder: id "%s" in %s is already used' % [def.id, path])
      continue
    defs[def.id] = def
  return defs


static func _script_paths(folder: String) -> Array[String]:
  var paths: Array[String] = []
  # list_directory also lists scripts correctly in an exported build, where they are remapped.
  for entry: String in ResourceLoader.list_directory(folder):
    if entry.ends_with('/'):
      paths.append_array(_script_paths(folder.path_join(entry.trim_suffix('/'))))
    elif entry.ends_with('.gd'):
      paths.append(folder.path_join(entry))
  paths.sort()
  return paths
