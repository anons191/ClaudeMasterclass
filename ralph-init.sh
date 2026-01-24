#!/bin/bash

# RALPH Loop Initializer
# Scaffolds all files needed for a RALPH loop with Claude
# Usage: ./ralph-init.sh or curl ... | bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════╗"
echo "║     RALPH Loop Initializer            ║"
echo "║     AI-Driven Development Setup       ║"
echo "╚═══════════════════════════════════════╝"
echo -e "${NC}"

# --- Project Type Detection ---
detect_project_type() {
    if [ -f "package.json" ]; then
        PROJECT_TYPE="node"
        # Check for pnpm, yarn, or npm
        if [ -f "pnpm-lock.yaml" ]; then
            PKG_MANAGER="pnpm"
        elif [ -f "yarn.lock" ]; then
            PKG_MANAGER="yarn"
        else
            PKG_MANAGER="npm"
        fi
        TEST_CMD="$PKG_MANAGER test"
        TYPECHECK_CMD="$PKG_MANAGER run typecheck"
    elif [ -f "pyproject.toml" ] || [ -f "requirements.txt" ]; then
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
        TEST_CMD="echo 'TODO: Add your test command'"
        TYPECHECK_CMD="echo 'TODO: Add your typecheck command'"
    fi
}

# --- Prompt for Confirmation ---
confirm_project_type() {
    echo -e "${YELLOW}Detected project type: ${GREEN}$PROJECT_TYPE${NC}"
    echo ""
    echo "Project types available:"
    echo "  1) node     - Node.js (pnpm/npm/yarn)"
    echo "  2) python   - Python (pytest/mypy)"
    echo "  3) go       - Go (go test/go vet)"
    echo "  4) rust     - Rust (cargo test/cargo check)"
    echo "  5) generic  - Custom (you fill in commands)"
    echo ""
    read -p "Press Enter to confirm, or enter number to change: " choice

    case $choice in
        1)
            PROJECT_TYPE="node"
            read -p "Package manager (pnpm/npm/yarn) [pnpm]: " PKG_MANAGER
            PKG_MANAGER=${PKG_MANAGER:-pnpm}
            TEST_CMD="$PKG_MANAGER test"
            TYPECHECK_CMD="$PKG_MANAGER run typecheck"
            ;;
        2)
            PROJECT_TYPE="python"
            TEST_CMD="pytest"
            TYPECHECK_CMD="mypy ."
            ;;
        3)
            PROJECT_TYPE="go"
            TEST_CMD="go test ./..."
            TYPECHECK_CMD="go vet ./..."
            ;;
        4)
            PROJECT_TYPE="rust"
            TEST_CMD="cargo test"
            TYPECHECK_CMD="cargo check"
            ;;
        5)
            PROJECT_TYPE="generic"
            read -p "Enter test command: " TEST_CMD
            read -p "Enter typecheck command: " TYPECHECK_CMD
            ;;
        "")
            # User pressed Enter, keep detected values
            ;;
        *)
            echo -e "${RED}Invalid choice, using detected type${NC}"
            ;;
    esac

    echo ""
    echo -e "${GREEN}Using: $PROJECT_TYPE${NC}"
    echo -e "  Test command: ${BLUE}$TEST_CMD${NC}"
    echo -e "  Typecheck command: ${BLUE}$TYPECHECK_CMD${NC}"
    echo ""
}

# --- Create plans directory ---
create_directories() {
    echo -e "${YELLOW}Creating directories...${NC}"
    mkdir -p plans
    echo -e "${GREEN}✓ Created plans/${NC}"
}

# --- Generate ralph.sh ---
generate_ralph_sh() {
    echo -e "${YELLOW}Generating ralph.sh...${NC}"

    cat > ralph.sh << 'RALPH_SCRIPT'
#!/bin/bash

# RALPH Loop - Automated AI Development
# Usage: ./ralph.sh <max_iterations>
# Now with real-time visibility and notifications!

set -e

# ─────────────────────────────────────────────────────────────
# NOTIFICATION CONFIG (via ntfy.sh)
# Set your topic to receive push notifications on phone/desktop
# Get started: just pick a unique topic name and subscribe at ntfy.sh/YOUR_TOPIC
# ─────────────────────────────────────────────────────────────
NTFY_TOPIC=""  # e.g., "my-ralph-builds" - leave empty to disable notifications

# Notification function
notify() {
    local title="$1"
    local message="$2"
    local priority="${3:-default}"  # low, default, high, urgent
    local tags="${4:-robot}"        # emoji tags
    if [ -n "$NTFY_TOPIC" ]; then
        curl -s -H "Title: $title" -H "Priority: $priority" -H "Tags: $tags" \
            -d "$message" "ntfy.sh/$NTFY_TOPIC" > /dev/null 2>&1 || true
    fi
}

if [ -z "$1" ]; then
    echo "Usage: $0 <iterations>"
    echo "Example: $0 10"
    exit 1
fi

# Create logs directory
mkdir -p logs

# Create log file with timestamp
LOG_FILE="logs/ralph-$(date +%Y-%m-%d-%H-%M-%S).log"
echo "Logging to: $LOG_FILE"
echo ""

# Count remaining features
count_remaining() {
    grep -c '"passes": false' plans/prd.json 2>/dev/null || echo "0"
}

# Notify build start
TOTAL_FEATURES=$(count_remaining)
notify "RALPH Started" "Building $TOTAL_FEATURES features over $1 max iterations" "default" "rocket"

for ((i=1; i<=$1; i++)); do
    REMAINING=$(count_remaining)
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

    echo ""
    echo "========================================"
    echo "  RALPH Loop - Iteration $i of $1"
    echo "  Time: $TIMESTAMP"
    echo "  Features remaining: $REMAINING"
    echo "  Log: $LOG_FILE"
    echo "========================================"
    echo ""

    # Log iteration header
    echo "" >> "$LOG_FILE"
    echo "======================================== ITERATION $i ========================================" >> "$LOG_FILE"
    echo "Started: $TIMESTAMP" >> "$LOG_FILE"
    echo "Features remaining: $REMAINING" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"

    # Create temp files
    PROMPT_FILE=$(mktemp)
    OUTPUT_FILE=$(mktemp)

    cat > "$PROMPT_FILE" << 'EOF'
Read these files first for context (if they exist):
- @plans/KNOWLEDGE.md (codebase architecture, conventions)
- @plans/LEARNINGS.md (error solutions, discoveries from previous iterations)
- @plans/prd.json (features to build)
- @progress.txt (what's been done)

Then:

1. Find the highest-priority feature to work on and work only on that feature.
   This should be the one YOU decide has the highest priority - not necessarily the first in the list.

2. Implement the feature. If KNOWLEDGE.md exists, follow the conventions documented there.

3. Check that the types check via: __TYPECHECK_CMD__
   And that the tests pass via: __TEST_CMD__
   (If these commands don't exist yet, set them up first)

4. Update the PRD (plans/prd.json) with the work that was done - set "passes" to true for the completed feature.

5. Append your progress to the progress.txt file.

6. If KNOWLEDGE.md exists and you learned something new about architecture/conventions,
   append it to the "Learning Log" section with today's date.
   If KNOWLEDGE.md doesn't exist, create it with architecture notes.

7. Make a git commit of that feature.

WHEN YOU ENCOUNTER ERRORS OR UNFAMILIAR CODE:
- First, check plans/LEARNINGS.md - the solution may already be documented
- Search for README.md files, docs/ folder, or inline comments in the codebase
- Use web search to find framework/library documentation if needed
- If still stuck, use AskUserQuestion to ask the user for help
- ALWAYS record what you learned in plans/LEARNINGS.md (create it if it doesn't exist):
  - Under "Error Solutions" for build/test failures
  - Under "Library/Framework Notes" for API discoveries
  - Under "Questions Asked & Answers" if you asked the user

IMPORTANT RULES:
- ONLY WORK ON A SINGLE FEATURE
- STAY UNDER 100K CONTEXT - If a feature is too large, break it into smaller pieces
- It's better to do less and succeed than to fill up context and fail
- ALWAYS document solutions when you solve errors - future iterations need this!

OUTPUT STATUS UPDATES as you work using this format:
[STATUS] Reading PRD...
[STATUS] Selected feature: <feature description>
[STATUS] Creating: <filename>
[STATUS] Editing: <filename>
[STATUS] Running: <command>
[STATUS] Tests: PASSED/FAILED
[STATUS] Looking up docs for: <topic>
[STATUS] Recording learning: <brief description>
[STATUS] Committing...

If, while implementing the feature, you notice the PRD is complete (all features have passes: true), output <promise>COMPLETE</promise>.
EOF

    # Run Claude with real-time output AND capture to file
    # Use unbuffer command if available (gstdbuf on macOS via brew install coreutils)
    if command -v stdbuf &> /dev/null; then
        cat "$PROMPT_FILE" | stdbuf -oL claude --dangerously-skip-permissions 2>&1 | tee -a "$LOG_FILE" "$OUTPUT_FILE" || true
    elif command -v gstdbuf &> /dev/null; then
        cat "$PROMPT_FILE" | gstdbuf -oL claude --dangerously-skip-permissions 2>&1 | tee -a "$LOG_FILE" "$OUTPUT_FILE" || true
    else
        cat "$PROMPT_FILE" | claude --dangerously-skip-permissions 2>&1 | tee -a "$LOG_FILE" "$OUTPUT_FILE" || true
    fi

    # Cleanup prompt file
    rm -f "$PROMPT_FILE"

    # Log completion
    echo "" >> "$LOG_FILE"
    echo "Iteration $i completed at $(date +"%Y-%m-%d %H:%M:%S")" >> "$LOG_FILE"

    # Check for completion
    if grep -q "<promise>COMPLETE</promise>" "$OUTPUT_FILE" 2>/dev/null; then
        rm -f "$OUTPUT_FILE"
        echo ""
        echo "========================================"
        echo "  PRD COMPLETE after $i iterations!"
        echo "  Full log: $LOG_FILE"
        echo "========================================"
        notify "RALPH Complete!" "All features built successfully after $i iterations" "high" "tada,white_check_mark"
        exit 0
    fi

    # Check if Claude asked the user a question (needs human input)
    if grep -qi "AskUserQuestion\|need.*input\|please.*help\|stuck\|cannot.*proceed" "$OUTPUT_FILE" 2>/dev/null; then
        notify "RALPH Needs Help" "Iteration $i: Claude is asking for human input. Check the terminal!" "urgent" "warning,question"
    fi

    # Check for errors/failures
    if grep -qi "error:\|failed\|exception\|cannot.*find\|not.*found" "$OUTPUT_FILE" 2>/dev/null; then
        if ! grep -qi "fixed\|resolved\|solved" "$OUTPUT_FILE" 2>/dev/null; then
            notify "RALPH Error" "Iteration $i: Encountered an error. May need attention." "high" "x,warning"
        fi
    fi

    # Notify iteration complete
    NEW_REMAINING=$(count_remaining)
    notify "Iteration $i Done" "$NEW_REMAINING features remaining" "low" "hammer"

    rm -f "$OUTPUT_FILE"
done

echo ""
echo "========================================"
echo "  Reached max iterations ($1)"
echo "  PRD may not be complete"
echo "  Full log: $LOG_FILE"
echo "========================================"
notify "RALPH Stopped" "Reached max iterations ($1). PRD may not be complete." "high" "stop_sign"
RALPH_SCRIPT

    # Replace placeholders with actual commands
    sed -i.bak "s|__TEST_CMD__|$TEST_CMD|g" ralph.sh
    sed -i.bak "s|__TYPECHECK_CMD__|$TYPECHECK_CMD|g" ralph.sh
    rm -f ralph.sh.bak

    chmod +x ralph.sh
    echo -e "${GREEN}✓ Created ralph.sh${NC}"
}

# --- Generate ralph-once.sh ---
generate_ralph_once_sh() {
    echo -e "${YELLOW}Generating ralph-once.sh...${NC}"

    cat > ralph-once.sh << 'RALPH_ONCE_SCRIPT'
#!/bin/bash

# RALPH Once - Single Iteration (Human-in-the-Loop)
# Usage: ./ralph-once.sh
# Run, review the changes, then run again

set -e

# ─────────────────────────────────────────────────────────────
# NOTIFICATION CONFIG (via ntfy.sh)
# Same topic as ralph.sh - set to receive notifications
# ─────────────────────────────────────────────────────────────
NTFY_TOPIC=""  # e.g., "my-ralph-builds" - leave empty to disable

notify() {
    local title="$1"
    local message="$2"
    local priority="${3:-default}"
    local tags="${4:-robot}"
    if [ -n "$NTFY_TOPIC" ]; then
        curl -s -H "Title: $title" -H "Priority: $priority" -H "Tags: $tags" \
            -d "$message" "ntfy.sh/$NTFY_TOPIC" > /dev/null 2>&1 || true
    fi
}

# Count remaining features
count_remaining() {
    grep -c '"passes": false' plans/prd.json 2>/dev/null || echo "0"
}

REMAINING=$(count_remaining)
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

echo ""
echo "========================================"
echo "  RALPH Once - Human in the Loop"
echo "  Time: $TIMESTAMP"
echo "  Features remaining: $REMAINING"
echo "========================================"
echo ""

# Create temp files
PROMPT_FILE=$(mktemp)
OUTPUT_FILE=$(mktemp)
cat > "$PROMPT_FILE" << 'EOF'
Read these files first for context (if they exist):
- @plans/KNOWLEDGE.md (codebase architecture, conventions)
- @plans/LEARNINGS.md (error solutions, discoveries from previous iterations)
- @plans/prd.json (features to build)
- @progress.txt (what's been done)

Then:

1. Find the highest-priority feature to work on and work only on that feature.

2. Implement the feature. If KNOWLEDGE.md exists, follow the conventions documented there.

3. Check that the types check via: __TYPECHECK_CMD__
   And that the tests pass via: __TEST_CMD__

4. Update the PRD (plans/prd.json) - set "passes" to true for the completed feature.

5. Append your progress to the progress.txt file.

6. If KNOWLEDGE.md exists and you learned something new about architecture/conventions,
   append it to the "Learning Log" section. Create KNOWLEDGE.md if it doesn't exist.

7. Make a git commit of that feature.

WHEN YOU ENCOUNTER ERRORS OR UNFAMILIAR CODE:
- First, check plans/LEARNINGS.md - the solution may already be documented
- Search for README.md files, docs/ folder, or inline comments in the codebase
- Use web search to find framework/library documentation if needed
- If still stuck, use AskUserQuestion to ask the user for help
- ALWAYS record what you learned in plans/LEARNINGS.md (create it if it doesn't exist)

IMPORTANT RULES:
- ONLY WORK ON A SINGLE FEATURE
- STAY UNDER 100K CONTEXT
- ALWAYS document solutions when you solve errors!

OUTPUT STATUS UPDATES as you work.

If the PRD is complete (all features have passes: true), output <promise>COMPLETE</promise>.
EOF

# Run Claude with the prompt file
if command -v stdbuf &> /dev/null; then
    cat "$PROMPT_FILE" | stdbuf -oL claude --dangerously-skip-permissions 2>&1 | tee "$OUTPUT_FILE"
elif command -v gstdbuf &> /dev/null; then
    cat "$PROMPT_FILE" | gstdbuf -oL claude --dangerously-skip-permissions 2>&1 | tee "$OUTPUT_FILE"
else
    cat "$PROMPT_FILE" | claude --dangerously-skip-permissions 2>&1 | tee "$OUTPUT_FILE"
fi

# Cleanup
rm -f "$PROMPT_FILE"

# Check for completion
if grep -q "<promise>COMPLETE</promise>" "$OUTPUT_FILE" 2>/dev/null; then
    notify "RALPH Complete!" "All features built successfully!" "high" "tada,white_check_mark"
fi

# Check for questions needing input
if grep -qi "AskUserQuestion\|need.*input\|please.*help" "$OUTPUT_FILE" 2>/dev/null; then
    notify "RALPH Asked Question" "Claude needs your input!" "high" "question"
fi

NEW_REMAINING=$(count_remaining)
rm -f "$OUTPUT_FILE"

echo ""
echo "========================================"
echo "  Iteration complete. Review changes."
echo "  Features remaining: $NEW_REMAINING"
echo "  Run ./ralph-once.sh again to continue."
echo "========================================"
RALPH_ONCE_SCRIPT

    # Replace placeholders with actual commands
    sed -i.bak "s|__TEST_CMD__|$TEST_CMD|g" ralph-once.sh
    sed -i.bak "s|__TYPECHECK_CMD__|$TYPECHECK_CMD|g" ralph-once.sh
    rm -f ralph-once.sh.bak

    chmod +x ralph-once.sh
    echo -e "${GREEN}✓ Created ralph-once.sh${NC}"
}

# --- Generate prd.json ---
generate_prd_json() {
    # Don't overwrite existing PRD!
    if [ -f "plans/prd.json" ]; then
        echo -e "${GREEN}✓ plans/prd.json already exists - keeping your features${NC}"
        return
    fi

    echo -e "${YELLOW}Generating plans/prd.json...${NC}"

    cat > plans/prd.json << 'PRD_JSON'
[
  {
    "category": "example",
    "description": "EXAMPLE: Delete this and add your own features. This shows the format.",
    "steps": [
      "Step 1: What to do first",
      "Step 2: What to verify",
      "Step 3: Expected outcome"
    ],
    "passes": false
  },
  {
    "category": "functional",
    "description": "EXAMPLE: User can log in with email and password",
    "steps": [
      "Navigate to /login page",
      "Enter valid email and password",
      "Click submit button",
      "Verify redirect to dashboard",
      "Verify user session is created"
    ],
    "passes": false
  },
  {
    "category": "ui",
    "description": "EXAMPLE: Login form displays validation errors",
    "steps": [
      "Navigate to /login page",
      "Submit form with empty fields",
      "Verify error messages appear",
      "Verify fields are highlighted red"
    ],
    "passes": false
  }
]
PRD_JSON

    echo -e "${GREEN}✓ Created plans/prd.json${NC}"
}

# --- Generate progress.txt ---
generate_progress_txt() {
    echo -e "${YELLOW}Generating progress.txt...${NC}"

    cat > progress.txt << 'PROGRESS_TXT'
# Progress Log

This file tracks what has been accomplished. Claude appends to this file after each iteration.

---

## $(date +%Y-%m-%d)

Project initialized with RALPH loop.

Next: Replace the example features in plans/prd.json with your actual features.

---

PROGRESS_TXT

    # Replace the date placeholder with actual date
    sed -i.bak "s/\$(date +%Y-%m-%d)/$(date +%Y-%m-%d)/g" progress.txt
    rm -f progress.txt.bak

    echo -e "${GREEN}✓ Created progress.txt${NC}"
}

# --- Generate README ---
generate_readme() {
    echo -e "${YELLOW}Generating plans/README.md...${NC}"

    cat > plans/README.md << 'README_MD'
# RALPH Loop Setup

This project is configured with the RALPH (Recursive Autonomous Loop for Programming Help) system.

## Files

| File | Purpose |
|------|---------|
| `ralph.sh` | Automated loop - runs until PRD complete |
| `ralph-once.sh` | Single iteration - human reviews after each |
| `plans/prd.json` | Your features/requirements (the todo list) |
| `progress.txt` | LLM memory - tracks what's been done |

## Quick Start

### 1. Define Your Features
Edit `plans/prd.json` and replace the examples with your actual features:

```json
{
  "category": "functional",
  "description": "What the feature does",
  "steps": [
    "Step to verify it works",
    "Another verification step"
  ],
  "passes": false
}
```

### 2. Run RALPH

**Automated (full loop):**
```bash
./ralph.sh 10  # Run up to 10 iterations
```

**Human-in-the-loop:**
```bash
./ralph-once.sh  # Run once
# Review the changes
./ralph-once.sh  # Run again
# Repeat until done
```

## Tips

1. **Size tasks small** - Each feature should be completable in one iteration
2. **Be specific in steps** - Clear verification criteria help Claude know when it's done
3. **Check progress.txt** - See what Claude learned and did
4. **Use human-in-loop first** - Build trust before full automation

## How It Works

```
ralph.sh
    │
    ├── Read prd.json (what to build)
    ├── Read progress.txt (what's done)
    │
    ├── Pick highest priority feature
    ├── Implement it
    ├── Run tests & typecheck
    ├── Update prd.json (passes: true)
    ├── Append to progress.txt
    ├── Git commit
    │
    └── Loop until <promise>COMPLETE</promise>
```

## Customization

Edit the test/typecheck commands in `ralph.sh` and `ralph-once.sh` if needed:
- Current test command: `__TEST_CMD__`
- Current typecheck command: `__TYPECHECK_CMD__`
README_MD

    # Replace placeholders with actual commands
    sed -i.bak "s|__TEST_CMD__|$TEST_CMD|g" plans/README.md
    sed -i.bak "s|__TYPECHECK_CMD__|$TYPECHECK_CMD|g" plans/README.md
    rm -f plans/README.md.bak

    echo -e "${GREEN}✓ Created plans/README.md${NC}"
}

# --- Main ---
main() {
    # Check if already initialized
    if [ -f "ralph.sh" ]; then
        echo -e "${RED}RALPH already initialized in this directory.${NC}"
        read -p "Overwrite existing files? (y/N): " overwrite
        if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
            echo "Aborted."
            exit 1
        fi
    fi

    # Run setup
    detect_project_type
    confirm_project_type
    create_directories
    generate_ralph_sh
    generate_ralph_once_sh
    generate_prd_json
    generate_progress_txt
    generate_readme

    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║     RALPH Setup Complete!             ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
    echo ""
    echo "Files created:"
    echo "  - ralph.sh         (automated loop)"
    echo "  - ralph-once.sh    (human-in-the-loop)"
    echo "  - plans/prd.json   (your features)"
    echo "  - progress.txt     (LLM memory)"
    echo "  - plans/README.md  (documentation)"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "  1. Edit plans/prd.json with your features"
    echo "  2. Run ./ralph-once.sh to test"
    echo "  3. Or run ./ralph.sh 10 for full automation"
    echo ""
}

main
