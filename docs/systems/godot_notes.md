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

## Runtime cleanup

Godot reports leaked objects at exit and can free an already-freed node at a scene
change. In `_exit_tree()`:

| Held resource | What to do |
|---|---|
| Textures | Set `node.texture = null` before `queue_free()` |
| Signals, tweens, timers | Disconnect and stop them |
| Arrays and dictionaries holding node references | Clear them |
| Nodes owning render resources | Free with `call_deferred('queue_free')` |

Avoid reparenting nodes during teardown. If a node must be reparented, store its
original parent with `set_meta()` and put it back.

### Scripts leaked at exit

"ObjectDB instances were leaked" listing only scripts and shaders has two known
causes: two scripts that each refer to the other's `class_name`, and a `static var`
on a script whose subclass refers to an autoload. Either keeps both scripts alive
past exit. Move the shared code to one side of the pair, or hold the value on an
autoload instead.
