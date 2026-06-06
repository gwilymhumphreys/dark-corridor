class_name RelicDef
extends RefCounted
## A relic definition (content_prd, decision #23) — authored in GDScript, collected
## in RelicCatalog. Carries the Draftable definition-face (id / name / rarity) by
## composition. Two effect shapes built:
##   COMBAT_START_STATUS — apply a status to the player Actor at each fight start
##     (re-applied every fight; the RunManager does it in _apply_relics_to_player).
##   MAX_HP_BONUS — a direct run-state mod applied ONCE on grant (baked into the saved
##     snapshot's max_hp; never re-applied on rehydrate). The design's max-HP-via-relics.
## The triggered event-push Ticker shape arrives later.

enum Kind { COMBAT_START_STATUS, MAX_HP_BONUS }
enum Rarity { COMMON, UNCOMMON, RARE }

var id: int = -1
var name_key: String = ''           # source English; displayed via tr() — localizable
var rarity: int = Rarity.COMMON     # feel-based for relics (content_prd), not a power ladder
var kind: int = Kind.COMBAT_START_STATUS
var status_type: int = -1           # StatusDef.Type applied at combat start (COMBAT_START_STATUS)
var status_count: float = 0.0       # stacks / pool applied (COMBAT_START_STATUS)
var max_hp_bonus: float = 0.0       # max-HP added on grant (MAX_HP_BONUS)
var panel_color: Color = Color.WHITE
