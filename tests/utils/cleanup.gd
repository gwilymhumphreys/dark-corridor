class_name TestCleanup
extends RefCounted
## Resets autoload / manager state between tests: frees the live run (Game), clears
## the autotest's Save.disabled, keeps Prefs off disk, and puts the authored text ladder back into
## the shared theme. Mirrors a-machine's
## TestCleanup pattern (docs/systems/testing.md). File is NOT named `test_*` so GUT does
## not collect it as a test case.

# Weak references to actors a test built outside a RunManager (a player or an ally handed to a
# CombatManager or Encounter). Their teardown keeps the player side intact on purpose, and in the
# game RunManager.teardown dissolves it at run end, so a test that drops one would leave its
# Actor<->Item cycle alive. Weak, so registering never keeps an actor alive or changes what a
# "frees after teardown" test sees.
static var _actors_to_dissolve: Array[WeakRef] = []

# The `IconSlots.CHOSEN_PATH` file as `snapshot_chosen_icons` found it, and whether it existed.
static var _had_chosen_icons: bool = false
static var _chosen_icons_text: String = ''


static func reset_all_managers() -> void:
  # StatusManager / Save / Draft are stateless. Game (the session singleton) holds
  # the live run — free it between tests so a leftover run can't bleed across.
  Game.reset()
  Save.disabled = false   # an autotest run may have set it (nosave); clear for the next test
  Prefs.disabled = true   # tests never write the prefs file to disk (in-memory + bus only)
  # The text ladder is written into the shared theme RESOURCE, so a test that changed the text size
  # would leave every later test measuring the wrong sizes. Put the authored ladder back.
  TextSize.apply(load(PrefsAutoload.THEME_PATH) as Theme, TextSize.DEFAULT_SCALE)
  DebugPanels.reset_settings()   # clamp off, scaled corridor, painted enemies
  _dissolve_registered_actors()


## Dissolve `actor` at the next reset_all_managers() if it is still alive then. Use it for
## actors a test builds without a RunManager, which is what dissolves the player and allies.
static func dissolve_at_reset(actor: Actor) -> void:
  if actor != null:
    _actors_to_dissolve.append(weakref(actor))


## Remembers `IconSlots.CHOSEN_PATH` so a test that changes an icon choice can put the file back.
## `IconSlots.set_icon` writes that file and `IconSlots.reset()` leaves it alone, so without this a
## choice made in one test is still on disk for the next run. Call it in `before_each`, and
## `restore_chosen_icons` in `after_each`.
static func snapshot_chosen_icons() -> void:
  _had_chosen_icons = FileAccess.file_exists(IconSlots.CHOSEN_PATH)
  _chosen_icons_text = ''
  if _had_chosen_icons:
    _chosen_icons_text = FileAccess.get_file_as_string(IconSlots.CHOSEN_PATH)


## Deletes `IconSlots.CHOSEN_PATH` and drops the in-memory choices, so every slot falls back to its
## default. Only for a test that needs "nothing is chosen"; call `snapshot_chosen_icons` first.
static func clear_chosen_icons() -> void:
  if FileAccess.file_exists(IconSlots.CHOSEN_PATH):
    DirAccess.remove_absolute(ProjectSettings.globalize_path(IconSlots.CHOSEN_PATH))
  IconSlots.reset()


## Puts `IconSlots.CHOSEN_PATH` back as `snapshot_chosen_icons` found it, deleting the file if
## there was none, and drops the in-memory choices so the next read re-reads the restored file.
static func restore_chosen_icons() -> void:
  if _had_chosen_icons:
    var file: FileAccess = FileAccess.open(IconSlots.CHOSEN_PATH, FileAccess.WRITE)
    file.store_string(_chosen_icons_text)
    file.close()
  elif FileAccess.file_exists(IconSlots.CHOSEN_PATH):
    DirAccess.remove_absolute(ProjectSettings.globalize_path(IconSlots.CHOSEN_PATH))
  IconSlots.reset()


static func _dissolve_registered_actors() -> void:
  for ref in _actors_to_dissolve:
    var actor: Actor = ref.get_ref()
    if actor != null:
      actor.dissolve()
  _actors_to_dissolve.clear()
