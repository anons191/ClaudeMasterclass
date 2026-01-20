# RALPH Loop Tool - Project Plan

## Overview
A CLI tool to easily scaffold RALPH loop files for any project, enabling automated AI-driven development workflows.

## User Story
As a developer, I want to run a single command (`ralph init`) in any project directory to generate all the files needed to run a RALPH loop with Claude, so I can quickly set up automated feature development.

---

## Features

### Feature 1: CLI Initialization Command
**Category:** core
**Description:** Running `ralph init` scaffolds all RALPH files in the current directory
**Steps:**
- User runs `ralph init` in their project directory
- Tool detects project type (Node, Python, Go, etc.)
- Tool prompts to confirm detected type or select manually
- Tool generates all required files
- Tool displays success message with usage instructions
**Passes:** false

### Feature 2: Project Type Auto-Detection
**Category:** core
**Description:** Automatically detect project type from files and set appropriate test/lint commands
**Steps:**
- Check for `package.json` → Node.js (use pnpm/npm test)
- Check for `requirements.txt` or `pyproject.toml` → Python (use pytest)
- Check for `go.mod` → Go (use go test)
- Check for `Cargo.toml` → Rust (use cargo test)
- Fallback to generic placeholder if unknown
- Prompt user to confirm or override detected type
**Passes:** false

### Feature 3: Generate ralph.sh (Full Loop)
**Category:** core
**Description:** Generate the automated RALPH loop script
**Steps:**
- Create `ralph.sh` with configurable iteration count
- Include project-specific test/lint commands
- Include completion signal detection (`<promise>COMPLETE</promise>`)
- Include optional notification support (commented out)
- Make script executable
**Passes:** false

### Feature 4: Generate ralph-once.sh (Human-in-the-Loop)
**Category:** core
**Description:** Generate the single-iteration script for human review workflow
**Steps:**
- Create `ralph-once.sh` that runs one iteration and stops
- Same prompt structure as ralph.sh
- No loop wrapper
- User runs manually after each review
**Passes:** false

### Feature 5: Generate PRD Template (JSON)
**Category:** core
**Description:** Generate a structured prd.json with example user stories
**Steps:**
- Create `plans/prd.json` with JSON array structure
- Include 2-3 example user stories showing the format
- Each story has: category, description, steps, passes
- Examples clearly marked for user to replace
- All examples have `passes: false`
**Passes:** false

### Feature 6: Generate progress.txt
**Category:** core
**Description:** Create the progress log file for LLM memory
**Steps:**
- Create `progress.txt` with header template
- Include date placeholder
- Include example format for progress entries
- Include "Next:" section example
**Passes:** false

### Feature 7: Generate README for RALPH usage
**Category:** documentation
**Description:** Include a README explaining how to use the generated RALPH setup
**Steps:**
- Create `plans/README.md` with usage instructions
- Document ralph.sh usage (with iteration count)
- Document ralph-once.sh usage (human-in-loop workflow)
- Explain PRD structure and how to add features
- Explain progress.txt purpose
- Include tips for task sizing
**Passes:** false

### Feature 8: Single Script Distribution
**Category:** distribution
**Description:** Tool is available as a single downloadable script
**Steps:**
- Host script at accessible URL
- User can install via `curl -O <url>`
- Script is self-contained with no dependencies
- Works on macOS and Linux
**Passes:** false

---

## Technical Implementation

### Language/Runtime
- **Bash script** - simple, portable, no dependencies

### Project Structure
```
ralph-tool/
├── ralph-init.sh      # The main tool script
└── README.md          # How to install and use the tool
```

### Generated Files Structure
```
user-project/
├── plans/
│   ├── prd.json       # Product requirements / todo list
│   └── README.md      # Usage documentation
├── progress.txt       # LLM memory / progress log
├── ralph.sh           # Full automated loop
└── ralph-once.sh      # Human-in-the-loop variant
```

### Project Type Detection Logic
```bash
if [ -f "package.json" ]; then
    PROJECT_TYPE="node"
    TEST_CMD="pnpm test"
    TYPECHECK_CMD="pnpm typecheck"
elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
    PROJECT_TYPE="python"
    TEST_CMD="pytest"
    TYPECHECK_CMD="mypy ."
elif [ -f "go.mod" ]; then
    PROJECT_TYPE="go"
    TEST_CMD="go test ./..."
    TYPECHECK_CMD="go vet ./..."
elif [ -f "Cargo.toml" ]; then
    PROJECT_TYPE="rust"
    TEST_CMD="cargo test"
    TYPECHECK_CMD="cargo check"
else
    PROJECT_TYPE="generic"
    TEST_CMD="echo 'Add your test command'"
    TYPECHECK_CMD="echo 'Add your typecheck command'"
fi
```

### Permission Mode
- Default to `--permission-mode acceptEdits` for smooth automation

### Notifications (Optional)
Include commented-out lines for:
- `terminal-notifier` (macOS)
- `notify-send` (Linux)
- `ntfy` (cross-platform push)

---

## Success Criteria

1. User can run `ralph init` in any project
2. Tool correctly detects common project types
3. All 5 files are generated with correct content
4. ralph.sh runs a working RALPH loop
5. ralph-once.sh works for human-in-the-loop workflow
6. Generated PRD has clear example format
7. Tool works on macOS and Linux

---

## Out of Scope (Future)
- GUI interface
- Windows support (may work with WSL)
- Custom PRD formats (Markdown variant)
- Integration with specific CI/CD systems
- MCP server integration
