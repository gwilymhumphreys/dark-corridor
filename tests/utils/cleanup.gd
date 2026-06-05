class_name TestCleanup
extends RefCounted
## Resets autoload / manager state between tests. Currently a stub — the combat
## spine's managers register their resets here as they're built. Mirrors
## a-machine's TestCleanup pattern (CLAUDE.md Testing). File is NOT named
## `test_*` so GUT does not collect it as a test case.


static func reset_all_managers() -> void:
  # No stateful managers to reset yet. As foundation autoloads land
  # (StatusManager is stateless; Save / Game gain state), reset them here.
  pass
