Full code + docs health review — LSP warning sweep, test-suite check, and a docs-vs-code freshness audit; fix what's clearly wrong, report the rest.

Repeat the periodic "is the codebase clean and are the docs honest?" pass. Scope to a subsystem if `$ARGUMENTS` names one (e.g. `audit combat log`); otherwise sweep the whole project.

## What "done" looks like

- **0 LSP warnings/errors** across `src/` + `tests/` + `tools/` (every `.gd` file actually checked — see the reliability note).
- **Full GUT suite green**, with **no `Warnings`/`Deprecated` rows** in the totals.
- **Docs match the code**: no stale versions/counts, no dead symbols, no behaviour the doc describes wrongly; built features not still marked "deferred"; genuinely-built-but-undocumented systems get concise coverage.
- **No new filler.** Trim only blatant duplication + invented jargon (CLAUDE.md forbids both); leave intent-bearing prose.

## Toolchain

Canonical commands + the Godot console-exe path live in [`docs/handoff.md`](../../docs/handoff.md) ("How to work"). Always **import first** after any new `class_name` script, then run the suite:

```bash
tools/import.sh      # required before the suite sees new globals
tools/gut.sh
tools/lsp_check.sh   # analyzer warnings for every .gd file (step 3)
```

The at-exit `ObjectDB leaked` / `resources still in use` lines are **benign** (the static catalog caches — handoff confirms this), not a leak.

## Process

### 1. Orient
Read [`docs/index.md`](../../docs/index.md), [`docs/handoff.md`](../../docs/handoff.md), and `git log --oneline -10 --stat`. The recently-churned files are where drift concentrates — start there.

### 2. Baseline health
Import, run the GUT suite, record the **test count** and whether the totals show any **`Warnings`/`Deprecated`** rows. Note the real Godot version (`project.godot` → `config/features`) — compare it to what the docs claim.

### 3. LSP warning sweep — check EVERY `.gd` file
Run `tools/lsp_check.sh`. It starts a headless editor with its own language server on port 6015, asks it about every `.gd` file under `src/`, `tests/` and `tools/` (or only the files you pass), prints each warning and error, and stops the editor. The summary line must say every file replied; a file with no reply was not checked.

**Do not use the other channels.** The `<new-diagnostics>` block on a `Read`, the `godot-mcp` diagnostics tools and the `godot-lsp:gdscript-validate` agent all return nothing, not an error, when the open editor's language server is unavailable. It accepts eight clients, and in the 2026-09-29 audit all eight were taken, so those channels reported a clean project that had 108 warnings. The command-line import and `--check-only` print errors but never warnings.

Common, correct fixes:
- `UNUSED_PARAMETER` on an interface/signature-symmetry method → prefix `_` (don't delete — it keeps the call-site shape). Genuinely dead → remove.
- Deprecated GUT API (`wait_frames` → `wait_physics_frames`), Float/Int comparison in asserts (`int(...)` wrap) → fix.
- `@warning_ignore('integer_division')` and untyped polymorphic-interface params (Actor-or-Item) are **intentional** — leave them.

### 4. Docs-vs-code audit (fan out, then VERIFY)
Spawn parallel agents (one per doc cluster) to cross-check each `docs/systems/*.md` claim against the code it describes, reporting DRIFT / STALE / MISSING / FILLER with `file:line` citations. Good clusters: the recently-changed docs; core combat (`combat_model`/`item`/`timekeeper`/`architecture`); the rest of `systems/`; and a staleness/filler survey of presentation + top-level docs.

**Do not edit straight from an agent's report.** Agents produce confident false positives — last pass, three findings were wrong on inspection (a "stateless violation" that wasn't, a "stale provisional" wording the decision-log itself uses, a "Prefs undocumented" that audio.md already covered). **Read the cited code + doc lines yourself before every edit.**

### 5. Apply fixes
- **Staleness:** Godot version, test counts, autoload count/list, exe paths, "Last updated" blurbs.
- **Dead symbols:** functions/scenes/fields the doc names that don't exist (e.g. a renamed scene, a never-built method).
- **Behavioural drift:** the doc describes what the code does wrongly.
- **Built-but-marked-deferred:** flip "deferred"/"not in scope" notes for shipped mechanism.
- **Missing coverage:** add *concise* coverage of built-but-undocumented systems (point to source, don't transcribe it).
- **Filler:** cut duplicated sections + invented jargon only.
- **CLAUDE.md compliance:** docs describe *intent, not numbers* (point at `Balance`/catalogs); update the doc in the **same change** as any code you touch.

### 6. Respect the owner's domain
`docs/design/*` and the content catalogs are the **owner's** — do NOT rewrite design choices, content, or terminology. In design docs only fix engineering-fact staleness (version, dead links, dead symbols). Flag anything else for the owner instead of editing.

### 7. Confirm + report
Re-run the suite (green, no Warnings/Deprecated). Report grouped: **health** (tests/LSP/version), **code/warning fixes** (table), **doc fixes** (grouped by file/kind), **verified-and-rejected** (agent claims you checked and dropped — shows the verification was real), and **optional follow-ups** left for the owner. Then offer to commit (don't auto-commit — CLAUDE.md: commit only when asked; no self-attribution).

ARGUMENTS: $ARGUMENTS
