# Dark Corridor — Art Direction & Audio (Ongoing Vibes Doc)

This is a working doc, not a settled spec. Almost everything here is a current leaning to test in prototype, not a decision. Treat it that way — argue with it freely.

Companion to the design snapshot. This is the living capture of the look-and-feel thinking — art direction, visual readability, audio. Add to it as the vibes evolve.
Date: 2026-05-30, revised 2026-06-01. Pre-prototype, gated on AMTKAG.

Rendering & corridor

2D, Godot 4. Leaning away from 3D — the spatial-correctness 3D offers probably isn’t worth the setup cost for a fixed-frame, hand-composed scene. A 3D-corridor / Doom-style-flat-sprite hybrid was explored (easier 3D dungeon-texture sourcing, smoother movement) and parked; 2D looks like the simpler path for the same result. Enemies are 2D sprites with their own scaling/depth, not billboards. (Supersedes the main doc’s old “3D corridor + 2D billboarded sprites” line — the snapshot has since been updated to match.)
Corridor = scaling tile-segments, split 4 ways (+ floor + ceiling). Same concentric-scaling model as before, but each segment is cut into separate wall / floor / ceiling tiles so they can be mixed and matched rather than authored as one frame-shaped sprite. Advance = all segments scale up together; nearest exits the screen, new ones spawn at the vanishing point. Driven by controlled advance steps, not _process. Stops lock the front segment at full-screen scale. Encounters happen “at a place,” not mid-segment.
Resolution approach: author at ~360p pixel-art scale, render at full monitor resolution. Scale the sprites up (nearest-neighbour) into a native-res canvas rather than rendering into a low-res viewport and upscaling the whole frame. This sidesteps the integer-scaling shimmer that bites a fixed low-res buffer on a 1080p display (the issue hit on the other project at 720p). The chunkiness comes from how large each source pixel is drawn, not from a low-res buffer.
Smooth-advance shimmer fix (to test): sprites scaling continuously during the walk can crawl/shimmer across non-integer sizes (Underkeep dodges this by being grid-stepped; our advance is smooth, so we don’t get that for free). Candidate fix: bilinear filtering only while in motion, snapping back to nearest when stopped, with the filter blend tweened ~0.1s tied to the advance velocity. Motion masks the softness; crisp where the player actually reads detail. Whether the in-motion softening reads as intentional motion-blur or as “the game goes blurry when I move” is a look-at-it question.
Movement feel: smooth-but-controlled advance, footfall audio, light flicker. Each advance should read as walking forward, not as the scene rearranging itself. Discrete-step (Eye of the Beholder style) considered and set aside — the auto-advance design doesn’t give the player the causal hook that made discrete movement work in classic blobbers. (Camera bob: now that the movement is framed as a walk rather than a glide, a subtle bob is coherent — a true continuous glide and footfall bob don’t really coexist. Whether to keep the bob is a feel question for prototype.)


Visual style & tone

Dark fantasy / classic dungeon. Desaturated, low-value, restricted colour band. Dim crimson, deep iron, sickly moss — no bright neon anything. Darkest Dungeon / Mörk Borg as touchstones.
Tone resolution: atmosphere is dread, mechanics are juicy. The corridor and walk are heavy and oppressive; the cascade punches through with restrained but unmistakable flashes of colour, particle, sound. Contrast is where the satisfaction lives.
Failure mode to avoid: dread-without-juice — oppressive and miserable, no payoff. The dread baseline only works if the cascade punch lands against it. Target the games that nail the balance (Mörk Borg, Darkest Dungeon); plenty of indie horror doesn’t.


Resolution & asset style (open)

Leaning: chunky pixel art, ~360p authoring scale. Will test against candidate packs. Not locked.
Two distinct looks that both read as “pixel” at a glance, and they’re different markets. Chunky native pixel = hand-placed pixels, a specific aesthetic, smaller/more style-specific asset market. Downscaled-painted (the earlier Dragon Ruins reference + palette-clamp pipeline) = painted/rendered art crushed to low res — different pipeline, different feel. Worth being honest about which one a given reference is actually doing. (E.g. Underkeep, an appealing reference, turns out to be hand-painted speed-painting crushed to low res — downscaled-painted, not chunky-pixel. So liking Underkeep is a pull toward the painted direction, and that look is also real art labour, easier for a studio than a solo asset-driven pipeline.)
Source in the right order: lead with the look, not the number. Find monster art authored at the target scale; let the art’s native size inform the resolution. Picking a number first and hunting for packs that survive being crushed into it is what made the earlier pack mush at 360p (it wasn’t authored for it).
Consequences if going chunky-pixel:

Monster variety gets harder — native chunky-pixel packs are rarer/smaller and unforgiving to mix across hands.
Corridor-tile commission gets easier/cheaper — pixel tiles are simpler than painted, and pixel artists are easier to reverse-source on itch.




VFX

Custom-built to fit the palette. Default Godot smooth particles fight the pixel aesthetic. Want pixel-snapped particles, palette-clamped via shader, banded light falloff (no smooth gradients), pixel-font damage numbers — all sharing a tight 32–64 colour palette across the whole game. (Note: if the chunky-pixel direction holds, this VFX spec is consistent; if the direction drifts back toward downscaled-painted, revisit whether pixel-snapping still fits.)
Existing 2D pixel-VFX asset libraries (itch, paid packs) cover most needs, recolour to palette. Already know this market from AMTKAG.


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
Items zoned by type. Effect family is carried by a colour-coded value panel at the top of each item, extruding over the edge (red attack, blue block, green heal, per-effect colours for status applicators); the number on the panel is the effect value. Borders are spoken for by rarity — bronze / silver / gold for common / uncommon / rare. Items bigger than feels comfortable, so activations stay legible in a cascade.
Cooldown meters Bazaar-style (filling overlay), on enemy items too — mutual cooldowns visible on both boards is the visible-race feel.
Player portrait separate from the scene; HP shown as the portrait getting progressively more beaten-up at low HP, with the value as text. No frame.


Audio
Soundtrack

Dungeon synth. Slow, droning, atmospheric, loop-friendly. Sits under the game.
Adaptive layering — thickens during combat, thins during the walk. No dramatic combat-theme cuts. Single base track per act, or one for the whole game.
Cheap to source: existing dungeon synth scene on Bandcamp, CC-licensed work, or commission a single ~30-min looped piece from a dungeon synth artist for modest money. Much cheaper than a generalist game composer, and better-fit.

Sound design

Contrasts the soundtrack. Quiet, ambient, dripping under the synth during the walk. Combat sounds crunchy and punchy — item triggers, cooldown pings, damage thuds, status applications all distinct and readable. The audio version of the visual punch-against-dread principle.
Footfall audio sells corridor movement when the visuals alone might not.
Doubles as the second readability channel (see cascade readability above) — per-effect-family sounds let the player hear their build’s texture.


Cohesion across mixed asset sources

Cohesion comes from a spec, not single authorship. Palette (32–64), resolution, line weight, lighting assumption, detail level. Hold every asset to it and multiple hands read as one. (Already conceded in principle — the monster pack isn’t made by the frame artist and is expected to cohere via the clamp.)
Darkness does coherence work. Single flickering point light, hard falloff to black washes out mismatched baked lighting and imposes one lighting read. Lean on it deliberately — not just mood.


Open items (prototype / mockup work)

Screen layout: full-screen scene vs. small framed window. Mock up one of each; decide on feel (cramped vs. breathing).
Item arrangement: type-zoned grid vs. arc-around-character. Fixed positions + hover-tilt either way. Try both with placeholder items.
UI implementation in Godot (when building): the frame wants Control nodes (anchoring, text tools); items want transform-driven nodes for free tilt/recoil. Items needing to travel over the frame is the constraint that picks the approach — cleanest options are all-2D (z-order, no viewport), or items-in-3D needing a single shared SubViewport to layer above a 2D frame, or rendering a 2D-authored frame to a viewport-texture on a 3D quad. At low res with flat pixel art these probably converge visually; deciding factor is which is least annoying to author 60 items inside. Build 3 placeholder items in the simplest (all-2D) first.
Smooth-advance shimmer — does the bilinear-in-motion / nearest-when-stopped trick read clean, or does the walk look blurry? (See Rendering.)
Light/lighting shader specifics — banded falloff, flicker math.
Palette pick (32–64 colours) — comes with the monster-pack survey.
Asset pack selection — first thing post-AMTKAG; lead with the look, let it inform the resolution.
One item firing against black — does it feel good? (Atomic readability test.)
One item on screen — idle-motion vs. cooldown-fill readability collision.
Walk pacing — can’t be dead time; atmosphere noises, environmental cues, occasional telegraph. Design once the asset style is settled.


End of vibes capture. Ongoing — add to it. The committed-at-the-family-level bits (2D, Godot, dungeon synth) are about as firm as anything here gets; everything else is a current leaning to test.