# RALPH Ecosystem

Tools for AI-driven development with Claude, based on the Claude Masterclass.

## Overview

The RALPH (Recursive Autonomous Loop for Programming Help) ecosystem helps you:
1. **Plan** your project with structured PRDs
2. **Build** features automatically with Claude
3. **Verify** each feature with tests before moving on

```
New projects:    plan-init → prd.json → ralph-init → ralph.sh
                   (plan)      (PRD)     (scaffold)    (build)

Existing projects: ralph-existing → smart prd.json → ralph.sh
                   (analyze+scaffold)    (PRD)         (build)
```

---

## Installation

### One-Line Install (Recommended)

```bash
curl -sL https://raw.githubusercontent.com/anons191/ClaudeMasterclass/main/install.sh | bash
```

This installs `plan-init`, `plan-claude`, `ralph-init`, and `ralph-existing` to `~/bin`.

### Manual Install

```bash
# Download individual scripts to your project
curl -O https://raw.githubusercontent.com/anons191/ClaudeMasterclass/main/plan-init.sh
curl -O https://raw.githubusercontent.com/anons191/ClaudeMasterclass/main/plan-claude.sh
curl -O https://raw.githubusercontent.com/anons191/ClaudeMasterclass/main/ralph-init.sh
curl -O https://raw.githubusercontent.com/anons191/ClaudeMasterclass/main/ralph-existing.sh
chmod +x *.sh
```

### Clone Repository

```bash
git clone https://github.com/anons191/ClaudeMasterclass.git
cd ClaudeMasterclass
```

---

## Quick Start

After installation, in any new project:

```bash
# 1. Plan your project with Claude interview (recommended)
plan-claude

# 2. Scaffold RALPH files
ralph-init

# 3. Build with Claude
./ralph.sh 10
```

**Alternative:** Use `plan-init` for simple bash-based planning (no Claude interview).

If you downloaded scripts directly (manual install):
```bash
./plan-claude.sh   # or ./plan-init.sh
./ralph-init.sh
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

### 2. Plan-Claude: AI-Driven Planning (Recommended)

Uses Claude's AskUserQuestion tool for comprehensive project interviews. **This is the recommended planning approach** from the masterclass.

```bash
plan-claude
```

**Modes:**
| Mode | Use When |
|------|----------|
| Start fresh | New project, full interview |
| Refine existing | Features are vague, need more detail |
| Add new features | Looking for missing features/edge cases |

**Interview Phases:**
1. **Project Overview** - Type, purpose, target users, MVP scope
2. **Feature Discovery** - Core functionality, UI, data, integrations
3. **Technical Decisions** - Frameworks, deployment, libraries
4. **Feature Sizing** - Split large features, define verification steps
5. **Validation** - Error handling, edge cases, priority order

**Output:**
- `plans/prd.json` - Your features (RALPH-compatible)
- `progress.txt` - Planning notes for development context

**Best for:**
- Any new project (start here!)
- Complex technical decisions
- Finding edge cases and missing features
- Properly sizing features for RALPH

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

### 4. Ralph-Existing: Codebase Analyzer (For Existing Projects)

Analyzes your existing codebase with Claude and generates a smart PRD pre-populated with detected features.

```bash
ralph-existing
# or
./ralph-existing.sh
```

**What it does:**
1. Scans your codebase (respects .gitignore)
2. Sends key files to Claude for analysis
3. Detects: tech stack, existing features, code structure, refactoring opportunities
4. Generates a smart `prd.json` with:
   - Existing features marked as `passes: true`
   - Improvement tasks marked as `passes: false`
5. Scaffolds all RALPH files

**Analysis Includes:**
| Category | What it Finds |
|----------|---------------|
| Tech Stack | Language, framework, libraries, testing setup, database |
| Features | Already-implemented functionality with verification steps |
| Structure | Architecture, entry points, routes, models, services |
| Refactoring | Large files, complexity issues, suggested improvements |

**When to Use:**
- Onboarding an existing codebase to RALPH
- You want Claude to understand what's already built
- You want automated refactoring/improvement suggestions

**Generated Files:**
| File | Purpose |
|------|---------|
| `ralph.sh` | Automated loop |
| `ralph-once.sh` | Human-in-the-loop |
| `plans/prd.json` | Smart PRD (pre-populated!) |
| `plans/KNOWLEDGE.md` | Codebase knowledge base |
| `plans/analysis.json` | Raw analysis data |
| `progress.txt` | LLM memory with codebase context |

---

### 5. KNOWLEDGE.md: Codebase Knowledge Base

A persistent documentation file that captures everything Claude learns about your codebase.

**Created by:** `ralph-existing` (auto-generated from analysis)

**Contains:**
- **Architecture Overview** - How the codebase is structured, patterns, data flow
- **Build Commands** - How to install, build, test, run, lint
- **Code Conventions** - Naming patterns, file organization, coding standards
- **Key Files** - Important files and their purposes
- **Gotchas** - Non-obvious things developers should know
- **Learning Log** - New discoveries appended during RALPH iterations

**How it works:**
1. `ralph-existing` generates initial KNOWLEDGE.md from codebase analysis
2. RALPH reads it before each iteration for context
3. When Claude learns something new, it appends to the Learning Log
4. Knowledge accumulates over time, making builds more consistent

**Example Learning Log entry:**
```markdown
## Learning Log

[2024-01-15] - Discovered that the auth middleware requires Redis connection.
Must run `docker-compose up redis` before running tests.

[2024-01-16] - The UserService uses a repository pattern. All DB access goes
through repositories in src/repositories/, not direct model calls.
```

---

### 6. LEARNINGS.md: Runtime Discoveries & Error Solutions

A separate file that captures what Claude learns while encountering errors or unfamiliar code.

**Created by:** `ralph-existing` (template) or Claude (during first error)

**Contains:**
- **Error Solutions** - Build/test failures and how they were fixed
- **Library/Framework Notes** - API discoveries and usage patterns
- **Debugging Tips** - Project-specific debugging strategies
- **External Doc References** - Useful documentation links found
- **Questions & Answers** - When Claude asked the user for help

**When Claude encounters errors or unknowns:**
1. First checks LEARNINGS.md - solution may already be documented
2. Searches project docs (README, docs/, comments)
3. Uses web search for framework/library documentation
4. Asks user if still stuck (via AskUserQuestion)
5. **Always records the solution** in LEARNINGS.md for future iterations

**Example entry:**
```markdown
## Error Solutions

### [2024-01-15] Error: "Module not found: @prisma/client"

**What happened:** Tests failed with missing prisma client
**What was tried:** Running npm install (didn't help)
**Solution:** Need to run `npx prisma generate` after install
**Why:** Prisma generates the client from schema.prisma at build time
```

**Difference from KNOWLEDGE.md:**
- `KNOWLEDGE.md` = Architecture, conventions, static knowledge
- `LEARNINGS.md` = Runtime discoveries, error solutions, debugging tips

---

### 7. Ralph.sh: The Build Loop

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

### 8. Ralph-Once.sh: Human-in-the-Loop

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

## Notifications (via ntfy.sh)

RALPH can send push notifications to your phone/desktop when important events occur.

### Setup

1. Pick a unique topic name (e.g., `my-ralph-builds-abc123`)
2. Subscribe on your phone: Install [ntfy app](https://ntfy.sh) and subscribe to your topic
3. Or subscribe in browser: Visit `ntfy.sh/YOUR_TOPIC`
4. Edit `ralph.sh` and `ralph-once.sh`, set: `NTFY_TOPIC="your-topic-name"`

### Events that trigger notifications

| Event | Priority | When |
|-------|----------|------|
| Build Started | Default | RALPH begins a new build run |
| Iteration Done | Low | Each feature iteration completes |
| Needs Help | **Urgent** | Claude asked a question or is stuck |
| Error Detected | High | Build/test error encountered |
| Build Complete | High | All features successfully built |
| Max Iterations | High | Stopped before completing PRD |

### Example notification flow

```
📱 RALPH Started - Building 5 features over 10 max iterations
📱 Iteration 1 Done - 4 features remaining
📱 Iteration 2 Done - 3 features remaining
📱 RALPH Needs Help - Claude is asking for human input!  ← Check terminal!
📱 Iteration 3 Done - 2 features remaining
📱 RALPH Complete! - All features built successfully after 4 iterations 🎉
```

### Why ntfy.sh?

- **Free** - No account needed, no costs
- **Simple** - Just HTTP POST, no API keys
- **Cross-platform** - iOS, Android, Desktop, Web
- **Self-hostable** - Run your own server if you prefer

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

### Onboarding an Existing Codebase (Recommended)

```bash
# 1. Run the analyzer - it does everything!
ralph-existing
# Scans codebase, generates smart PRD, scaffolds RALPH

# 2. Review the auto-generated PRD
cat plans/prd.json
# Verify detected features, adjust priorities

# 3. Start building improvements
./ralph-once.sh
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
│   ├── KNOWLEDGE.md    # Codebase knowledge (architecture, conventions)
│   ├── LEARNINGS.md    # Runtime discoveries (error solutions, debugging)
│   ├── analysis.json   # Raw analysis data (if using ralph-existing)
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
