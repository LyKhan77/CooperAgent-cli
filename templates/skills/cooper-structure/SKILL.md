---
name: cooper-structure
description: Propose how to organise this codebase. Surveys what is actually there, names the pattern it follows today, then offers two or three candidate structures with their trade-offs so the developer picks one and adjusts it. Writes a migration plan to .cooper/structure/rencana.md and never moves a single file. Use when asked to tidy up, restructure, split, or reorganise a project — not on every session.
---

# cooper-structure

On demand only. Reach for this when someone asks to tidy up, reorganise, split
apart, or decide where new code should live. Never run it unprompted: a codebase
that nobody complained about does not need a proposal.

**Announce first:** "Using the cooper-structure skill."

## The one hard rule

**This skill does not move, create, or delete a single source file.** It writes
exactly one artifact — the plan — and stops. Restructuring a repository is a
decision with consequences the developer owns: import churn, broken CI paths,
lost review history, a team that no longer knows where anything is. Proposing is
useful; doing it unasked is damage.

## Step 1 — Survey what is actually there

Bounded, not exhaustive. Read enough to be specific, not everything:

- **Manifests and lockfiles** — how many, and where. Two or more manifests means
  the repository is already multi-package whether or not anyone planned it.
- **Entry points** — how many deployable things exist (servers, CLIs, web apps).
- **Top-level source folders** and their names. `controllers/ services/ models/`
  says one thing; `users/ orders/ billing/` says another.
- **Business nouns** — count the distinct ones. Four or more is the point where
  layer-first folders start costing more than they save.
- **Duplication across entry points** — the same types, client, or helpers
  copied in two places is a shared package waiting to be named.
- **Test location** — alongside sources, or a separate `tests/` tree.
- **Existing conventions** — casing, plural vs singular, `index` files. Whatever
  the repository already does consistently is a convention; do not "fix" it.

Say what you found in numbers. "9 folders, 3 business nouns, 61 cross-folder
imports" earns a recommendation. "The structure could be improved" does not.

## Step 2 — Name the pattern it follows today

Use the shared vocabulary so the developer and the agent mean the same thing:

| Pattern | Shape | Fits when |
| :-- | :-- | :-- |
| **Layered** | `controller/ service/ repository/ model/` | one deployable, few domains, small team |
| **Feature-based** | `users/ orders/ payments/` | several business features; a change touches one folder |
| **Domain-driven** | `sales/ inventory/ accounting/` | domains have their own language and rules; bounded contexts are real |
| **Monorepo** | `apps/* + packages/*` + a workspace file | more than one deployable sharing code |
| **Polyrepo** | one repository per service | teams release on separate schedules and own their own pipelines |

Related terms worth naming when they apply: **shared package**, **public API**
(what a package deliberately exports), **dependency boundary** (`apps` may use
`packages`, never the reverse), **circular dependency**, **source of truth**
(e.g. `openapi.yaml` over generated clients), **generated files** and **build
artifacts** (which belong in neither the plan nor git), **code ownership**.

If the codebase follows no pattern consistently, say that plainly — it is the
most common finding and the most useful one.

## Step 3 — Offer candidates, not a verdict

**Always two or three, never one.** A single recommendation hides the trade-off
and invites the developer to accept it without thinking. Candidates are usually
*combinations* — "monorepo with feature-based apps", "single repo, layered, with
one shared package" — not menu items.

For each candidate give exactly four things:

```
### Candidate B — monorepo + feature-based per app

Shape
  apps/web/       features/users, features/orders
  apps/api/       features/users, features/orders
  packages/shared-types/

Why it fits here
  <tied to the numbers from step 1 — not general theory>

What it costs
  <import churn, build config, CI paths, review history, ramp-up>

When it is the wrong answer
  <the honest case against it>
```

Then stop and ask which one, and what they would change about it. Expect the
answer to be a mix — "B, but keep tests where they are". Fold the adjustment in
and confirm the result before writing anything.

## Step 4 — Write the plan

One file: `.cooper/structure/rencana.md`. If it already exists, read it and
update it — do not leave two competing plans in the repository.

```markdown
# Structure plan — <repo name>
Written: <YYYY-MM-DD>  ·  Chosen: <candidate + the developer's adjustments>

## Where it stands today
<pattern named, with the numbers from the survey>

## Target shape
<the directory tree, only as deep as it needs to be>

## Move map
src/controllers/users.ts  ->  apps/api/src/features/users/controller.ts
<one line per file; if there are more than ~40, group by folder and say so>

## Order of work
1. <step that can be finished and verified on its own>
2. ...

## Risks
- <import count that will need fixing>
- <build config: tsconfig paths, go.mod, workspace file>
- <CI paths, CODEOWNERS, anything referencing old paths>

## Not in scope
<what this plan deliberately leaves alone>
```

Steps must be individually verifiable. A plan whose first step is "move
everything" cannot be reviewed, stopped halfway, or rolled back.

Finish by reporting the path and the headline number, in two or three lines. Do
not paste the plan back into the conversation.

## What not to do

**Do not touch code.** Not a `git mv`, not an empty directory, not a README
placeholder. The plan is the deliverable.

**Do not propose a monorepo for one deployable.** Workspace tooling has a real
cost and one application does not repay it.

**Do not restructure to match a framework tutorial.** The question is what this
codebase and this team need, not what a starter template looks like.

**Do not touch generated files or build artifacts** in the move map. They are
outputs; they move when their source does.
