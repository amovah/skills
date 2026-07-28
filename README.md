# amovah/skills

Personal [Claude Code](https://claude.com/claude-code) skills, packaged as a plugin.

## Install

```
/plugin marketplace add amovah/skills
/plugin install amovah@amovah-skills
```

Once installed the skills are available as `/amovah:batch-plan` and
`/amovah:batch-run`.

## Skills

| Skill | What it does |
|-------|--------------|
| `batch-plan` | Second pass over a finished implementation plan: derives the real code-level dependencies between tasks, groups them into concurrently-safe batches, and writes the dispatch table, batch sequence, and dependency edges back into the plan file. |
| `batch-run` | Executes an annotated plan batch by batch. Every unblocked task is dispatched at once, each subagent in its own git worktree branched from a common base; the batch is reviewed as a whole, merged in order, and validated once. |

## Batch Workflow

The two are a pair, run in order:

1. Write a plan (any planning skill or by hand).
2. `/amovah:batch-plan` — annotate it with blockers, batches, and worktree safety.
   The plan file is the deliverable; it is edited in place.
3. `/amovah:batch-run` — execute the annotated plan with concurrent subagents.

`batch-run` refuses to derive batches on the fly, so step 2 is not optional.

`batch-run` builds on `superpowers:subagent-driven-development` for the per-task
machinery (task brief, report file, review loop, progress ledger) and replaces
exactly one of its rules — the ban on dispatching implementation subagents in
parallel.

## License

MIT — see [LICENSE](LICENSE).
