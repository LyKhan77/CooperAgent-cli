---
name: handoff
description: Hand off to a fresh session when context is nearly full or compaction is failing or too slow. Updates the checkpoint minimally and tells you what to say next. Cheap by design — it does not re-summarize the conversation.
---

# handoff

Use this when the context is nearly full, or compaction has failed, or it is
taking longer than you are willing to wait.

**It is cheap on purpose.** The checkpoint at `.cooper/context/<slug>.md` is
already being maintained at every task boundary, so there is nothing to
reconstruct. Do not re-read the conversation and do not write a long summary.

**Announce first:** "Using the handoff skill."

## What to do

1. Read the existing checkpoint. If none exists, create one now using the format
   in the global rules — this is the only case where handoff writes it in full.

2. Update only what has changed since it was last written:
   - **Where I am** — the current state, 1-3 sentences
   - the step markers `[ ] [~] [x] [!]`
   - **Next** — one concrete action
   - **Don't repeat** — anything tried and abandoned since the last update

3. Write it via a temp file, then move it into place.

4. Reply with **at most three lines**:

```
Checkpoint: .cooper/context/<slug>.md
State: <one sentence>
Continue in a new session with: "continue <slug>"
```

## What not to do

**Do not summarize the conversation.** That is what compaction does, and it is
what you are avoiding by using this skill.

**Do not paste code, diffs, or command output.** The checkpoint carries only
evidence lines already recorded at task boundaries.

**Do not ask questions.** The user is out of context and waiting. Write the
file and report.

## After

The user starts a new session and says "continue <slug>". The global rules make
the next session read `.cooper/context/` before doing anything, so the handoff
completes without anyone carrying text between sessions.
