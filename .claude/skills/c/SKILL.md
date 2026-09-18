---
name: c
description: Commit the current changes. Use whenever there is committing to do — the user says "commit", "/c", "commit this", "commit the changes", or a workflow step calls for a commit. Always delegates the commit to a Sonnet subagent.
---

# Commit

Do not run git yourself. Spawn one subagent and let it do the whole commit:

```
Agent(
  subagent_type: "general-purpose",
  model: "sonnet",
  description: "Commit changes",
  prompt: <the prompt below>
)
```

Prompt for the subagent:

> Commit the current changes in this repository.
>
> 1. Run `git status --short` and `git diff --stat` (nothing else — do not read full diffs or file contents).
> 2. Stage everything with `git add -A`.
> 3. Commit once, with a short imperative summary line under 72 characters, based only on what the paths and stat output show. Add no body unless the change is clearly several unrelated things, in which case one line of detail is enough. Add no attribution lines and no Co-Authored-By.
> 4. Reply with just the commit subject line and the short stat.
>
> Keep it cheap: one commit for everything, minimal tool calls, no verification builds or tests.

When the subagent reports back, tell the user the commit subject in one line. Do not re-check the repository.
