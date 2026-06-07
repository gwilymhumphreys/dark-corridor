class_name EventOptionDef
extends RefCounted
## One option of a non-combat EVENT encounter (encounter_prd) — a label + a direct outcome
## applied to the player run-state on pick. Authored in GDScript (#23). PLACEHOLDER effect
## set: player-Actor outcomes (heal / max-HP growth / damage). Relic/potion-granting
## outcomes route through the RunManager's run-state surface and are added with real
## event content. Player-facing `label_key` is localized via tr().

enum Effect { HEAL_FRACTION, MAX_HP_BONUS, DAMAGE }

var label_key: String = ''     # the option's button text (source English; tr())
var effect: int = Effect.HEAL_FRACTION
var amount: float = 0.0        # HEAL_FRACTION: fraction of max HP; MAX_HP_BONUS / DAMAGE: flat
