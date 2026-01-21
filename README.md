# RALPH Ecosystem

Tools for AI-driven development with Claude, based on the Claude Masterclass.

## Overview

The RALPH (Recursive Autonomous Loop for Programming Help) ecosystem helps you:
1. **Plan** your project with structured PRDs
2. **Build** features automatically with Claude
3. **Verify** each feature with tests before moving on

```
plan-init.sh → prd.json → ralph-init.sh → ralph.sh
   (plan)        (PRD)      (scaffold)     (build)
```

---

## Quick Start

```bash
# 1. Plan your project
./plan-init.sh

# 2. Scaffold RALPH files
./ralph-init.sh

# 3. Build with Claude
./ralph.sh 10
```

---

## Tools

### 1. Plan-Init: PRD Builder

Creates a structured `prd.json` through guided interviews.

```bash
./plan-init.sh
```

**Features:**
- Project description intake
- Built-in templates (webapp, api, cli, library)
- Feature size warnings (prevents tasks too big for one iteration)
- Verification step helper
- Completeness and priority validation
- Save custom templates for reuse

**Menu Options:**
| Option | Description |
|--------|-------------|
| New project | Full guided workflow |
| Modify existing | Load and edit existing prd.json |
| Quick start | Pick a template and customize |

**Output:** `plans/prd.json`

---

### 2. Plan-Claude: Deep-Dive Interviews

Uses Claude's AskUserQuestion tool for detailed feature interviews.

```bash
./plan-claude.sh
```

**Modes:**
| Mode | Use When |
|------|----------|
| Refine existing | Features are vague, need more detail |
| Add new features | Looking for missing features/edge cases |
| Full interview | Starting fresh, want thorough planning |

**Best for:**
- Complex technical decisions
- UI/UX details
- Finding edge cases
- Breaking down large features

---

### 3. Ralph-Init: RALPH Scaffolder

Sets up all files needed for the RALPH loop.

```bash
./ralph-init.sh
```

**Auto-detects project type:**
- Node.js (pnpm/npm/yarn)
- Python (pytest/mypy)
- Go (go test/go vet)
- Rust (cargo test/cargo check)

**Generated Files:**
| File | Purpose |
|------|---------|
| `ralph.sh` | Automated loop (runs until PRD complete) |
| `ralph-once.sh` | Single iteration (human-in-the-loop) |
| `plans/prd.json` | Your features (if not exists) |
| `progress.txt` | LLM memory between iterations |
| `plans/README.md` | Usage documentation |

---

### 4. Ralph.sh: The Build Loop

Automated AI development loop.

```bash
./ralph.sh <max_iterations>

# Example: Run up to 10 iterations
./ralph.sh 10
```

**Each iteration Claude will:**
1. Pick highest-priority feature (not just first in list)
2. Implement the feature
3. Run typecheck and tests
4. Update prd.json (`passes: true`)
5. Append to progress.txt
6. Git commit

**Stops when:** All features pass or max iterations reached.

---

### 5. Ralph-Once.sh: Human-in-the-Loop

Single iteration for manual review between each feature.

```bash
./ralph-once.sh
# Review changes
./ralph-once.sh
# Review changes
# Repeat...
```

**Use when:**
- Building trust with the system
- Complex/critical features
- Learning how RALPH works

---

## PRD Format

The `prd.json` file is both your requirements doc AND todo list:

```json
[
  {
    "category": "functional",
    "description": "User can log in with email and password",
    "steps": [
      "Navigate to /login",
      "Enter valid credentials",
      "Submit form",
      "Verify redirect to dashboard"
    ],
    "passes": false
  }
]
```

| Field | Purpose |
|-------|---------|
| `category` | Type: functional, ui, api, data, config |
| `description` | What the feature does |
| `steps` | Verification criteria (how to test) |
| `passes` | Completion status (false → true when done) |

---

## Workflow Examples

### New Project from Scratch

```bash
# 1. Create your PRD interactively
./plan-init.sh
# Choose "New project", describe it, add features

# 2. (Optional) Deep-dive on complex features
./plan-claude.sh
# Choose mode 1 to refine features

# 3. Scaffold RALPH files
./ralph-init.sh
# Confirm project type, generates scripts

# 4. Run the loop
./ralph.sh 10
```

### Adding Features to Existing Project

```bash
# 1. Modify existing PRD
./plan-init.sh
# Choose "Modify existing prd.json"

# Or use Claude for discovery
./plan-claude.sh
# Choose mode 2 "Add new features"

# 2. Run RALPH to build new features
./ralph.sh 5
```

### Human-in-the-Loop Development

```bash
# 1. Plan and scaffold as usual
./plan-init.sh
./ralph-init.sh

# 2. Build one feature at a time
./ralph-once.sh
# Review the changes, check the code
git diff

# 3. Continue if satisfied
./ralph-once.sh
# Repeat until done
```

---

## Tips

### Planning
- **Invest time in planning** - bad plans = bad output
- **Keep features small** - one iteration each
- **Be specific in verification steps** - Claude needs to know when it's done
- **Use pen and paper** - think before typing

### Building
- **Start with human-in-the-loop** - build trust first
- **Check progress.txt** - see what Claude learned
- **Stay under 50% context window** - context is everything
- **Don't over-obsess on MCP** - focus on planning

### Task Sizing
If a feature seems too big, split it:

**Too big:**
> "Complete user authentication system"

**Right size:**
> "User registration form"
> "User login form"
> "Password reset flow"
> "Session management"

---

## File Structure

After setup, your project will have:

```
your-project/
├── plans/
│   ├── prd.json        # Your features
│   └── README.md       # RALPH docs
├── progress.txt        # LLM memory
├── ralph.sh            # Automated loop
└── ralph-once.sh       # Human-in-loop
```

---

## Resources

- [Anthropic: Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
- Claude Masterclass notes: `claude-masterclass-notes.md`

---

## License

MIT
