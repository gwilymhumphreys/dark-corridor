# Godot engine notes

Engine behaviours that have cost time on this project, and the working approach for
each. These are not project systems — they are Godot 4 specifics you need when the
symptom appears.

## Importing assets

If a script, scene or texture is missing at runtime, or GUT cannot see a newly added
`class_name` global, the project has not been reimported. Run:

```bash
tools/import.sh
```

Do this after adding any file, and always after adding a new `class_name` script.

**Wav files must be 8-bit or 16-bit PCM.** Godot's wav importer rejects 24-bit, and the failure
is quiet: the file imports as an empty resource and plays nothing. The only sign is
`Can't save empty resource` in the import log, which is easy to miss because the import still
exits successfully. Check the log after adding audio, and convert a 24-bit recording before
committing it.

## RichTextLabel with fit_content

A `RichTextLabel` with `fit_content = true` computes its height from its actual
rendered width, not from `custom_minimum_size.x`. On first display, if sibling nodes
push the parent container wider than that minimum, the label has already computed its
height at the narrower width and shows extra empty space below the text. On later
opens the cached width is correct, so the problem looks intermittent.

Set `custom_minimum_size.x` on the parent container wide enough for the widest
expected content, so the label computes its height at the right width from the start.
Deferred resizing, re-setting the text, updating `custom_minimum_size.x` after layout,
and switching to a plain `Label` were all tried and did not work.

## Shader built-ins and includes

Two things about the Godot shading language that fail at compile time with a message that
does not say why:

- Built-ins such as `FRAGCOORD` exist only inside the function they belong to. A helper
  function called from `fragment()` cannot read `FRAGCOORD`; the compiler says
  `Unknown identifier in expression: 'FRAGCOORD'`. Pass it in as a parameter.
- `#include` has no include guards. Including the same `.gdshaderinc` twice, directly and
  through another include, redefines everything in it. Check what the file you are
  including already pulls in.

`Shader.code` is the file's own text, with the `#include` lines unexpanded, so code that
reads uniform defaults out of shader source has to read each included file as well.

## Instance uniforms

The compatibility renderer, which the web build needs, has room for about 256 canvas items using
`instance uniform` at the same time. Godot reserves 16 slots of one 4096-slot buffer for each such
canvas item, however many instance uniforms it uses, and the size comes from the hardware, so
`rendering/limits/global_shader_variables/buffer_size` cannot raise it. Past the limit Godot logs
`Too many instances using shader instance variables`, the extra nodes draw wrong or blank, and
freeing one logs `instance_buffer_pos.has(p_instance)`.

- Use an instance uniform only on something that appears a few times at most (the portraits'
  `picture_zoom`, the pencil boxes in `board_grid.gdshader`).
- For anything that can appear many times, such as panels, item cells or effects, give each node its
  own copy of the material and set ordinary uniforms on it (the worn panels in
  [panel_wear.md](panel_wear.md), the item cell's cooldown ring), or lay the pattern out from
  `FRAGCOORD`. Canvas items drawn through a shared material with instance uniforms are already one
  draw call each, so material copies cost no extra draw calls.

## Runtime cleanup

Godot reports leaked objects at exit and can free an already-freed node at a scene
change. In `_exit_tree()`:

| Held resource | What to do |
|---|---|
| Textures | Set `node.texture = null` before `queue_free()` |
| Signals, tweens, timers | Disconnect and stop them |
| Arrays and dictionaries holding node references | Clear them |
| Nodes owning render resources | Free with `call_deferred('queue_free')` |
| Textures registered with a server | Unregister them and drop the reference in `_exit_tree()` |

A "RID allocations of type 'N5GLES37TextureE' were leaked at exit" error, followed by
"Parameter "RenderingServer::get_singleton()" is null" from `~ImageTexture`, means a texture
was still referenced when the rendering server shut down. Find who holds it and release it
during scene-tree teardown. (The mouse cursor is drawn as an ordinary node and registers no
texture with the display server — [cursor.md](cursor.md).)

Avoid reparenting nodes during teardown. If a node must be reparented, store its
original parent with `set_meta()` and put it back.

### Scripts leaked at exit

"ObjectDB instances were leaked" listing only scripts and shaders has two known
causes: two scripts that each refer to the other's `class_name`, and a `static var`
on a script whose subclass refers to an autoload. Either keeps both scripts alive
past exit. Move the shared code to one side of the pair, or hold the value on an
autoload instead.
