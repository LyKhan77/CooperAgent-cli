---
name: cooper-handoff
description: Hand off to a fresh session when context is nearly full or compaction is failing or too slow. Updates the checkpoint minimally and tells you what to say next. Cheap by design — it does not re-summarize the conversation.
---

# cooper-handoff

Use this when the context is nearly full, or compaction has failed, or it is
taking longer than you are willing to wait.

**It is cheap on purpose.** The checkpoint at `.cooper/context/<slug>.md` is
normally already maintained at every task boundary, so there is nothing to
reconstruct. Do not re-read the conversation and do not write a long summary.

**Announce first:** "Using the cooper-handoff skill."

## What to do

1. Read the existing checkpoint at `.cooper/context/<slug>.md`. If none exists,
   create one now using the format below — this is the only case where this
   skill writes it in full.

2. Update only what has changed since it was last written:
   - **Where I am** — the current state, 1-3 sentences
   - the step markers `[ ] [~] [x] [!]`
   - **Next** — one concrete action
   - **Don't repeat** — anything tried and abandoned since the last update

3. Write it via a temp file, then move it into place. Overwriting in place
   leaves a window where the file is empty, and a session that dies there loses
   its checkpoint:

   ```bash
   tmp=$(mktemp) && cat > "$tmp" <<'CP'
   ...
   CP
   mv "$tmp" .cooper/context/<slug>.md
   ```

4. Reply with **at most three lines**:

   ```
   Checkpoint: .cooper/context/<slug>.md
   State: <one sentence>
   Continue in a new session with: "continue <slug>"
   ```

## Checkpoint format

Kept here in full so this skill works on its own. The CooperAgent global rules
(`AGENTS.md`) are optional since 2026-09-03, and a skill that only points at
rules the developer declined is a skill that does nothing.

```markdown
# <task title>
Updated: <YYYY-MM-DD HH:MM>

## Where I am
<1-3 sentences. Latest state, not history.>

## Steps
[x] <done> — evidence: <output/number/test result>
[~] <in progress>
[ ] <not started>

## Decisions
- <decision + why, one line>

## Don't repeat
- <what was tried and failed, so the next session doesn't spend it again>

## Next
<one concrete action>
```

`[x]` only with **evidence** — command output, test results, real numbers.
"Don't repeat" is the most valuable section: dead ends that go unrecorded get
walked again.

## What not to do

**Do not summarize the conversation.** That is what compaction does, and it is
what you are avoiding by using this skill.

**Do not paste code, diffs, or command output.** The checkpoint carries only
evidence lines already recorded at task boundaries.

**Do not ask questions.** The user is out of context and waiting. Write the
file and report.

## After

The user starts a new session and says "continue <slug>". Read
`.cooper/context/<slug>.md` before doing anything else — with the global rules
installed that happens automatically, and without them the sentence above is
what triggers it.
