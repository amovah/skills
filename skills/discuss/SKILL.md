---
name: discuss
description: Use only when the user explicitly runs /discuss. Switches the session into plan mode for a discussion-first conversation — explore the code, answer questions, weigh approaches — and writes no plan until the user explicitly asks for one.
disable-model-invocation: true
---

# Discuss

Plan mode without the plan. The user wants to think a problem through with you —
explore the codebase, ask and answer questions, compare approaches — and to
decide for themselves when the thinking is done. Until they say so, no plan gets
written.

If the user passed a topic with the command, start there. Otherwise ask what
they want to discuss.

## 1. Enter plan mode

In Claude Code, call `EnterPlanMode` (fetch its schema with `ToolSearch` first if
it is deferred). Skip this if the session is already in plan mode.

If the user declines the switch, or the host has no plan-mode tool the agent can
call (Codex and most others), carry on anyway and hold yourself to the same
rule: read-only, no edits. Plan mode just makes "no changes" mechanical instead
of a matter of discipline.

## 2. Discuss

Do freely:

- read files, search, run read-only commands — ground every answer in the real code
- explain how things work and answer the user's questions
- lay out options with their tradeoffs, and say which one you'd pick and why
- ask clarifying questions

Hold until unlocked:

- **writing a plan file**, including the one plan mode points you at
- **calling `ExitPlanMode`** — it presents a plan for approval, so calling it is writing the plan
- **a step-by-step plan in chat** — an ordered list of tasks, files to touch, and
  sequence is a plan no matter where it appears. Discussing the approach is fine;
  turning it into a checklist is not.
- editing any project file

Don't end turns by offering to write the plan. The user invoked this skill
precisely because they want to decide when; they know how to ask.

### When plan mode's own instructions disagree

Claude Code's plan mode tells you to draft a plan file and finish with
`ExitPlanMode`. For this session the user's `/discuss` overrides that — stopping
that default is the entire reason the skill exists. Keep exploring and talking;
the normal plan workflow resumes at the unlock.

## 3. The unlock

The hold lifts when the user clearly asks for the plan — "write the plan",
"ok, draft it", "go ahead and plan this", "put that into a plan". Judge intent,
not keywords.

These are **not** an unlock:

- agreement — "sounds good", "yeah, option B", "makes sense"
- momentum — "ok", "what else?", "anything I'm missing?"
- a request to implement — "just do it" asks for code, not a plan; ask whether
  they want the plan first or want to leave plan mode and build

When a message could go either way — "so what would the steps be?" — answer at
the level of approach and ask one short question: want the plan written? A
wrong guess in the permissive direction is exactly the failure this skill
prevents; a one-line question costs nothing.

Once unlocked, write the plan the host's normal way — in Claude Code plan mode,
write the plan file and call `ExitPlanMode`. Everything the discussion settled
goes into it. From then on the session is ordinary: revising the plan on request
needs no second unlock.

## Rationalizations

| Excuse | Reality |
|--------|---------|
| "Plan mode says to write the plan file" | The user ran `/discuss` to switch that off. Their explicit instruction wins. |
| "They agreed with my recommendation, so they want the plan" | Agreeing on an approach is not asking for a plan. Wait for the ask. |
| "I'll just sketch the steps in chat, it's not a plan file" | A numbered implementation checklist is a plan wherever it's written. |
| "A draft plan would help the discussion" | Then say what you'd do and why, in prose. The user decides when it becomes a plan. |
