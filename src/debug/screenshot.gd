class_name Screenshot
extends RefCounted
## Saves `--shot` screenshots into the project's `screenshots/` folder (gitignored), so they can be
## opened from the project. Each file name ends with the date and time, so a later shot does not
## overwrite an earlier one. The folder holds a `.gdignore`, so Godot does not import the images.

const FOLDER: String = 'res://screenshots'


## Save the viewport's current frame as `<name>_<date>_<time>.png`, print `SHOT_SAVED:<path>`, and
## return the absolute path. Call after `await RenderingServer.frame_post_draw`.
static func save(viewport: Viewport, name: String) -> String:
  var folder: String = ProjectSettings.globalize_path(FOLDER)
  DirAccess.make_dir_recursive_absolute(folder)
  var gdignore: String = folder.path_join('.gdignore')
  if not FileAccess.file_exists(gdignore):
    FileAccess.open(gdignore, FileAccess.WRITE)
  var stamp: String = Time.get_datetime_string_from_system().replace('T', '_').replace(':', '-')
  var path: String = folder.path_join('%s_%s.png' % [name, stamp])
  viewport.get_texture().get_image().save_png(path)
  print('SHOT_SAVED:', path)
  return path
