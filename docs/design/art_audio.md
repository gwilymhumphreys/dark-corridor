# Dark Corridor — Art Direction & Audio (Ongoing Vibes Doc)

This is a working doc, not a settled spec. Almost everything here is a current leaning to test in prototype, not a decision. Treat it that way — argue with it freely.

Companion to the design snapshot. This is the living capture of the look-and-feel thinking — art direction, visual readability, audio. Add to it as the vibes evolve.
Date: 2026-05-30, revised 2026-06-01 and 2026-09-16. The prototype is playable; the look is being explored in game.

Direction (exploring, 2026-09)

The chunky pixel-art direction is set aside. The goal is a distinctive look that fits the dark-fantasy theme, made with the assets and skills we have. That means existing art (the monster collection, icon packs, textures, UI packs), shaders, post-processing and palettes, not drawing or commissioning art. Nothing in the look is chosen yet.
Work order: get the corridor and enemies looking good first, then build the rest of the look around them.
Full-screen effects are welcome, for example CRT, colour treatments, bloom, and the post-processing in Slots & Daggers.
How options are judged: each option is built as a debug setting, screenshotted in the same real fight, and shown on one comparison page. The owner picks; options are not ranked for him.


Rendering & corridor

Godot 4. The corridor is a real 3D scene (decision #36): a row of modular corridor sections seen from a fixed camera. One steady light at the camera lights it, fading gradually to black. The light does not flicker; flicker remains only as a look setting. Walls are a tiling stone texture on code-built sections for now; a bought modular kit can replace them.
Enemies are flat painted images inside the 3D scene, lit by the same light, so they come out of the dark on the approach. They use hard-edged transparency (alpha scissor), not blended edges.
Hit lights: when a hit lands on an enemy, a short light in the effect's colour shows on it. On by default and subtle, kept until the effects are designed.
Resolution: everything renders at full monitor resolution. The corridor is not rendered at a low resolution; the Pixelate look setting keeps that available to try.
Movement feel: smooth-but-controlled advance, footfall audio. Each advance should read as walking forward, not as the scene rearranging itself. Discrete-step (Eye of the Beholder style) considered and set aside — the auto-advance design doesn’t give the player the causal hook that made discrete movement work in classic blobbers. (Camera bob: now that the movement is framed as a walk rather than a glide, a subtle bob is coherent — a true continuous glide and footfall bob don’t really coexist. Whether to keep the bob is a feel question for prototype.)


Visual style & tone

Dark fantasy / classic dungeon. Desaturated, low-value, restricted colour band. Dim crimson, deep iron, sickly moss — no bright neon anything. Darkest Dungeon / Mörk Borg as touchstones.
Tone resolution: atmosphere is dread, mechanics are juicy. The corridor and walk are heavy and oppressive; the cascade punches through with restrained but unmistakable flashes of colour, particle, sound. Contrast is where the satisfaction lives.
Failure mode to avoid: dread-without-juice — oppressive and miserable, no payoff. The dread baseline only works if the cascade punch lands against it. Target the games that nail the balance (Mörk Borg, Darkest Dungeon); plenty of indie horror doesn’t.


Art sources (exploring)

Where the packs live and how to find a file by name: docs/design/asset_library.md.

Monsters: painted images from the monster collection in ../dark-corridor-design/monsters/, used at their original resolution and cut out of their black backgrounds. The game has a sample of nine in assets/monsters/cut_out/. Fights pick one at random; which enemy uses which image is not content yet.
Corridor walls: one tiling stone texture for now. Candidate PSX-style modular kits are listed in docs/plans/full_res_art_palette_clamp_3d_corridor.md.
Icons: painted icons from the 6000 Fantasy Icons pack for items, potions, statuses and keywords, copied into assets/icons/. The agent picked a first icon for each; every pick is a placeholder for the owner to swap.
Portraits: painted character portraits from the same pack (the versions without backgrounds, so the worn frame shows behind the figure), copied into assets/portraits/. Each character and enemy has one, shown on the character select cards, the player's combat portrait and the ally slots. The agent picked each one; every pick is a placeholder for the owner to swap.
Interface frame: the Black and White UI pack, pixel art drawn at a ~360p scale on the full-resolution screen (decision #32). Panel frames will come from whichever UI theme is used.
Font: Rakkas, a smooth font, chosen from a screenshot comparison. Other shortlisted fonts can be tried from the debug panel. No pixel font by default.
No generative-AI assets.


Colour (exploring)

The world, the interface and the effects each have their own colours. There is no fixed colour count and no single shared palette.

World (corridor walls and enemy images): black and white, greyscale or very desaturated. Each act could have its own tint, but switching tints between acts is not a priority. A palette is applied to the corridor image only.
Interface: its own palette, with more hues than the world palette. A palette file recolours the theme and the game's named colours.
Effects (projectiles, damage numbers, hit lights): use the interface's effect colours rather than a palette of their own. This keeps them matching the item value badges and status swatches. They stand out against the desaturated corridor by hue and brightness, without needing strong saturation.
Readability limits: text and item icons must stay readable. Panels, buttons, text, tooltips, menus, the map strip and readouts take a palette only, with no shaders. The border around the play area, portraits, item cells and icons may also get shaders. Health bars, value badges, the cooldown sweep, potions, status swatches and the enemy name are undecided.


Looks being tried

Corridor look (F1 tab of the debug panel): post-processing on the corridor image only. It covers grade, colour ramp, halftone, hatching, edge lines, bloom, warp, scanlines, grain, vignette, posterize, pixelate, and the world palette with dithering, plus fog and glow. Example looks are saved as presets in assets/presets/; their names are placeholders. Dithering in motion is one of the things being judged.
Printed record sleeve (F4 Background tab): the screen background is drawn like a worn printed sleeve the owner liked. Rubbed edges, creases, subtle faded areas and sparse specks are on by default. Mottling, faint flecks and scratches were tried and removed.
The same print wear can be carried over the corridor, with its edge worn away, and the corridor moved in from the screen edges. The owner's saved defaults have both on. A rough border around the corridor and folds across the sheet are available but not judged yet. Two red two-ink corridor looks go with this style.
Interface look (F2 tab): the corridor look's effects on item and potion icons, portraits and health bars only, never on text or panels. Settings can be copied to and from the corridor look.
Glow: any interface element can be made to glow from code, following the image's shape, when there is a use for it (for example an item that fires). Nothing uses it yet.
Interface palettes: candidate palette files, saved with the world palette and the rest of the look in a preset, so the corridor and interface are judged together.


VFX

Effects are flat placeholder shapes and text for now, in the interface's effect colours (see Colour). Their final style is open. The earlier plan was pixel-snapped particles, banded light falloff and pixel-font damage numbers, and it belonged to the pixel-art direction. It needs rethinking for full-resolution painted art and post-processing.
Existing 2D VFX asset libraries (itch, paid packs) may cover most needs, recoloured to fit. Already know this market from AMTKAG.


Cascade / activation readability (the hardest open problem)
Parsing ~30 item activations in ~10 seconds. Key reframes:

Reads at two scales, serving different things. At speed: each fire feeds an aggregate/gestalt — screen pulses, enemy flinches, colour washes the board, feels like a machine going off. Not meant to be individually tracked. Under slow-mo-hover: the individual chain resolves crisply. Design every activation to do both.
The causal link (bar fills → thing happens) is bound by the item visibly reacting when it fires — not by a projectile. The forgotten half is the source: the item must recoil / flash / scale-punch and the bar resets with a snap. Silent-empty + damage-on-enemy = weak connection. Item emotes + same-coloured effect lands on the enemy simultaneously → the eye binds them. The colour vocabulary (red attack, per-effect status colours) is the binding agent.
Projectiles: lean toward always. Earlier draft was over-cautious here (worried 30-in-flight = crossing-line soup). Bazaar runs a coloured projectile per activation and stays readable even when its board goes fully chaotic — and our coupling of size→cooldown spreads activations across time (fast small items ping often, slow big items boom occasionally), so it’s rarely actually 30-at-once. So: coloured projectile per activation, colour by effect. Chaos at full speed is fine — it reads as the machine going off, not as something to track. The projectiles also fill otherwise-empty space between the boards and the enemy rather than occluding anything. Levers for tuning density if a peak burst tips into noise: small/fast/faded tracers for commons (read as flow), bigger/slower/crisp arcs for rares (read as punctuation). The one thing that must hold: under slow-mo-hover, the inspected chain resolves as one clean shot you can follow.
Numbers don’t carry the gestalt (30 stacking on one sprite = soup). Flinch + flash + thud carry the at-speed read; the number is for precision under hover.
Audio is the second readability channel. Per-effect-family activation sounds = you hear your build’s texture (poison hiss vs. fire crackle) without watching closely. Mixes without occluding the screen.
Atomic test first: does one item firing punch through the dark and feel satisfying against black? If a single activation doesn’t feel good, no cascade fixes it. Get one item right before worrying about 30.


Inventory presentation — living, not drifting
The “drifting / swarm of equipment” idea — items wandering and rotating freely — doesn’t fit: drift breaks spatial constancy, and rotation hides the panel colour and icon, which is what readability rests on. (Note: a fixed-position arrangement with hover-tilt is a different thing and is fine — see UI layout. The thing that doesn’t work is items actually moving around, not items having some life in place.)
What survives — the real want is aliveness, not drift:

Fixed, learnable, type-zoned grid (this is the readability — keep it).
Within each fixed slot the item breathes — subtle idle bob, hover-tilt on the focused item only, pulse on cooldown-fill, hard reaction on fire.
Motion = signal. A mostly-still board that erupts in localised motion as items fire is the cascade reading itself out through movement. If everything already drifts, firing doesn’t pop. Stillness makes the cascade legible as motion — same punch-against-baseline logic as dread-vs-juice. Tune the idle so the fire always out-punches it.
Watch: idle-drift vs. cooldown-fill collision — a bobbing item makes the fill harder to read, and the fill does real anticipatory work. The bar may want to be the one dead-still element on an otherwise-breathing item. Cheap to find out with one item on screen.

Item size as a tempo lever (to test)
Earlier draft argued hard for uniform slots and against size variation (spatial-packing friction). That was over-stated — especially since the layout may not be a packed grid at all (see UI layout). Current leaning: let item size encode tempo. Bigger = longer cooldown = bigger per-hit number, with the three coupled by balance so damage-per-second stays roughly flat across sizes. So size reads as weight/rhythm, not as a power tier — consistent with the flat-power identity (small fast item = rapid small hits; big slow item = occasional big hit; same DPS). Size, cooldown-bar length, swing rhythm, and the damage number then all tell the same story — reinforcing channels for one property.

Keep it to a small number of clearly-distinct sizes (~2–3, count TBD) so they read at a glance in a dense board.
Size is then spoken for by tempo — “which item is special / a build-anchor” has to live on a different channel (glow, key-item frame, panel treatment — not the border, which is rarity, and not size).
Watch (the kernel of truth in the old uniform-slot worry): if the layout is ever a packed grid, mixed sizes reintroduce arrangement friction. Figure out the actual layout when designing it.


UI layout

Screen real-estate split is open — two live approaches:

Small-game-area + large-UI dungeon-crawler frame (Wizardry / Eye of the Beholder / Bard’s Tale family) — combat scene small and framed, items dominating the surround. Gets a cramped corridor feel for free.
Full-screen scene (Topdeck Automat-style) — player character on-screen one side, enemy the other, items arranged around the player, UI integrated into the scene rather than framing it. More room to breathe; the cost is keeping the cramped tunnel feel, which a full-screen open scene loses. Substitutes for cramped if going this way: darkness-as-funnel (tight lit pool, edges crushed to black — arguably more oppressive than a frame, and on-brand) and board-density-as-crowding (the wall of items does the crowding, not the walls of stone). Untested — mock up one of each and see which actually feels more oppressive.


Item arrangement (open): type-zoned grid, or a loose arc around the character. Either way fixed positions with hover-tilt on the focused item — not drifting. Both can keep colour-zoning and a stable scan path; the arc just needs more deliberate zoning to stay as readable. Pure layout swap, no mechanical cost — try both with placeholder items.
Items zoned by type. Effect family is carried by a colour-coded value panel at the top of each item, extruding over the edge (red attack, yellow shield, green heal, per-effect colours for status applicators); the number on the panel is the effect value. Borders are spoken for by rarity — bronze / silver / gold for common / uncommon / rare. Items bigger than feels comfortable, so activations stay legible in a cascade.
Cooldown meters Bazaar-style (filling overlay), on enemy items too — mutual cooldowns visible on both boards is the visible-race feel.
Player portrait separate from the scene; HP shown as the portrait getting progressively more beaten-up at low HP, with the value as text. No frame.
Buttons: hovering does not change a button's size; hover is shown by the text colour only. Pressing squashes the button.


Audio
Soundtrack

Dungeon synth. Slow, droning, atmospheric, loop-friendly. Sits under the game.
Adaptive layering — thickens during combat, thins during the walk. No dramatic combat-theme cuts. Single base track per act, or one for the whole game.
Cheap to source: existing dungeon synth scene on Bandcamp, CC-licensed work, or commission a single ~30-min looped piece from a dungeon synth artist for modest money. Much cheaper than a generalist game composer, and better-fit.

In the project now: three dungeon synth packs by arnocyreus — Lordran Tapes, Outrider's Oath and Bonfires — converted to `.ogg` in `assets/music/` and shuffled by MusicManager (docs/systems/audio.md); see [asset_credits.md](asset_credits.md). They are a starting soundtrack, not a final pick — swapping or adding tracks is a matter of changing the files in that folder.

Sound design

Contrasts the soundtrack. Quiet, ambient, dripping under the synth during the walk. Combat sounds crunchy and punchy — item triggers, cooldown pings, damage thuds, status applications all distinct and readable. The audio version of the visual punch-against-dread principle.
Footfall audio sells corridor movement when the visuals alone might not.
Doubles as the second readability channel (see cascade readability above) — per-effect-family sounds let the player hear their build’s texture.


Cohesion across mixed asset sources

Cohesion comes from a spec, not single authorship: colours, lighting, post-processing and detail level. Hold every asset to it and multiple hands read as one. The monster images, wall textures, icons and interface pack all come from different sources and are expected to cohere through the world palette, the corridor look and the interface palette.
Darkness does coherence work. One light at the camera fading to black gives walls and enemy images one lighting read and hides mismatched lighting painted into the art.


Open items (prototype / mockup work)

Screen layout: full-screen scene vs. small framed window. Mock up one of each; decide on feel (cramped vs. breathing).
Item arrangement: type-zoned grid vs. arc-around-character. Fixed positions + hover-tilt either way. Try both with placeholder items.
UI implementation in Godot (when building): the frame wants Control nodes (anchoring, text tools); items want transform-driven nodes for free tilt/recoil. Items needing to travel over the frame is the constraint that picks the approach — cleanest options are all-2D (z-order, no viewport), or items-in-3D needing a single shared SubViewport to layer above a 2D frame, or rendering a 2D-authored frame to a viewport-texture on a 3D quad. These may look the same on screen; deciding factor is which is least annoying to author 60 items inside. Build 3 placeholder items in the simplest (all-2D) first.
Corridor look: which effects, world palette and dithering, including how dithering looks in motion.
Print style: whether the worn record-sleeve style carries on to the corridor border, folds and the rest of the interface.
Interface: which palette, and which interface parts take shaders.
Interface frame: stay pixel art, or change to fit the painted enemies and icons.
Corridor walls: textures or a bought modular kit.
Effects style at full resolution with post-processing.
One item firing against black — does it feel good? (Atomic readability test.)
One item on screen — idle-motion vs. cooldown-fill readability collision.
Walk pacing — can’t be dead time; atmosphere noises, environmental cues, occasional telegraph. Design once the look is settled.


Asset sources (candidate packs)

- Monster collection (painted): ../dark-corridor-design/monsters/
- 6000 Fantasy Icons (painted, 256px; armour, weapons, skills, professions, character portraits): ../dark-corridor-design/6000FantasyIcons/
- https://clockworkraven.itch.io/raven-fantasy-icons (pixel art)
- https://toffeecraft.itch.io/ui
- Corridor kits: see docs/plans/full_res_art_palette_clamp_3d_corridor.md


End of vibes capture. Ongoing — add to it. The firmest bits are Godot, the 3D corridor and dungeon synth; the look itself is still being explored.
