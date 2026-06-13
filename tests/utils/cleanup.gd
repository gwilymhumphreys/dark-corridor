class_name TestCleanup
extends RefCounted
## Resets autoload / manager state between tests: frees the live run (Game), clears
## the autotest's Save.disabled, and keeps Prefs off disk. Mirrors a-machine's
## TestCleanup pattern (CLAUDE.md Testing). File is NOT named `test_*` so GUT does
## not collect it as a test case.


static func reset_all_managers() -> void:
  # StatusManager / Save / Draft are stateless. Game (the session singleton) holds
  # the live run — free it between tests so a leftover run can't bleed across.
  Game.reset()
  Save.disabled = false   # an autotest run may have set it (nosave); clear for the next test
  Prefs.disabled = true   # tests never write the prefs file to disk (in-memory + bus only)
