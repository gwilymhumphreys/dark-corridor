# Handoff: finding the look, next up the interface palettes

A starting point for the next agent. The owner wants a unique, coherent look for the game without
drawing art, using post-processing and palettes. The corridor and enemy now have dev tooling for trying
looks; the next task is trying palettes on the interface. Nothing is chosen.

Read `CLAUDE.md` first and follow it. Then read
[`separate_palettes.md`](separate_palettes.md) (the plan for separate world, effects and interface
palettes, which this continues), [`../systems/palette_clamp.md`](../systems/palette_clamp.md),
[`../systems/corridor_look.md`](../systems/corridor_look.md), [`../systems/ui_theme.md`](../systems/ui_theme.md)
and [`../systems/debug_panel.md`](../systems/debug_panel.md). [`../design/art_audio.md`](../design/art_audio.md)
is the owner's doc: read it for intent, do not edit it.

## The owner's direction (2026-09-15)

- Get the corridor and enemy looking good first, then build the rest of the look around them. That
  tooling now exists; the owner will judge it, including dithering in motion, at his PC.
- Full-screen effects are welcome (the owner mentioned CRT, colour, bloom, and the post-processing in
  Slots & Daggers).
- Not sure about rendering the corridor at a lower resolution; keep it as an option only.
- No pixel font by default; the interface needs a suitable smooth font instead of Godot's default.
- Looks are compared as settings plus screenshots in real fights, published on one page. The owner
  picks; do not rank options.

## What exists

- **The look shader and F2 panel** ([`corridor_look.md`](../systems/corridor_look.md)): grade, colour
  ramp, halftone, hatching, edges, bloom, warp, scanlines, grain, vignette, posterize, pixelate, and the
  world palette clamp with its dither options, plus the corridor light and the camera Environment
  (Godot fog and glow). Looks save to `assets/looks/*.cfg`.
- **Thirteen example looks** in `assets/looks/`, on the owner's comparison page:
  https://claude.ai/artifact/DiA9cHCTciHbQNobpeKjsU (private to the owner), saved in
  `comparisons/corridor_look_plates/`. It was built from a scratch script, not the repo: real fight
  screenshots, 1:1 crops, a no-effects view, palette swatches and each look file's settings. The earlier
  page on enemies as lit sprites in the 3D corridor is saved in `comparisons/corridor_enemy_sprites/`.
- **Dither options** (pattern, size, 2x supersample) for judging dithering in motion. The research on
  dithering in motion (Obra Dinn, surface-stable dithering) is in
  [`palette_clamp.md`](../systems/palette_clamp.md#dithering-in-motion-research); do not repeat it.
- **The full-screen clamp** (F1 "Palette") still clamps everything, interface included, to one palette.
- **The interface palette** ([`interface_palette.md`](../systems/interface_palette.md)): F1 "Interface
  palette" or `--ui-palette=`, recolouring `Colours` and the theme from a named `.gpl` file. First
  comparison page (private to the owner): https://claude.ai/artifact/62suHYJCvWuJgJ8LbWdLCL, saved in
  `comparisons/interface_palette_plates/`.
- **Background wear** ([`background_wear.md`](../systems/background_wear.md)): print wear on the screen
  background, from a record sleeve the owner liked (worn edges, specks, bends). Settings in F3.
  Comparison page (private to the owner): https://claude.ai/artifact/LfmcUdSUhiV2fbXoDkhMC1, saved in
  `comparisons/background_wear_plates/`. The owner's verdict: the rubbed edges and creases are good;
  specks are not needed but can stay if sparse (the current defaults); mottling and faint flecks were
  tried and rejected.
- **Faded areas** in the background wear, from a second sleeve the owner linked
  (https://f4.bcbits.com/img/a2053539252_10.jpg): a few large soft patches, a smooth blend (owner's
  choice), kept subtle (owner). After the first page the owner asked for about a quarter of the
  coverage and a much lower amount; version 2 shows that at three amounts (private to the owner):
  https://claude.ai/artifact/GBEJbeVgES2Tpp7MfnzFDV, saved in `comparisons/faded_areas_plates/`. The
  owner chose amount 0.15 with the quarter coverage, then asked for patch size and amount to be halved
  again; the halved values are the shader defaults.
- **Background wear is on by default** (owner, 2026-09-15): faded areas, specks, rubbed edges and two
  creases, as in the screenshots. Scratches were shown (off, dark, light, then fewer, longer and
  thinner) and removed at the owner's request. Scratch page (private to the owner):
  https://claude.ai/artifact/MNrs75MUvoAvsDtC1yjfsr, saved in `comparisons/scratch_plates/`.
- **Print frame** ([`print_frame.md`](../systems/print_frame.md)): the owner asked for every idea for
  making the corridor fit the sleeve style as a switch in a new F3 panel, and agreed the corridor moves
  in to make room for a border. Border, wear over the corridor, worn corridor edge, folds (the owner's
  folded-paper idea) and two red two-ink looks. Comparison page (private to the owner):
  https://claude.ai/artifact/CnNGoUSLqHvGx5QvauKNtB, saved in `comparisons/print_frame_plates/`. Not
  judged yet.

## The owner's direction on the interface (2026-09-15)

- The interface palette has more hues than the corridor palette.
- The interface is split into groups. Panels, buttons, text, tooltip, menus, map strip and readouts
  take a palette only, with no shaders or post-processing, so text stays legible. The border around
  the play area (not built yet), portraits and item cells and icons may also get shaders to experiment
  with. Health bars, value badges, cooldown sweep, potions, status swatches and the enemy name are
  undecided. This replaces the earlier idea of one full-screen pass over the interface.
- Fonts are being chosen in a separate session. Panel frames will come from whichever UI theme is used.

Screenshot commands (Godot exe path in [`../handoff.md`](../handoff.md)):

```
# A real fight under a look and a full-screen palette
<godot> --path . -- --autostart --autofight --nosave --notutorial --shot --shot-delay 5 --monster-image=res://assets/monsters/cut_out/bone_golem.png --look=res://assets/looks/<name>.cfg --palette=<path>
```

## Next task: palettes and effects on the interface

The interface should look like it belongs with the corridor, so try both palettes and post-processing
effects on it (for example grain, vignette, scanlines, colour grading, dithering, bloom, a slight warp),
matched to the corridor looks. Text and item icons must stay readable; check them at 1:1 in every
screenshot.

Start from [`separate_palettes.md`](separate_palettes.md): its table of where the combat screen draws,
the owner's answers (item icons are interface, damage numbers are effects), the candidate
`assets/palettes/new/ui/ui-muted.gpl`, and its approaches:

- **Choose colours at the source** (approach 3): set the theme `assets/themes/black_white_ui.tres` and the
  interface constants in `src/data/colours.gd` from a palette. Item icons are pixel art with their own
  colours, so they would still need a clamp or recolour.
- **Clamp and post-process the interface with a shader**: the interface draws on several canvas layers
  (HUD, tooltip, pause menu), so a pass that skips the corridor would need the interface in its own
  viewport, or a full-screen pass with the corridor area masked out. Both are larger changes; check the
  cost before building. A full-screen pass over everything is simpler: the corridor look shader's effects
  could be reused in a screen-reading version (like `palette_clamp.gdshader` reads the screen), with its
  own settings in the look panel, so effects can differ between corridor and interface.
- Keep each option as a debug setting, screenshot the same real fight with each, and publish one page.
  Pair interface palettes with a corridor look the owner liked (for example `demichrome`) so they are
  judged together.

## Known issues

- Every GUT run ends with "6 resources still in use at exit" (Actor, Item, Ticker and definition
  scripts), probably the Actor and Item link not being broken in combat tests. It predates this work and
  the owner has not said whether to fix it.
- The palette clamp sometimes fails to show in a screenshot when other Godot processes run at the same
  time ([palette_clamp.md](../systems/palette_clamp.md#known-issue)). Take screenshots one at a time.
