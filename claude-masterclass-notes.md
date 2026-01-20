# Claude Masterclass Notes

## 1. Project Setup Framework

### The Foundation: PRD / Todo List / Plans
- First step is creating your planning document (PRD, todo list, plans - naming doesn't matter)
- This document serves as the **base** of your project
- Design it so the agent/model can build out all the features

### Feature-Based Completion Criteria
- Identify all features needed for the product
- Features act as your checklist for knowing when the product is **complete**

### Workflow
```
Input → Output

PRD/Plans → [Feature] [Feature] → Product
            [Feature] [Feature]
```

**Key Insight:** Structure your planning documents so Claude can systematically work through each feature until the product is done.

### Testing & Verification
- Problem: We don't always know if the model created features **correctly**
- Solution: Include **tests** with your features
- Tests provide verification that features work as intended

### Sequential Build-Test Loop
1. Build Feature 1 → Test → Pass? → Move on
2. Build Feature 2 → Test → Pass? → Move on
3. Build Feature 3 → Test → Pass? → Move on
4. ...continue until all features complete

**Key Rule:** Only proceed to the next feature after current tests pass.

### Updated Workflow
```
PRD/Plans → Feature 1 → Test ✓ → Feature 2 → Test ✓ → ... → Verified Product
```

### Feature-Test Pairing
Every feature should have a corresponding test:
```
| Feature | Test |
| Feature | Test |
| Feature | Test |
```

**Big Picture:** We're now in an era where you can build something **serious** with these models - when you structure work properly with features + tests.

---

## 2. Better Planning: The Interview Method

### Beyond Basic Plan Mode
Instead of just asking Claude to make a plan, use a more thorough approach: **have Claude interview you**.

### The Technique
Prompt Claude to use the `AskUserQuestion` tool to interview you about your plan. This forces deeper thinking about:
- Technical implementation
- UI & UX decisions
- Concerns
- Tradeoffs

### Example Prompt
```
Read this plan file and interview me in detail using AskUserQuestionTool
about literally anything: technical implementation, UI & UX, concerns,
tradeoffs, etc.
```

**Why this works:** The interview process surfaces decisions and edge cases you might not have considered upfront. Claude asks, you answer, and the plan gets refined.

### Step 1: Master Planning
- **Get really good at planning** - this is the foundation
- Get comfortable with the Claude interview tool
- **Invest in your plans** - don't settle for generic plans
- The interview tool keeps asking questions **until Claude truly knows what you want built**

**Key mindset:** Don't rush planning. A thorough plan = better output.

---

## 3. The RALPH Loop

### Step 2: Only Use RALPH After You Master Planning
Don't jump to RALPH until you're solid at planning first.

### What You Need
1. **A good plan** - documented (e.g., `PRD.md`)
2. **Progress tracking** - document what's been done (e.g., `progress.txt`)

### How the RALPH Loop Works
```
    ┌──────────────────────────────────┐
    │                                  │
    ▼                                  │
 PRD.md ──────► Claude ──────► progress.txt
 (task list)   (works on       (updates what's
                task)           been done)
    ▲                                  │
    │                                  │
    └──────────────────────────────────┘
              (back to plan)
```

1. Model reads the plan (list of tasks)
2. Works on the first task
3. Finishes and documents progress
4. Goes back to plan file
5. Repeats until done
6. **Stops when the entire list is complete**

**Key insight:** The loop is self-documenting and self-terminating - it tracks progress automatically and knows when to stop (all tasks done).

### Critical Warning
**If you have a terrible plan, RALPH will not work for you.**

This is why Step 1 (mastering planning) comes first. RALPH is only as good as the plan you feed it. Garbage in = garbage out.

### How RALPH Builds
RALPH goes through your plan and builds **each feature step by step**.

**For each feature, the cycle is:**
```
Build Feature → Test → Lint → Next Feature
```

**RALPH Setup Checklist:**
- Each feature is created with a **test**
- After test passes, run **lint** (code quality check)
- Then move to next feature

### Visual: Sequential Feature-Test Flow
```
    Feature #1 ──────► Tests #1
        │                 │
        │            (pass?)
        ▼                 │
    Feature #2 ──────► Tests #2
        │                 │
        │            (pass?)
        ▼                 │
    Feature #3 ──────► Tests #3
        │                 │
        ▼                 ▼
       ...               ...
```

Each feature gets built, tested, and only after tests pass does it move to the next feature.

---

## 4. Tips & Tricks

1. **Use AskUserQuestion tool when planning** - let Claude interview you for better plans

2. **Don't over-obsess on MCP skills** - they're useful but not the main event

3. **Use RALPH after building something without it first** - understand the manual process before automating

4. **Context is more important than anything** - NEVER go over 50% of the context window. Keep it lean.

5. **Have audacity in planning** - take your time, think deeply about it. Planning is an art, not a chore.

6. **Don't be afraid to use pen and paper** - plan offline, sketch ideas, think away from the screen.

---

## 5. RALPH Loop Setup (Deep Dive)

### Traditional vs AI Sprints
- **Traditional engineering:** Time-boxed sprints (2 weeks, etc.)
- **AI world:** Don't worry about time-boxing as much
- Instead: Split work into a **multi-phased plan** in a `.md` file

### Task Prioritization
- Real engineers decide tasks based on **importance**
- Most important tasks first

### What RALPH Actually Is
RALPH = A **bash loop** that:
- Takes a task or list of tasks
- Gives them to the LLM
- Loops until all tasks are complete

### The Actual RALPH Script (ralph.sh)

```bash
set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <iterations>"
    exit 1
fi

for ((i=1; i<=$1; i++)); do
    echo "Iteration $i"
    echo "--------------------------------"
    result=$(claude --permission-mode acceptEdits -p "@plans/prd.json @progress.txt \
    1. Find the highest-priority feature to work on and work only on that feature. \
    This should be the one YOU decide has the highest priority - not necessarily the first item. \
    2. Check that the types check via pnpm typecheck and that the tests pass via pnpm test. \
    3. Update the PRD with the work that was done. \
    4. Append your progress to the progress.txt file. \
    Use this to leave a note for the next person working in the codebase. \
    5. Make a git commit of that feature. \
    ONLY WORK ON A SINGLE FEATURE. \
    If, while implementing the feature, you notice the PRD is complete, output <promise>COMPLETE</promise>")

    echo "$result"

    if [[ "$result" == *"<promise>COMPLETE</promise>"* ]]; then
        echo "PRD complete, exiting."
        exit 0
    fi
fi
```

### Script Breakdown

**Setup:**
- `set -e` - exit on error
- Takes number of iterations as argument

**The Loop (each iteration):**
1. **Find highest-priority feature** - Claude decides, not just first item
2. **Typecheck & test** - `pnpm typecheck` and `pnpm test`
3. **Update PRD** - mark what was done
4. **Append to progress.txt** - leave notes for next iteration
5. **Git commit** the feature

**Key Rules:**
- ONLY work on a **single feature** per iteration
- When PRD is complete, output `<promise>COMPLETE</promise>`
- Loop exits when it sees the completion marker

**Files Needed:**
- `plans/prd.json` - your plan/task list
- `progress.txt` - progress tracking

### Key: Passing Files to Claude
```bash
claude --permission-mode acceptEdits -p "@plans/prd.json @progress.txt ..."
```

**The `@` symbol** passes file contents to Claude:
- `@plans/prd.json` - Claude reads your full plan
- `@progress.txt` - Claude reads what's been done

This gives Claude the context it needs:
- What needs to be built (PRD)
- What's already complete (progress)

### PRD Structure (prd.json)
The PRD is a JSON array of **user stories** with this format:

```json
[
  {
    "category": "functional",
    "description": "Preview Changelog action visible when multiple versions exist",
    "steps": [
      "Select a repo with multiple versions",
      "Click the Actions dropdown",
      "Verify 'Preview Changelog' action is visible in the Version section"
    ],
    "passes": true
  },
  {
    "category": "ui",
    "description": "Beats display as three orange ellipsis dots below clip",
    "steps": [
      "Add a beat to a clip",
      "Verify three orange dots appear below the clip",
      "Verify dots are orange colored",
      "Verify dots form an ellipsis pattern"
    ],
    "passes": false
  }
]
```

**Each user story has:**
- `category` - type of feature ("functional", "ui", etc.)
- `description` - what the feature does
- `steps` - verification/test steps (acts as test criteria)
- `passes` - **completion status** (true/false)

**Key insight:** The `steps` array doubles as your test criteria. Claude knows exactly what to verify.

### The `passes` Flag: Dual Purpose
The `passes` field makes the PRD do double duty:

1. **Product Requirements Doc** - defines what to build
2. **Todo List** - tracks what's done

```
passes: false  →  "needs to be built"
passes: true   →  "complete"
```

**The Loop Visualized:**
```
┌─────────────────────────────────┐
│  [task] [task] [task] [task]    │
│  [task] [PICK] [task] [task]  ──┼──► [✓ DONE]
│  [task] [task] [task] [task]    │        │
│  [task] [task] [task] [task]    │        │
└─────────────────────────────────┘        │
         ▲                                 │
         └─────────────────────────────────┘
              (back to pick next)
```

Claude picks a task, completes it, marks `passes: true`, then loops back.

### Progress.txt: The Learning Log
A **free-text file** where the LLM appends what it has learned.

**Example:**
```
# Progress Log

## 2026-01-02

Implemented PRD item #8: Focus refresh uses shared hook with main page

- Created `app/hooks/use-focus-revalidate.ts` - reusable hook for focus-based revalidation
- Hook uses `useRevalidator` from react-router, supports optional interval polling
- Refactored `_index.tsx` to use the new hook instead of inline fetcher logic

Next: Changelog preview page needs to be created and should use this same hook

---

Implemented PRD items #1 & #2: Preview Changelog action visibility

- Added "Preview Changelog" action to Version section in Actions dropdown
- Action only shows when `versions.length > 1` (hidden for single-version repos)

Next: Create changelog preview page route at `app/routes/repos.$repoId.changelog.tsx`

---
```

**What progress.txt captures:**
- Which PRD items were completed
- What files were created/modified
- Technical decisions made
- **"Next:"** hints for the next iteration
- Knowledge transfer between loop iterations

**Key insight:** This is like leaving notes for the "next person" working on the code - except that next person is also Claude in the next loop iteration.

### progress.txt = The LLM's Memory
LLMs don't have persistent memory between sessions. **progress.txt IS the memory.**

- Each iteration, Claude reads it to know what happened before
- Each iteration, Claude appends to it with new learnings
- Without this, every loop would start from zero

**This solves the memory problem** - external file becomes persistent context.

### Priority-Based, Not Sequential
The prompt tells Claude:

> "Find the highest-priority feature to work on and work only on that feature.
> This should be the one YOU decide has the highest priority - **not necessarily the first in the list.**"

**Key:** Don't work in order. Let Claude **intelligently prioritize** what's most important.

- Claude evaluates all tasks
- Picks the highest-impact one
- Works only on that single feature

This is smarter than blindly going first-to-last.

### The Loop Rules (Summary)
Each iteration Claude must:
1. Find highest-priority feature
2. Run typecheck + tests (`pnpm typecheck`, `pnpm test`)
3. **Update the PRD** with work done (flip `passes` to true)
4. **Append to progress.txt** (leave notes for next iteration)
5. **Make a git commit** for that feature

**Critical Rule: ONLY WORK ON A SINGLE FEATURE**

This prevents Claude from biting off more than it can chew.

### Task Sizing Matters
If tasks in your PRD are too big, Claude gets swallowed up.

**Bad:** One giant task (like a Kanban card that's huge)
**Good:** Small, focused tasks that can be completed in one iteration

**Your job when writing the PRD:** Size tasks appropriately so Claude can finish each one cleanly in a single loop.

### The Completion Signal
At the end of the prompt, add:

> "If, while implementing the feature, you notice the PRD is complete, output `<promise>COMPLETE</promise>`"

This is the **termination signal**:
- Claude checks if all PRD tasks are done
- If yes, outputs `<promise>COMPLETE</promise>`
- The bash script detects this and exits the loop

```bash
if [[ "$result" == *"<promise>COMPLETE</promise>"* ]]; then
    echo "PRD complete, exiting."
    exit 0
fi
```

**This is how the loop knows when to stop.**

### Verification Every Iteration
From the prompt:
> "Check that the types check via pnpm typecheck and that the tests pass via pnpm test."

**Every single iteration** must verify:
- `pnpm typecheck` - types are valid
- `pnpm test` - tests pass

No moving forward until verification passes. This catches bugs immediately, not at the end.

### Optional: Notifications
The script can notify you when complete:
```bash
tt notify "PRD complete after $i iterations"
```
Useful for long-running loops so you know when it's done.

---

## 6. Research: Anthropic's Article on Long-Running Agents

**Source:** [Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents) - Anthropic Engineering, Nov 26, 2025

### The Core Problem
AI agents struggle across multiple context windows. Each new session starts with **no memory** of prior work - like engineers working shifts with no handoff.

### Two Failure Modes
1. **Over-ambition** - tries to do everything at once, runs out of context mid-implementation
2. **Premature completion** - declares project "done" after seeing partial progress

### Anthropic's Solution (aligns with RALPH!)

**Initializer Agent** (first session):
- Sets up foundation
- Creates progress tracking file
- Initial git commits

**Coding Agent** (subsequent sessions):
- Works on **single features** incrementally
- Maintains "clean state" code
- Well-documented, bug-free

### Best Practices from Anthropic
- **Feature Lists** - JSON files with all features marked as initially failing (like `prd.json`!)
- **Incremental Progress** - one feature per session (RALPH does this!)
- **Git Management** - descriptive commits bridge context windows
- **Comprehensive Testing** - verify end-to-end functionality
- **Session Startup Protocol** - check directory, read progress logs, run tests before implementing

**Key insight:** This article validates the RALPH approach - it's the same pattern Anthropic recommends.

### Robust Feedback Loops (from Anthropic)

**Three Feedback Mechanisms:**
1. **Progress Files** - `progress.txt` keeps a log of what's been done
2. **Git History** - descriptive commits serve as documentation, can revert bad changes
3. **Feature Lists** - JSON tracks what's complete, prevents false "done" declarations

**Verification Strategies:**
- **End-to-end testing is critical** - verify features as a human user would
- Use **browser automation** (Puppeteer MCP) for visual verification
- Run **basic functionality checks** at session start to catch undocumented bugs
- **Only mark features as "passing" after careful testing**

**Warning:** Without explicit prompting, agents tend to mark features complete without proper verification. You must deliberately require testing.

**Feedback Loop Summary:**
```
Code → Test → Verify End-to-End → Update Progress → Git Commit → Next Feature
        ↑                                                              │
        └──────────────── If tests fail, fix first ────────────────────┘
```

---

## 7. Modification: Human-in-the-Loop

You can modify RALPH to include **human review** in the loop.

### The Modified Flow
```
┌─────────────────────────────────┐
│  [task] [task] [task] [task]    │
│  [task] [PICK] [✓]   [task]    │
│  [task] [task] [task] [task]    │
└───────────┬─────────────────────┘
            │
            ▼
       ┌─────────┐
       │  Human  │  ◄── Review before marking complete
       │  (You)  │
       └────┬────┘
            │
            ▼
        ┌──────┐
        │  ✓   │  ◄── Only complete after human approval
        └──┬───┘
           │
           └────► Back to task list
```

### Why Human-in-the-Loop?
- **Catch mistakes** the LLM might miss
- **Verify quality** meets your standards
- **Course correct** before moving to next feature
- **Learn** what the LLM is doing well/poorly

### When to Use It
- Early in a project (build trust)
- Complex/critical features
- When you're learning RALPH
- When stakes are high

### When to Skip It
- Simple, well-defined tasks
- After you trust the loop is working
- Low-risk features

### Implementation: ralph-once.sh
For human-in-the-loop, use `ralph-once.sh` instead of `ralph.sh`:

```bash
set -e

claude --permission-mode acceptEdits "@plans/prd.json @progress.txt \
1. Find the highest-priority feature to work on and work only on that feature. \
This should be the one YOU decide has the highest priority - not necessarily the first in the list. \
2. Check that the types check via pnpm typecheck and that the tests pass via pnpm test. \
3. Update the PRD with the work that was done. \
4. Append your progress to the progress.txt file. \
Use this to leave a note for the next person working in the codebase. \
5. Make a git commit of that feature. \
ONLY WORK ON A SINGLE FEATURE. \
If, while implementing the feature, you notice the PRD is complete, output <promise>COMPLETE</promise>
"
```

**Key difference:** No loop - runs **once** and stops.

**Workflow:**
1. Run `ralph-once.sh`
2. Claude completes one feature
3. **You review** the work
4. Run `ralph-once.sh` again
5. Repeat until done

This puts you in control of each iteration.

---

### How to Run RALPH
```bash
./ralph.sh <max_iterations>
```

**Example:**
```bash
./ralph.sh 10
```
This runs the loop up to 10 times max. It will exit early if PRD completes before hitting the limit.

---

