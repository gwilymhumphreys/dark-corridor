class_name TestCleanup
extends RefCounted
## Resets autoload / manager state between tests: frees the live run (Game), clears
## the autotest's Save.disabled, and keeps Prefs off disk. Mirrors a-machine's
## TestCleanup pattern (CLAUDE.md Testing). File is NOT named `test_*` so GUT does
## not collect it as a test case.

# Weak references to actors a test built outside a RunManager (a player or an ally handed to a
# CombatManager or Encounter). Their teardown keeps the player side intact on purpose, and in the
# game RunManager.teardown dissolves it at run end, so a test that drops one would leave its
# Actor<->Item cycle alive. Weak, so registering never keeps an actor alive or changes what a
# "frees after teardown" test sees.
static var _actors_to_dissolve: Array[WeakRef] = []


static func reset_all_managers() -> void:
  # StatusManager / Save / Draft are stateless. Game (the session singleton) holds
  # the live run — free it between tests so a leftover run can't bleed across.
  Game.reset()
  Save.disabled = false   # an autotest run may have set it (nosave); clear for the next test
  Prefs.disabled = true   # tests never write the prefs file to disk (in-memory + bus only)
  DebugPanels.reset_settings()   # clamp off, scaled corridor, painted enemies
  _dissolve_registered_actors()


## Dissolve `actor` at the next reset_all_managers() if it is still alive then. Use it for
## actors a test builds without a RunManager, which is what dissolves the player and allies.
static func dissolve_at_reset(actor: Actor) -> void:
  if actor != null:
    _actors_to_dissolve.append(weakref(actor))


static func _dissolve_registered_actors() -> void:
  for ref in _actors_to_dissolve:
    var actor: Actor = ref.get_ref()
    if actor != null:
      actor.dissolve()
  _actors_to_dissolve.clear()
