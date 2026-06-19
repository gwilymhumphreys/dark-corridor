# Documentation — how the docs work here

How this project's docs are organized, and the rules for writing + maintaining
them. Read this before adding or changing a doc. (Agent working rules live in
`CLAUDE.md`; this is the canonical detail it points to.)

## Where each kind of doc lives

| Location | Holds |
|----------|-------|
| `docs/index.md` | The catalog — one row per doc (Doc / Covers / Keywords). **Read first; every doc must be listed here.** |
| `docs/handoff.md` + `docs/decision_log.md` | Fresh-agent orientation + the canonical numbered decision record. |
| `docs/systems/` | One doc per engineering system — spec + as-built together. Cross-system edges live **once** in `systems/architecture.md`'s boundary hub, not duplicated. |
| `docs/design/` | Game/content design (the owner's domain) + the content authoring guide. |
| `docs/plans/` | Approved-but-unbuilt designs. Each becomes a `systems/` doc on ship. |
| `docs/history/` | The chronological build log + the original phase plans. |

## The rules

1. **Keep docs in sync with the code — in the same change.** If you change
   behaviour a doc describes, update that doc in the same commit. Code and its
   doc are never committed out of sync. This is mandatory, not a follow-up.
2. **Catalog every doc.** A new doc gets a one-row entry in `docs/index.md`
   (Doc / Covers / Keywords). An uncatalogued doc is invisible — the index is
   the entry point everyone reads first.
3. **Describe systems, mechanics, and design intent — not specific numbers.**
   Point to source files (GDScript constants, `*.json`) for tunable values, so
   docs don't go stale when values are tuned. Include a formula only if it aids
   understanding, and cite the source file for the actual constants.
4. **Be concise.** Minimal examples; an agent should grok the subject fast.
   Each doc opens with its own one-paragraph summary (the index matches on it).
5. **Plain language, full names.** No invented jargon; refer to game entities by
   their full names (the `CLAUDE.md` Code Standards apply to docs too).
6. **Keep player-facing text translatable.** See `systems/localization.md`;
   regenerate the POT after changing any translatable string.

## Lifecycle (which doc to touch when)

- **New engineering system** → a `docs/systems/<name>.md` + an `index.md` row.
  Put any new cross-system contract in `architecture.md`'s boundary hub.
- **A plan ships** → the `docs/plans/<name>.md` becomes `docs/systems/<name>.md`,
  add a `decision_log.md` line, and move the `index.md` entry from Plans to
  Systems (the plan file stays for rationale/lineage). The tooltip system
  ([systems/tooltips.md](systems/tooltips.md)) is the worked example.
- **A settled decision / rationale** → a numbered `decision_log.md` entry (don't
  re-litigate anything already in it).
- **A notable milestone** → refresh `handoff.md`'s "Last updated" blurb.

## After-change checklist

- [ ] Behaviour changed? Update the doc(s) that describe it — same change.
- [ ] New doc? Add its `index.md` catalog row.
- [ ] New decision/rationale worth keeping? Add a `decision_log.md` entry.
- [ ] Player-facing strings changed? Regenerate the POT (`localization.md`).
