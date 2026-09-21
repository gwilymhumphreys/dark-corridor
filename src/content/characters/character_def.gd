class_name CharacterDef
extends RefCounted
## A playable character (design: portrait + signature starting relic + small starting
## item set). Per decision #27 each character draws from its OWN item pool — so a run's
## drafts stay focused while the game's range lives across the roster. Authored in
## GDScript (#23), collected in CharacterCatalog. The placeholder default ports the
## prototype seed; the owner authors the real characters (e.g. the Spore Druid).

var id: String = ''
var name_key: String = ''            # the character's personal name; source English, displayed via tr()
var subtitle_key: String = ''        # the role line under the name (e.g. 'Rot Shepherd'); tr(), '' = none
var portrait: String = ''            # res:// path of the character's portrait (assets/portraits/characters/); empty = none
# The folder under assets/sound-effects/ whose recordings play when this character is hit
# (docs/systems/audio.md). Empty = the shared combat/hurt folder.
var hurt_sound: String = ''
var item_pool: Array = []            # this character's draftable item ids (#27); colorless is added at draw
var starting_item_ids: Array = []    # the run-start board, left-to-right; ignored when starting_item_types is set
# The run-start board as TYPE constraints instead of fixed ids: one random item of each listed
# ItemType, drawn from item_pool on the run RNG, so every run opens differently. Repeating a type
# asks for two of it, and each slot draws a DISTINCT item. Empty = use starting_item_ids.
var starting_item_types: Array = []
var starting_relic_id: String = ''   # the signature starting relic (the most build-defining — design)
var starting_potion_ids: Array = []  # run-start potions (design: usually 0; the seed carries one)
var starting_enchants: Array = []    # [{ 'item_index': int, 'enchant_id': String }] applied at start
var stride_length: float = 0.65      # metres covered per footstep; sets the walking pace
