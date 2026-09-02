# CooperAgent — Agent Working Rules

Installed to `~/.grok/AGENTS.md` (Grok) and `~/.omp/agent/AGENTS.md` (Oh My Pi)
by the setup script. Source: `templates/agent-rules.md`. Edit the source,
commit, re-run setup — edits to the installed copies are lost on update.

> Grok truncates rules files at 10,000 characters without warning. Adding a rule
> means removing another, not stacking.

## 1. Think before coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them — don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity first

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

## 3. Surgical changes

**Touch only what you must. Clean up only your own mess.**

- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it — don't delete it.
- Remove imports and variables that YOUR changes made unused. Only those.

The test: every changed line traces directly to the user's request.

## 4. Goal-driven execution

**Define success criteria. Loop until verified.**

- "add validation" → "write tests for invalid inputs, then make them pass"
- "fix the bug" → "write a test that reproduces it, then make it pass"

For multi-step work, state the plan first — each step with how you will verify
it. Strong criteria let you work to completion; weak criteria ("make it work")
force constant clarification.

## 5. Checkpoints — write before you forget

Compaction and new sessions erase detail. Files don't.

```
.cooper/context/<slug>.md   your state: where am I    (gitignored)
docs/plans/<slug>.md        plan + evidence, shared   (in git)
```

**At the start of a session**, read `.cooper/context/` before doing anything.
Never guess the state from memory or from a compaction summary — both can be
wrong. Then confirm in three lines: where things stand, next step, blockers.

If the directory doesn't exist, say so and start fresh. Do not create it until
there is something worth recording.

**At every task boundary** — a step reaches `[x]`, a bug is verified fixed, a
decision is made — update the checkpoint. Whatever the context level. The task
boundary is the trigger, not a context threshold.

Never checkpoint mid-investigation. A summary of a half-formed state misleads
the next session.

Status markers:

```
[ ] not started   [~] in progress   [x] done + proven   [!] failed
```

`[x]` only with **evidence** — command output, test results, real numbers —
pasted beneath the step. If new evidence contradicts a step already marked
`[x]`, move it back to `[~]` and write the correction.

Checkpoint file format — keep it the same every time:

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

"Don't repeat" is the most valuable section. Dead ends that go unrecorded get
walked again.

Write via a temp file — overwriting in place leaves a window where the file is
empty, and a session that dies there loses its checkpoint:

```bash
tmp=$(mktemp) && cat > "$tmp" <<'CP'
...
CP
mv "$tmp" .cooper/context/<slug>.md
```

## 6. CooperAgent specifics

**Context ceiling is 131,072 tokens, hard**, for prompt AND answer together.
Exceeding it truncates the answer mid-sentence; it does not slow down.
Auto-compaction fires at 80%. Let it run; don't defer it.

**Limit tool output — the largest controllable token cost.** Measured here: 20
turns (3.3%) accounted for 72.1% of all prefill. Capping tool output at 2,000
tokens cuts context growth by 86.5%.

- Don't `cat` large files; read the part you need (`sed -n '120,180p'`).
- Bound searches: `| head -50`, or `grep -c` when you only need the count.
- Don't re-run a command whose output is already in context.
- `git diff` without a path can burn tens of thousands of tokens — name paths.

**Don't break the prefix cache.** Measured here: median prefill is 238 tokens
because the slot's KV is reused — but 8 requests (2.2%) with prefill above 20K
accounted for 72.3% of all prefill, peaking at 151,712 tokens. The cache holds
only while the start of the prompt is byte-identical. So: never insert anything
above existing context, and don't resume an old session to continue work — start
clean and read the checkpoint instead. Resuming forces a full re-prefill.

**Zero-Secret.** Never write API keys, passwords, or tokens into code,
committed config, commit messages, or plan files. Use placeholders and read
values from the environment. This applies to tool output pasted as evidence:
redact first.

**Commits.** Conventional Commits (`feat:`, `fix:`, `docs:`, `refactor:`,
`test:`, `chore:`), imperative subject, no trailing period. Every code change
gets a `CHANGELOG.md` entry: context, what changed (full paths), evidence,
impact, rollback. Don't `push` unless asked.

## 7. How to work

Do what was asked, in full. If part is blocked, finish the rest and say plainly
which part you left and why — narrowing scope is the user's decision, not the
agent's.

Report outcomes as they are. If a test fails, say it failed and show the output.
If a step was skipped, say so. Never claim done for work you haven't verified.
