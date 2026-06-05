class_name RelicDef
extends RefCounted
## A relic definition (content_prd, decision #23) — authored in GDScript, collected
## in RelicCatalog. Carries the Draftable definition-face (id / name / rarity) by
## composition. Phase 3 builds the simplest effect shape only: COMBAT_START_STATUS
## — apply a status to the player Actor when each fight begins. The other shapes
## (a triggered event-push Ticker, a direct run-state mod) arrive with the
## enchant / consumable fast-follow.

enum Kind { COMBAT_START_STATUS }
enum Rarity { COMMON, UNCOMMON, RARE }

var id: int = -1
var name_key: String = ''           # source English; displayed via tr() — localizable
var rarity: int = Rarity.COMMON     # feel-based for relics (content_prd), not a power ladder
var kind: int = Kind.COMBAT_START_STATUS
var status_type: int = -1           # StatusDef.Type applied at combat start
var status_count: float = 0.0       # stacks / pool applied
var panel_color: Color = Color.WHITE
