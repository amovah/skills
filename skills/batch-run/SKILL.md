---
name: batch-run
description: Use when the user runs /batch-run, or asks for an annotated implementation plan to be executed by dispatching each batch of independent tasks to concurrent subagents in isolated git worktrees.
---

# Batch Run

Execute a plan batch by batch. Every task whose blockers are satisfied is
dispatched at once, each subagent in its own git worktree branched from the same
base commit; the batch is reviewed as a whole, merged in order, and validated
once.

**Relationship to superpowers:subagent-driven-development:** that skill owns the
per-task machinery — task brief, report file, task review, the five-round fix
loop, the progress ledger, model selection. All of it applies here unchanged.
This skill replaces exactly one of its rules:

> Never dispatch multiple implementation subagents in parallel (conflicts).

That rule is right when nothing has proven the tasks disjoint. An annotated plan
is that proof.

## Requires an annotated plan

Each task must carry its blockers, its batch, and a worktree-safe flag, and the
plan must carry a dispatch table. If it does not, stop and run
`batch-plan` first. Deriving batches on the fly, mid-execution,
is how a wrong edge reaches a merge.

## The batch loop

Repeat until no tasks remain.

**1. Select the batch.** Every task whose blockers are all complete, per the
dispatch table and the ledger.

**2. Pre-dispatch ownership check.** Take each task's write paths from the plan.
They must be pairwise disjoint across the batch. If two tasks in the batch write
the same path, the annotation is wrong — see *Conflicts are plan defects* below.
Do this before dispatching, every batch, even when the table says worktree-safe.

**3. Record BASE** (`git rev-parse HEAD`). Every worktree in this batch branches
from this one commit.

**4. Create the worktrees yourself.** `git worktree add <path> -b <branch> BASE`,
one per task. Do not rely on a harness `isolation: "worktree"` flag to do this
for you — observed: subagents dispatched with that flag ran in the *shared*
checkout on the shared branch and committed serially into it. Nothing was
clobbered that run, by luck rather than isolation.

**5. Dispatch the whole batch concurrently** — all Agent calls in a single
message, each carrying its task brief per subagent-driven-development. Each
dispatch states: the absolute worktree path, the exact files this task may
write, and that sibling tasks are running concurrently so their files do not yet
exist in this tree.

Every dispatch opens with an isolation self-check the agent must run before any
other work: print `git rev-parse --show-toplevel` and `git branch --show-current`,
and abort immediately if either is not the one assigned to it. An agent that
silently lands in the wrong tree is the failure this check exists to catch.

**6. Wait for the entire batch, then confirm isolation actually held.** Each
task's commits must sit on its own branch. Single-parent commits stacked
linearly on the shared branch mean the worktrees never took effect and the
agents ran in one tree — audit each task's `git diff --name-only` for
overlapping writes before trusting any of the work, and fix isolation before
the next batch.

**7. Review every task's diff** — spec compliance and quality, per
subagent-driven-development's task review — *before merging any of them*.
Ownership checks (`git diff --name-only BASE..<branch>`, plus a pairwise
overlap check across the batch) verify lanes were respected; they are not a
review and do not replace one.

**8. Merge sequentially in dispatch-table order.**

**9. Validate once, after the last merge in the batch** — the full gate
(typecheck, lint, build, tests). Not after each merge. Cross-task drift only
becomes visible once the batch is whole.

**10. Append the batch to the ledger**, then clean up worktrees and branches.

## Conflicts are plan defects

A merge conflict inside a batch means two tasks the plan called disjoint were
not. The conflict is the symptom; the annotation is the bug.

**Stop the merge. Fix the plan, then rework one task against the corrected
annotation.**

Concretely: correct the dispatch table (split the shared file so each task owns
one, or move a task to a later batch), then re-dispatch the affected task from
the corrected plan. The plan and the code end up agreeing.

**Not allowed:**

- Hand-resolving the conflict and continuing. The code works; the table still
  lies; the next execution of this plan walks into the same collision.
- Pre-coordinating the colliding agents so their edits merge cleanly — dictating
  an identical structure to both so the union applies without conflict. This
  hides an ownership violation behind coordination that does not scale past two
  agents and leaves the annotation wrong.
- Rebasing the second task onto the first to make the conflict resolvable. Same
  concealment, different mechanism.

The same applies to a collision you spot at step 2 rather than at merge: it is a
plan defect at that moment too, not an obstacle to engineer around.

## Questions do not stop execution

Execution runs to completion. A question that surfaces mid-run — an ambiguity in
a brief, a detail the plan left open, a choice between two valid approaches — is
answered by you, logged, and left for the user to approve at the end.

For each one:

1. Choose the option you would recommend.
2. Append it to the decision log at `<workspace>/decisions.md`: the question, the
   options considered, what you chose, why, and which task, batch, and commits
   it touches.
3. Keep going.

Do not batch up questions and stall, and do not ask the user one at a time as
they arise. The user asked for the plan to be executed; a run that pauses six
times for questions you were able to answer has not executed it.

### Decisions made below you still belong in the log

Most ambiguity is not resolved by you. It is resolved by an implementer who
found its brief silent, picked something reasonable, and shipped it without
ever raising a question. That choice never reaches the log unless you ask for
it.

Every dispatch therefore instructs the implementer: **report every choice you
made where the brief was silent or admitted more than one reading** — the
options, what you picked, and why — in your report. Reviewing the resulting code
does not substitute: by then the alternative is invisible, and a reviewer sees a
working implementation rather than a decision.

Fold each one into the decision log under the task that made it. If a reported
choice turns out to be large drift or spec-level, it becomes a hard stop at that
point, even though the code already exists.

### The two hard stops

Some decisions are not yours. Log them, report to the user, and wait:

- **Critical.** Data loss, a security consequence, anything irreversible,
  anything that invalidates work already merged, or anything that blocks every
  remaining task.
- **Against approved spec.** The answer would contradict the spec the user
  accepted. Choosing here is overruling a decision they already made — and it
  stays a hard stop even when the spec looks wrong to you. Say so in the report
  and let them rule.

  This includes the plan mandating something the spec forbids. Finding a third
  option that satisfies the spec while quietly dropping or weakening what the
  plan required does not dissolve the conflict — it resolves it in your favor
  and hides it in a workaround. Two documents the user approved disagree; which
  one gives way is theirs to say. Log the conflict, name your recommended
  resolution, and stop.

### Spec is binding; the plan tolerates drift up to a ceiling

The plan is how the work was expected to get done; the spec is what the user
agreed to receive. Small and medium drift from the route is acceptable — log it
and keep going. Large drift is not.

Judge the size by how far the deviation reaches, not by how it feels. It stays
inside the acceptable band while it is confined to the files this task already
owns:

- **Small to medium — log and continue.** File layout inside the task's own
  folder, an extra internal module, a helper's location, naming, step ordering,
  splitting a file the task owns, a different internal approach that produces
  the same exports.
- **Large — hard stop.** The deviation reaches outside the task: it changes an
  interface or file other tasks were told to consume, adds or drops a task,
  moves a task between batches or adds a blocking edge, pulls in a dependency or
  tool the plan does not name, or abandons the plan's approach for this task in
  favor of a different one. Each of these invalidates a brief someone else is
  working from, so it is not yours to absorb.
- **Spec-level — hard stop.** Changes what gets delivered: an endpoint or
  contract the spec names, user-visible behavior, the auth or data model, what
  is or isn't in scope. That is spec, whatever the plan says about it.

The line between the first two is a question you can answer by looking: does
anything outside this task's own write set have to change for the deviation to
work? If yes, it is large.

superpowers:subagent-driven-development routes every plan contradiction to the
human partner. Here, only the ones that leave the task's own lane do.

### Approval gate before master

The decision log is the last gate. When every batch is merged and the final
review is clean, present the log to the user — every entry, each one approvable
on its own. Rejected entries get reworked before the branch moves.

**The branch does not merge to master until the log is approved.** Batch merges
land on the working branch during the run; master waits.

## Batches of one

A task marked *alone* runs alone — no worktree needed, work directly on the
branch. Tasks that sweep many folders are marked alone precisely because their
write set cannot be bounded in advance.

## Rationalizations

| Excuse | Reality |
|--------|---------|
| "Serial execution satisfies every blocker by construction" | True and irrelevant. You were asked to execute the plan in parallel; a schedule that collapses to one lane discards the analysis that produced it. |
| "Worktrees add merge overhead with nothing to gain" | The gain is the batch running concurrently. Skipping isolation is what makes concurrency unsafe, so this reasoning is circular. |
| "I can make both agents write the shared file compatibly" | Then the batch annotation is wrong and stays wrong. Fix the plan; two agents you can coordinate become eight you cannot. |
| "The conflict was small, I resolved it" | Every hand-resolved conflict is a plan defect discarded. The next run hits it again. |
| "The agents' own checks passed, no need to review the diff" | Their checks ran inside isolated worktrees against a tree that never saw their siblings' work. Green there is not green merged. |
| "I'll validate after each merge to catch problems early" | Cross-task drift is invisible until the batch is whole, and N validations per batch cost N times as much to find less. |
| "This batch is only two tasks, the ownership check is overkill" | The observed collision was a two-task batch, marked worktree-safe, and it collided. |
| "The dispatch table says worktree-safe" | The table is a claim. Step 2 is the check. |
| "I passed the isolation flag, so they're isolated" | Observed doing nothing: agents dispatched with it ran in the shared checkout on the shared branch. Create the worktrees yourself and make every agent print where it landed. |
| "Nothing got clobbered, so isolation was fine" | Disjoint writes in one shared tree is luck, and luck does not survive a batch eight wide. |
| "I should check with the user before choosing" | Only for the two hard stops. Everything else: choose, log it, keep going — they approve the log at the end. |
| "This decision is big enough to be worth interrupting for" | Size is not the test. Critical or against approved spec is the test. A large reversible choice gets logged like any other. |
| "The spec is clearly wrong here, I'll do the sensible thing" | Contradicting approved spec is a hard stop, precisely when you are sure. Report it and let them rule. |
| "This deviates from the plan, so I have to stop" | Drift confined to the task's own files gets logged, not escalated. Only drift that reaches outside it stops. |
| "It's only a small deviation" | Then nothing outside this task's write set changes. If something does, it is large regardless of how few lines it took. |
| "I'll just adjust the shared interface and tell the other tasks" | That is the large-drift case. Other briefs are already written against it — stop and report. |
| "I logged it, so it's settled" | The log is a queue for approval, not consent. Rejected entries get reworked before master. |
| "The implementer didn't ask anything, so there was nothing to decide" | Silence means it chose without asking. Require the choices in its report; the log is empty otherwise. |
| "I found a way to satisfy both the plan and the spec" | If it satisfies the spec by dropping what the plan required, you resolved an approved-document conflict yourself. Log it and stop. |
| "Reviewing the diff will catch anything the implementer decided" | A review sees working code, not the option that was discarded. |

## Red flags

- Dispatching a batch without recording BASE
- Dispatching without an isolation self-check in the prompt, or accepting a
  batch whose commits are single-parent and linear on the shared branch
- Merging any task in a batch before every task in it has been reviewed
- Editing conflict markers by hand
- Running the validation gate between merges inside one batch
- Deriving a task's blockers yourself mid-run instead of reading the table
- A batch that finished with the plan file unchanged after a collision surfaced
- Stopping to ask a question that is neither critical nor against approved spec
- Answering a question that *is* against approved spec, however sensible the answer
- Escalating a deviation confined to the task's own write set
- Absorbing a deviation that changed something outside it
- A dispatch that never asked the implementer for the choices it made
- A completed batch whose decision log gained no entry from any implementer
- Resolving a plan-versus-spec contradiction with a workaround instead of a stop
- Reaching master with unapproved entries in the decision log

## Finish

When the last batch is merged and validated, run the whole-branch final review
from superpowers:subagent-driven-development. Then present the decision log for
approval — this gates the merge to master, so it happens before
superpowers:finishing-a-development-branch, not after.
