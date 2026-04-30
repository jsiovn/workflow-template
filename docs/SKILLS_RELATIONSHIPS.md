# Skills Relationships

A map of every skill under `skills/` — what each one does, who calls it, who it calls, and where it sits in the overall workflow. Read this before customizing or adding a skill so the new piece slots into an existing seam instead of creating a parallel one.

The canonical end-user description of the workflow lives in `templates/BEADS_WORKFLOW.md` (which is what gets shipped into downstream repos). This document is the _internal_ view: the skills as a graph.

---

## 1. The three execution modes

Every skill belongs to exactly one of three modes. The mode boundary is what the `<HARD-GATE>` blocks in many SKILL.md files are protecting.

```mermaid
flowchart LR
    subgraph PLAN["🧠 Planner mode<br/>(no code, no claims)"]
        BS[brainstorming]
        PR[planner-research]
        BP[beads-planner]
        PB[plan-beads<br/>orchestrator]
        VB[validate-beads]
    end

    subgraph EXEC["🔨 Executor mode<br/>(one bead, one session)"]
        BC[beads-claim]
        WP[writing-plans]
        IMP[(implementation)]
        SD[systematic-debugging]
        VBC[verification-before-completion]
        RCR[requesting-code-review]
        BCL[beads-close]
        EO[executor-once<br/>orchestrator]
        EL[executor-loop<br/>orchestrator]
        ELE[executor-loop-epic<br/>orchestrator]
    end

    subgraph SWARM["🐝 Swarm mode<br/>(coordinator + fresh workers)"]
        SE[swarm-epic<br/>coordinator]
        EBW[execute-bead-worker]
        RE[review-epic]
        FDB[finishing-a-development-branch]
    end

    subgraph CC["🧰 Cross-cutting helpers"]
        TRE[target-runtime-exec]
        GAH[game-action-harness<br/>profile=game-re only]
    end

    PLAN -->|hands off epic| EXEC
    PLAN -->|hands off epic| SWARM
    EXEC -->|epic complete| FDB
    SWARM -->|epic complete| RE --> FDB
    EXEC -.uses.-> CC
    SWARM -.uses.-> CC
```

**Hard rule encoded in the diagram:** planner skills must NOT invoke executor or swarm skills. The bead-creation handoff is the _only_ legal exit from planner mode.

---

## 2. Skill catalog (one-liner per skill)

| Skill                            | Mode                            | Role                                               | Invoked by                                                                | Invokes                                                                            |
| -------------------------------- | ------------------------------- | -------------------------------------------------- | ------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| `brainstorming`                  | planner                         | Turn fuzzy idea into a settled design              | `plan-beads`, user                                                        | `planner-research` (optional)                                                      |
| `planner-research`               | planner                         | Resolve factual unknowns before bead creation      | `brainstorming`, `plan-beads`                                             | —                                                                                  |
| `beads-planner`                  | planner                         | Translate settled plan into epic + tasks           | `plan-beads`                                                              | —                                                                                  |
| `plan-beads`                     | planner (orchestrator)          | Run a full planner session end-to-end              | user                                                                      | `brainstorming` → `planner-research` → `beads-planner` → `validate-beads`          |
| `validate-beads`                 | planner                         | Quality gate before swarm execution                | `plan-beads`, user                                                        | —                                                                                  |
| `beads-claim`                    | executor                        | Find + claim one ready bead                        | `executor-*` orchestrators, user                                          | —                                                                                  |
| `writing-plans`                  | executor                        | Write the implementation plan for the claimed bead | `executor-*` orchestrators, user                                          | `requesting-code-review` (for plan review during chunked drafting)                 |
| `systematic-debugging`           | executor                        | Root-cause investigation when blocked              | implementation step                                                       | `game-action-harness` (phase 3, if installed)                                      |
| `verification-before-completion` | executor                        | Evidence-before-claims gate                        | `executor-*` orchestrators                                                | `game-action-harness` (if installed)                                               |
| `requesting-code-review`         | executor                        | Dispatch the local code-reviewer subagent (`.claude/agents/code-reviewer.md` / `.codex/agents/code-reviewer.md`) | `executor-*` orchestrators (required, not optional)                       | —                                                                                  |
| `beads-close`                    | executor                        | Close bead + create follow-ups + commit            | `executor-*` orchestrators, user                                          | —                                                                                  |
| `executor-once`                  | executor (orchestrator)         | One bead, end-to-end, fresh context                | user                                                                      | `beads-claim` → `writing-plans` → impl → `build-and-test` → verify → `beads-close` |
| `executor-loop`                  | executor (orchestrator)         | Sequential beads from the global ready queue       | user                                                                      | same chain as `executor-once`, repeated                                            |
| `executor-loop-epic`             | executor (orchestrator)         | Sequential beads scoped to one epic                | user                                                                      | same chain + `review-epic` + `finishing-a-development-branch`                      |
| `swarm-epic`                     | swarm                           | Coordinate parallel workers under one epic         | user                                                                      | `execute-bead-worker` (per bead), `review-epic`, `finishing-a-development-branch`  |
| `execute-bead-worker`            | swarm                           | Implement one assigned bead; reports back          | `swarm-epic` only                                                         | —                                                                                  |
| `review-epic`                    | swarm                           | Epic-level quality gate after all beads close      | `swarm-epic`, `executor-loop-epic`                                        | —                                                                                  |
| `finishing-a-development-branch` | swarm/exec                      | Sync backup mirror, push, create PR                | `swarm-epic`, `executor-loop-epic`, user                                  | —                                                                                  |
| `target-runtime-exec`            | cross-cutting                   | Route build/test/run through local or SSH          | implementation steps, `build-and-test`                                    | —                                                                                  |
| `game-action-harness`            | cross-cutting (profile=game-re) | Trigger in-game actions for verification           | `writing-plans`, `systematic-debugging`, `verification-before-completion` | —                                                                                  |

> Note: `build-and-test` is **not** in `skills/` — it lives under `templates/.codex/skills/build-and-test/` and `templates/.claude/skills/build-and-test/` because it is the one skill the downstream repo specializes (stage 2). Treat it as the implicit verification step in every executor chain.

---

## 3. Planner session flow (`plan-beads` orchestration)

```mermaid
flowchart TD
    START([User: 'plan this thing']) --> PB[plan-beads]
    PB --> Q1{Topic<br/>clear?}
    Q1 -->|no| ASK[Ask clarifying Qs]
    ASK --> Q1
    Q1 -->|yes| BS[brainstorming]
    BS --> Q2{Material<br/>factual unknowns?}
    Q2 -->|yes| PR[planner-research]
    PR --> SETTLE
    Q2 -->|no| SETTLE[Settled plan]
    SETTLE --> CONFIRM[/User confirms<br/>bead creation/]
    CONFIRM --> BP[beads-planner<br/>creates epic + tasks]
    BP --> Q3{Intended for<br/>swarm?}
    Q3 -->|yes| VB["validate-beads"]
    VB --> Q4{Pass?}
    Q4 -->|no, tighten| BP
    Q4 -->|yes| DONE([Stop. Executor<br/>runs in new session])
    Q3 -->|manual only| DONE

    style PB fill:#e1f5ff
    style BS fill:#e1f5ff
    style PR fill:#e1f5ff
    style BP fill:#e1f5ff
    style VB fill:#e1f5ff
```

**Key invariant:** the planner session ends at `DONE`. It does NOT invoke `beads-claim`, `writing-plans`, or any implementation skill. The user starts executor work in a _separate_ session.

---

## 4. Single-bead executor flow (`executor-once`)

This is the canonical 8-step chain. `executor-loop` and `executor-loop-epic` are just this chain repeated, with different ready-bead selection rules.

```mermaid
flowchart TD
    START([User: 'execute bead X'<br/>or 'execute next ready']) --> EO[executor-once]
    EO --> S1[1. beads-claim<br/>bd update --status in_progress]
    S1 --> S2[2. writing-plans<br/>save to docs/plans/...]
    S2 --> S3[3. implementation]
    S3 --> Q1{Stuck?}
    Q1 -->|yes| SD[systematic-debugging]
    SD --> S3
    Q1 -->|no| S4[4. build-and-test<br/>repo-local skill]
    S4 --> Q2{Pass?}
    Q2 -->|no, in scope| S3
    Q2 -->|no, blocked| BLOCK[Stop, update bead]
    Q2 -->|yes| S5[5. verification-before-completion]
    S5 --> S6[6. requesting-code-review<br/>dispatch code-reviewer subagent]
    S6 --> S7[7. beads-close<br/>+ commit]
    S7 --> END([Stop. Do NOT auto-claim<br/>another bead])

    style S1 fill:#fff4e1
    style S2 fill:#fff4e1
    style S6 fill:#fff4e1
    style S7 fill:#fff4e1
    style S3 fill:#fff4e1
    style S4 fill:#fff4e1
    style S5 fill:#fff4e1
    style S6 fill:#fff4e1
    style SD fill:#ffe1e1
    style BLOCK fill:#ffe1e1
```

**`executor-loop` vs `executor-loop-epic` vs `executor-once`:**

```mermaid
flowchart LR
    subgraph EO[executor-once]
        EOA[Pick 1 bead] --> EOB[Run chain] --> EOC([Stop])
    end
    subgraph EL[executor-loop]
        ELA[Pick from<br/>bd ready] --> ELB[Run chain] --> ELC{More ready?}
        ELC -->|yes| ELA
        ELC -->|no/blocked| ELD([Stop])
    end
    subgraph ELE[executor-loop-epic]
        ELEA[Pick from<br/>bd ready --parent epic] --> ELEB[Run chain] --> ELEC{More in epic?}
        ELEC -->|yes| ELEA
        ELEC -->|no| ELED[review-epic] --> ELEE[finishing-a-development-branch] --> ELEF([Stop])
    end
```

All three are **compatibility paths**. The SKILL.md files explicitly call out that `swarm-epic` is preferred for epic-scoped work, and fresh `executor-once` sessions are preferred over long loops that accumulate context.

---

## 5. Swarm flow (`swarm-epic` + workers)

This is the primary path for epic execution. The coordinator stays thin; workers are spawned fresh per bead.

```mermaid
flowchart TD
    USER([User: 'swarm epic E']) --> SE[swarm-epic<br/>coordinator]
    SE --> CHK{validate-beads<br/>passed?}
    CHK -->|no| STOP1([Stop. Run<br/>validate-beads first])
    CHK -->|yes| BR[Create branch<br/>epic/E-id]
    BR --> AM[Init Agent Mail<br/>+ acquire epic lock]
    AM --> READY[bd ready --parent E]
    READY --> LOOP{Ready<br/>beads left?}
    LOOP -->|yes| RES[Reserve file scope<br/>via Agent Mail]
    RES --> ASSIGN[Assign bead to<br/>fresh worker]
    ASSIGN --> WORK[execute-bead-worker]

    WORK --> WR[Worker reports:<br/>files, verification,<br/>blocker classification]
    WR --> RVW[Coordinator reviews]
    RVW --> CLOSE{Close?}
    CLOSE -->|ok| BCLOSE[bd close<br/>release reservations]
    CLOSE -->|blocked: clarify/env| RETRY[Reuse worker]
    CLOSE -->|blocked: contract/scope| FIX[Tighten bead<br/>or split]
    BCLOSE --> LOOP
    RETRY --> WORK
    FIX --> READY

    LOOP -->|no| BAT[final build-and-test]
    BAT --> RE[review-epic]
    RE --> FIND{P1<br/>findings?}
    FIND -->|yes| READY
    FIND -->|no, P2/P3 ok| FDB[finishing-a-development-branch<br/>sync mirror, push, PR]
    FDB --> DONE([Stop. PR open])

    style SE fill:#e1ffe1
    style WORK fill:#fff4e1
    style RE fill:#e1ffe1
    style FDB fill:#e1ffe1
```

**Worker hard rules** (encoded in `execute-bead-worker`):

- Workers never run `bd update` or `bd close` — only the coordinator mutates bead state.
- Workers receive the full persisted contract (`Read:` / `Inputs:` / `Files:` / `Verify:` / `Risk:` / `Parallel:` / `Escalate:`) — they don't replay coordinator chat.
- Workers reserve their `Files:` scope via Agent Mail before editing.
- A blocked worker classifies the blocker as one of `clarify` / `env` / `contract` / `scope` so the coordinator can decide whether to reuse the worker or replace it.

---

## 6. Cross-cutting helpers

These are not phase skills; they're called _from inside_ phase skills.

```mermaid
flowchart LR
    subgraph TARGET[target-runtime-exec]
        TR[Reads .beads/workflow/<br/>runtime-target.json]
        TR --> TLOC[local exec]
        TR --> TSSH[ssh exec via<br/>scripts/shared/target_runtime.py]
    end

    subgraph HARNESS[game-action-harness<br/>profile=game-re only]
        H1[Catalog .harness/actions.yaml]
        H2[scripts/shared/harness.py trigger]
        H3[Optional: observe via<br/>existing project hooks]
        H1 --> H2 --> H3
    end

    BAT[build-and-test] -.uses.-> TARGET
    IMPL[implementation] -.uses.-> TARGET
    WP[writing-plans] -.verification section.-> HARNESS
    SD[systematic-debugging] -.phase 3 repro.-> HARNESS
    VBC[verification-before-completion] -.harness-first rule.-> HARNESS
```

**Key seams to know about:**

- `target-runtime-exec` is the _only_ place runtime-routing logic lives. Anything that builds, tests, runs, deploys, or migrates should funnel through it. Reading files / git inspection should NOT.
- `game-action-harness` is profile-gated. It's only present in repos bootstrapped with `profile=game-re`. The "harness-first rule" appears in `writing-plans`, `systematic-debugging`, and `verification-before-completion` to enforce that the agent triggers actions itself instead of asking the user to play the game.

---

## 7. Full invocation graph

The complete picture — every legal "skill X invokes skill Y" edge in one diagram. Solid lines = orchestration; dashed lines = optional/conditional invocation.

```mermaid
flowchart TD
    USER([user])

    USER --> PB[plan-beads]
    USER --> EO[executor-once]
    USER --> EL[executor-loop]
    USER --> ELE[executor-loop-epic]
    USER --> SE[swarm-epic]
    USER --> VB[validate-beads]
    USER --> BC[beads-claim]
    USER --> BCL[beads-close]
    USER --> FDB[finishing-a-development-branch]

    PB --> BS[brainstorming]
    PB -.-> PR[planner-research]
    PB --> BP[beads-planner]
    PB --> VB
    BS -.-> PR

    EO --> BC
    EO --> WP[writing-plans]
    EO -.-> SD[systematic-debugging]
    EO --> BAT[build-and-test]
    EO --> VBC[verification-before-completion]
    EO -.-> RCR[requesting-code-review]
    EO --> BCL

    EL --> BC
    EL --> WP
    EL -.-> SD
    EL --> BAT
    EL --> VBC
    EL -.-> RCR
    EL --> BCL

    ELE --> BC
    ELE --> WP
    ELE -.-> SD
    ELE --> BAT
    ELE --> VBC
    ELE -.-> RCR
    ELE --> BCL
    ELE --> RE[review-epic]
    ELE --> FDB

    SE --> EBW[execute-bead-worker]
    SE --> BAT
    SE --> RE
    SE --> FDB

    EBW --> BAT
    EBW -.-> SD

    SD -.-> GAH[game-action-harness]
    VBC -.-> GAH
    WP -.-> GAH

    BAT -.-> TRE[target-runtime-exec]
    EBW -.-> TRE

    classDef planner fill:#e1f5ff,stroke:#0277bd
    classDef executor fill:#fff4e1,stroke:#ef6c00
    classDef swarm fill:#e1ffe1,stroke:#2e7d32
    classDef cross fill:#f3e1ff,stroke:#6a1b9a

    class PB,BS,PR,BP,VB planner
    class EO,EL,ELE,BC,WP,SD,BAT,VBC,RCR,BCL executor
    class SE,EBW,RE,FDB swarm
    class TRE,GAH cross
```

---

## 8. Customizing or adding a skill

When you add or rename a skill, four places need to stay consistent:

1. **The SKILL.md** — frontmatter `name` + `description`, `<HARD-GATE>` if it must not run in the wrong mode, and explicit "invoked by / invokes" links to other skills.
2. **`scripts/posix/scaffold-repo-files.sh` and `scripts/windows/scaffold-repo-files.ps1`** — these are the authority on what gets copied into downstream `.codex/skills/` and `.claude/skills/`. New skill ⇒ add the copy line. Removed skill ⇒ add a `rm -rf` / `Remove-Item` line so existing downstreams clean up on next `update-skills`.
3. **Profile gating** — if the skill is profile-specific (like `game-action-harness`), add it to `profile_gated_skills` in both scaffold scripts. Don't gate ad hoc.
4. **`templates/AGENTS.snippet.md` and `templates/CLAUDE.snippet.md`** — if the skill should appear in the managed instructions block downstream, mention it there. The block lives between `<!-- BEGIN/END TEMPLATE BD WORKFLOW -->` markers — never remove or rename those markers.

**Where to slot a new skill — quick decisions:**

| If your new skill is…                                         | Add it as a peer of…                           | Make sure it…                                                                                                        |
| ------------------------------------------------------------- | ---------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| A new planning step (e.g., risk assessment, security review)  | `planner-research`                             | Has a planner `<HARD-GATE>`; only invocable from `plan-beads` or directly by the user                                |
| A new executor step (e.g., perf benchmark, contract test)     | `verification-before-completion`               | Plugs into the 8-step chain in `executor-once` / `executor-loop` / `executor-loop-epic` — update those orchestrators |
| A new orchestrator (different bead-selection strategy)        | `executor-loop`                                | Composes the same 8-step chain; doesn't reinvent claim/close logic                                                   |
| A new cross-cutting helper (new runtime, new external system) | `target-runtime-exec` or `game-action-harness` | Is invoked _from inside_ phase skills, doesn't introduce a new mode                                                  |
| A new swarm role (e.g., reviewer worker)                      | `execute-bead-worker`                          | Coordinator (`swarm-epic`) is the only writer of bead state; workers report back                                     |

**Anti-patterns to avoid** (these are repeatedly enforced in the existing SKILL.md `<HARD-GATE>` blocks):

- A planner skill that claims a bead or writes code.
- An executor skill that re-plans the epic or creates new top-level beads outside the active one.
- A worker skill that mutates `bd` state directly instead of reporting to the coordinator.
- A skill that invokes `build-and-test` without going through `target-runtime-exec` for runtime-dependent commands.
- A second source of truth for task state (parallel TODO trackers, planning JSONs alongside Beads).

---

## 9. Reading order for newcomers

If you're trying to learn the system from scratch, read the SKILL.md files in this order:

1. `plan-beads` — understand the planner session shape
2. `brainstorming` — the heart of planner mode
3. `beads-planner` + `validate-beads` — how a plan becomes Beads
4. `executor-once` — the canonical executor chain
5. `writing-plans` — the executor's most opinionated step
6. `verification-before-completion` — why "tests pass" requires evidence
7. `swarm-epic` + `execute-bead-worker` — the multi-agent path
8. `target-runtime-exec` — runtime routing seam
9. `game-action-harness` (only if working with `profile=game-re`)

Then re-read this document. The graph should make more sense.
