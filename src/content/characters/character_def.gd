class_name CharacterDef
extends RefCounted
## A playable character (design: portrait + signature starting relic + small starting
## item set). Per decision #27 each character draws from its OWN item pool — so a run's
## drafts stay focused while the game's range lives across the roster. Authored in
## GDScript (#23), collected in CharacterCatalog. The placeholder default ports the
## prototype seed; the owner authors the real characters (e.g. the Mushroom Druid).

var id: String = ''
var name_key: String = ''            # source English; displayed via tr() — localizable
var item_pool: Array = []            # this character's draftable item ids (#27); colorless is added at draw
var starting_item_ids: Array = []    # the run-start board, left-to-right
var starting_relic_id: String = ''   # the signature starting relic (the most build-defining — design)
var starting_potion_ids: Array = []  # run-start potions (design: usually 0; the seed carries one)
var starting_enchants: Array = []    # [{ 'item_index': int, 'enchant_id': String }] applied at start
