class_name EventOptionDef
extends RefCounted
## One option of a non-combat EVENT encounter (docs/systems/encounter.md) — a label + a direct outcome
## applied to the run-state on pick. Authored in GDScript (#23). PLACEHOLDER effect set:
## player-Actor outcomes (heal / max-HP growth / damage) AND recruiting a run-scoped ally
## (ADD_ALLY — the event-driven ally-acquisition path). Player-Actor effects are applied by
## the Encounter (it holds the player); ADD_ALLY is applied by the RunManager (it owns the
## ally roster + snapshot), which intercepts the pick before delegating. Relic/potion-granting
## outcomes route through the RunManager's surface too, added with real event content.
## Player-facing `label_key` is localized via tr().

enum Effect { HEAL_FRACTION, MAX_HP_BONUS, DAMAGE, ADD_ALLY }

var label_key: String = ''     # the option's button text (source English; tr())
var effect: int = Effect.HEAL_FRACTION
var amount: float = 0.0        # HEAL_FRACTION: fraction of max HP; MAX_HP_BONUS / DAMAGE: flat
var ally_def_id: String = ''   # ADD_ALLY: the EnemyCatalog def id the recruited ally is built from
