# Delegating implementation to the local model

A dev tool. A local model runs on this machine behind an OpenAI-compatible HTTP
endpoint. Claude Code plans a change, hands the specification to that model,
which writes the edits into the working tree, and then reviews the diff. The
local model is much weaker, so it gets a specification rather than a goal.

The runner and the workflow live outside this repository, in the `delegate`
skill at `~/.claude/skills/delegate/` (`SKILL.md` for the workflow,
`reference.md` for the options and the configuration format). They are shared
across projects. What lives here is the project's own configuration.

Not for content (items, enemies, encounters) — that is the project owner's
domain. Not for design decisions.

## This project's configuration

`.claude/delegate.json` sets:

- **Standards** — the model is given `CLAUDE.md`, so the code standards it is
  held to are the same ones written there, with no second copy to drift.
- **Denied paths** — `.git/`, `.godot/`, `.claude/`, `.worktrees/`,
  `autotest_results/` and the vendored `addons/gut/`.
- **Verification**, three stages run in order, stopping at the first failure,
  with the failures handed back to the model to fix:
  1. A text check of the GDScript standards on the changed `.gd` files: tabs,
     odd indentation, double-quoted strings, missing type annotations and
     missing return types. It only reports lines the model actually added or
     altered, so it never asks the model to change pre-existing code.
  2. `godot --headless --path . --import --exit`, scanning for script and parse
     errors. This also imports new files, which the GUT suite needs in order to
     see a new `class_name`.
  3. The GUT suite, as described in [handoff.md](../handoff.md).

None of that checks whether the change does what was asked, which is why the
diff review is Claude Code's job and not optional.

## Running it

```bash
python ~/.claude/skills/delegate/delegate.py run <task file> --files src/a.gd,src/b.gd
```

Each run keeps its transcript, its task file, the diff it produced and a line of
statistics under `~/.claude/delegate/`, outside the repository. Nothing is
written into the project except the code changes.
