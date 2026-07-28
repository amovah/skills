---
name: batch-plan
description: Use when the user runs /batch-plan, or asks for an existing implementation plan to be annotated with real task dependencies, parallel batches, and worktree safety before the plan is executed by parallel agents.
---

# Batch Plan

A second pass over a finished implementation plan. Derives the real code-level
dependency between tasks, groups them into batches that can safely run
concurrently, and writes all of it back into the plan file.

Input: a plan whose tasks are written but whose parallelism claims are
unverified. Output: the same file, annotated.

## The Iron Rule

**A task's declared interface list is a hint. The task body is the truth.**

Where a task's declared `Consumes` / `Interfaces` list and its own prose or code
blocks disagree, the body wins — and you repair the declaration in the plan.

This rule exists because of one observed failure. A 24-task plan had a task
declaring seven consumed symbols, none of them the balance hook — while its own
prose two lines below read *"Toman amount with the IRT balance as max."* Its two
sibling tasks declared that hook correctly. An analyst who trusted declarations
placed the odd task in the same batch as the task that defines the hook. At
merge it would import a file that does not exist yet.

Loud dependencies get declared. Quiet ones get described in prose and forgotten.

## Output contract

The deliverable is **the edited plan file**. A dependency analysis delivered as
a chat message is not a deliverable — whoever executes the plan reads the plan,
so an uncorrected file keeps misleading them after your analysis scrolls away.

Every run writes exactly these four things into the plan:

1. **A header line on every task**, in the plan's existing task-header style:
   `**Blocked by:** T3, T7. **Batch E — parallel with T9, worktree-safe.**`
   Every task gets one, including tasks blocked by nothing. One line: task IDs,
   batch, and at most a bare symbol in parentheses. Justification, quoted prose,
   and the story of how you found an edge go in the dependency-edges section —
   a header carrying a paragraph is unreadable at the exact moment someone needs
   it, which is while dispatching.
2. **A dispatch table** near the end of the plan: one row per task, columns
   `Task | Blocked by | Batch | Worktree-safe | Writes outside its own folder`.
3. **A batch sequence block** listing batches in execution order with their
   width, plus the critical path.
4. **A dependency-edges section** naming each cross-task edge and the symbol
   that causes it — `T11 → T12: CoinPage imports the AssetRow type and
   useBalances hook that T11 defines.`

Corrections you make to a task's declared `Consumes` list are edits to that
list, in place.

## Procedure

**1. Build the produces table.** For each task, list what it creates: every
path under its `Files: Create`, and every exported symbol named in its code
blocks or prose.

**2. Build the consumes table.** For each task, read the *whole body* — prose,
code blocks, `Files: Modify`, verification steps — and list every symbol and
path it uses. Do this for every task, not only the ones whose dependencies look
interesting. The declared list is one input among several, never the stopping
point.

**3. Draw edges.** A consumed symbol whose producer is another task is an edge.
Record the symbol; a batch table without symbols cannot be audited later.

**4. Verify every stated blocker.** For each `blocked by` already written in the
plan, confirm a real edge backs it. Blockers inherited from wave or section
structure, with no symbol behind them, are scheduling habit — drop them. This is
where parallelism is usually hiding: two tasks sitting in adjacent waves may
write entirely disjoint paths and belong in one batch.

**5. Check write collisions.** Two tasks that write the same path cannot share a
batch. Resolve by splitting the file so each task owns one (preferred — it buys
concurrency) or by serializing them into different batches. Record which you
chose and why.

**6. Check environment collisions.** File-level disjointness is not enough.
Walk this list for every batch wider than one:

- fixed dev-server ports (`strictPort`), fixed database or fixture ports
- lockfiles and manifests — any task that may install a dependency
- codegen or scaffolding CLIs that rewrite shared config (`shadcn add` rewriting
  a theme block, an OpenAPI generator rewriting a client)
- shared global config: linter config, barrel/index files, route tables
- per-worktree bootstrap: a fresh worktree has no `node_modules` and no
  gitignored `.env`

Each one found becomes either a batch-level rule in the plan or an edge.

**7. Assign batches.** Topological levels: a task's batch is one past the
highest batch among its blockers. Tasks that write across many folders run
alone.

**8. Write the four artifacts from the output contract into the plan file.**

## When uncertain, add the edge

A missed edge breaks the build at merge time and costs a rework cycle. A
spurious edge costs one batch of wall-clock. These are not symmetric. If you
cannot tell whether a task depends on another, it does.

## Rationalizations

| Excuse | Reality |
|--------|---------|
| "The task declares what it consumes" | Declarations are written per-task by an author focused on that task. The one that omits a symbol is exactly the one that breaks the batch. Read the body. |
| "The plan already says these run in parallel" | That claim is the thing you were asked to verify. A plan asserting a twelve-wide fan-out had four real edges inside it. |
| "The wave structure implies the blockers" | Waves are how the plan was written, not what the code needs. Blockers with no symbol behind them cost parallelism for nothing. |
| "I'll report the dependencies in my summary" | The executing agent reads the plan file. An uncorrected plan keeps misleading it forever. |
| "This one's obvious, no need to name the symbol" | An edge without its symbol cannot be re-checked when the plan changes. |
| "The declared list and the prose disagree — probably prose sloppiness" | Backwards. The prose describes the code that will be written. |

## Red flags

- Producing a dispatch schedule without opening every task's body
- A batch table whose edges have no symbol names
- Leaving a task's `Consumes` list untouched after finding it incomplete
- Any batch wider than one that was never checked for port, lockfile, or
  shared-config collisions
- Finishing with the analysis in your final message and the plan file unmodified

## Handing off

The annotated plan is the input to superpowers-style parallel execution. Use
`batch-run` to run it.
