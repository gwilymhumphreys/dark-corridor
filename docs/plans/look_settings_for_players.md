# Plan: look settings for players

> **Status: planned, not built (2026-09-17).** Step 1, [look presets](../systems/look_presets.md) and the
> tabbed debug panel, is built. This plan covers the owner-approved next steps: making the default look
> load in release builds, then letting players change parts of it from the settings screen.

## Layers

The look is built from four layers, each recording only what it changes:

| Layer | Where it lives | Who sets it |
|---|---|---|
| Shader defaults | Shader code; every effect off | Nobody |
| The game's look | `assets/presets/default.cfg`, in the repository | The owner, with Make default |
| Player settings | `Prefs` (`user://`), only the settings the player changed | The player, on the settings screen |
| Debug panel edits and start-up arguments | The session | The owner, while trying looks |

A player who turned one setting off keeps it off when the default look changes in an update, and gets
every other change.

## Step 2: the default look in release builds

- Palette files are read with `FileAccess`, which only works in debug builds, and `.cfg` and `.gpl`
  files are not exported by default. Load them in a way that works in exports (resources, or export
  include filters) and check with an exported build.
- The corridor look's material and settings live on `DebugPanels`. Decide whether they move to an
  autoload that is not a dev tool, like `PrintLook` and `InterfaceLook`.

## Step 3: player settings

- A player setting is a named choice, not a shader value. Each option sets several values at once,
  for example "Screen effects: Full / Reduced / Off". The settings and their options are defined in one
  file. `Prefs` stores the setting name and the chosen option only, so a renamed or retuned shader value
  does not break saved settings; an option that no longer exists falls back to the default.
- Optionally, a preset can be marked as shown to players, with a translatable name, and appear in a
  "Look" setting with the finer settings applied on top. The owner decides.
- Presets are saved from the game's look and the debug panel edits only, never from player settings.
  The debug panel greys out a value a player setting currently holds and names the setting.
- Which settings players get is the owner's decision. The agent builds the mechanism and at most one
  example setting, marked as a placeholder.
