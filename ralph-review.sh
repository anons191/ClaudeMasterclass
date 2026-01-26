#!/bin/bash

# RALPH Review - Code Quality & Bug Detection with Interview
# Uses Claude's AskUserQuestion tool for guided codebase review
# Part of the RALPH ecosystem
#
# Usage: ralph-review or ./ralph-review.sh

set -e

# ─────────────────────────────────────────────────────────────
# CONFIGURATION
# ─────────────────────────────────────────────────────────────
MAX_FILES=50
MAX_FILE_LINES=500
MAX_CONTEXT_CHARS=80000
REVIEW_OUTPUT="plans/review.json"
PROGRESS_FILE="review-progress.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ─────────────────────────────────────────────────────────────
# BANNER
# ─────────────────────────────────────────────────────────────
print_banner() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════╗"
    echo "║     RALPH Review - Code Quality & Bug Detection   ║"
    echo "║     Interactive Mode with Interview               ║"
    echo "╚═══════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# ─────────────────────────────────────────────────────────────
# PHASE 1: PROJECT DETECTION
# ─────────────────────────────────────────────────────────────

detect_project_type() {
    if [ -f "package.json" ]; then
        PROJECT_TYPE="node"
        if [ -f "pnpm-lock.yaml" ]; then
            PKG_MANAGER="pnpm"
        elif [ -f "yarn.lock" ]; then
            PKG_MANAGER="yarn"
        else
            PKG_MANAGER="npm"
        fi
    elif [ -f "pyproject.toml" ] || [ -f "requirements.txt" ]; then
        PROJECT_TYPE="python"
        PKG_MANAGER=""
    elif [ -f "go.mod" ]; then
        PROJECT_TYPE="go"
        PKG_MANAGER=""
    elif [ -f "Cargo.toml" ]; then
        PROJECT_TYPE="rust"
        PKG_MANAGER=""
    else
        PROJECT_TYPE="generic"
        PKG_MANAGER=""
    fi

    echo -e "${GREEN}Detected project type: ${YELLOW}$PROJECT_TYPE${NC}"
    if [ -n "$PKG_MANAGER" ]; then
        echo -e "  Package manager: ${BLUE}$PKG_MANAGER${NC}"
    fi
    echo ""
}

detect_monorepo() {
    if [ -f "lerna.json" ] || [ -f "pnpm-workspace.yaml" ] || [ -f "nx.json" ]; then
        IS_MONOREPO=true
    elif [ -d "packages" ] && [ $(ls -1 packages/ 2>/dev/null | wc -l) -gt 1 ]; then
        IS_MONOREPO=true
    elif [ -d "apps" ] && [ $(ls -1 apps/ 2>/dev/null | wc -l) -gt 1 ]; then
        IS_MONOREPO=true
    else
        IS_MONOREPO=false
    fi

    if [ "$IS_MONOREPO" = true ]; then
        echo -e "${YELLOW}Monorepo detected!${NC}"
        echo "Packages/apps found:"

        local packages=()
        [ -d "packages" ] && packages+=($(ls -1 packages/ 2>/dev/null))
        [ -d "apps" ] && packages+=($(ls -1 apps/ 2>/dev/null))

        local i=1
        for pkg in "${packages[@]}"; do
            echo "  $i) $pkg"
            ((i++))
        done
        echo "  $i) Analyze entire monorepo"
        echo ""
        read -p "Select package to analyze [${#packages[@]}+1 for all]: " pkg_choice

        if [ -n "$pkg_choice" ] && [ "$pkg_choice" -le "${#packages[@]}" ] 2>/dev/null; then
            FOCUS_DIR="${packages[$((pkg_choice-1))]}"
            if [ -d "packages/$FOCUS_DIR" ]; then
                FOCUS_DIR="packages/$FOCUS_DIR"
            elif [ -d "apps/$FOCUS_DIR" ]; then
                FOCUS_DIR="apps/$FOCUS_DIR"
            fi
            echo -e "Focusing on: ${GREEN}$FOCUS_DIR${NC}"
        else
            FOCUS_DIR="."
            echo "Analyzing entire monorepo"
        fi
        echo ""
    else
        FOCUS_DIR="."
    fi
}

# ─────────────────────────────────────────────────────────────
# PHASE 2: FILE COLLECTION (for context)
# ─────────────────────────────────────────────────────────────

categorize_files() {
    CONFIG_FILES=()
    ENTRY_FILES=()
    ROUTE_FILES=()
    MODEL_FILES=()
    TEST_FILES=()
    COMPONENT_FILES=()
    OTHER_FILES=()

    local file_list
    if [ -d ".git" ]; then
        file_list=$(git ls-files --cached "$FOCUS_DIR" 2>/dev/null)
    else
        file_list=$(find "$FOCUS_DIR" -type f \
            ! -path "*/node_modules/*" \
            ! -path "*/.git/*" \
            ! -path "*/vendor/*" \
            ! -path "*/dist/*" \
            ! -path "*/build/*" \
            2>/dev/null)
    fi

    while IFS= read -r file; do
        [ -z "$file" ] && continue

        local basename=$(basename "$file")
        local dirname=$(dirname "$file")

        # Skip binary and generated files
        case "$basename" in
            *.png|*.jpg|*.gif|*.ico|*.svg|*.woff|*.woff2|*.ttf|*.eot) continue ;;
            *.min.js|*.min.css|*.map|*.lock|package-lock.json) continue ;;
            *.pyc|*.class|*.jar|*.so|*.dylib) continue ;;
            .DS_Store|Thumbs.db) continue ;;
        esac

        # Categorize by filename patterns
        case "$basename" in
            package.json|pyproject.toml|Cargo.toml|go.mod|tsconfig*.json|.eslintrc*|.prettierrc*|webpack.config.*|vite.config.*|next.config.*|requirements.txt|setup.py|setup.cfg)
                CONFIG_FILES+=("$file")
                ;;
            main.*|index.*|app.*|server.*|__main__.py|cmd/*)
                ENTRY_FILES+=("$file")
                ;;
            *.test.*|*.spec.*|test_*|*_test.go|*_test.py|tests/*|__tests__/*)
                TEST_FILES+=("$file")
                ;;
            *)
                case "$dirname" in
                    */routes/*|*/api/*|*/pages/*|*/endpoints/*|*/handlers/*)
                        ROUTE_FILES+=("$file")
                        ;;
                    */models/*|*/schemas/*|*/types/*|*/entities/*|*/domain/*)
                        MODEL_FILES+=("$file")
                        ;;
                    */components/*|*/views/*|*/widgets/*|*/ui/*)
                        COMPONENT_FILES+=("$file")
                        ;;
                    *)
                        OTHER_FILES+=("$file")
                        ;;
                esac
                ;;
        esac
    done <<< "$file_list"
}

apply_context_limits() {
    SELECTED_FILES=()
    local total_chars=0
    local file_count=0

    local all_categories=(
        "CONFIG_FILES"
        "ENTRY_FILES"
        "ROUTE_FILES"
        "MODEL_FILES"
        "COMPONENT_FILES"
        "TEST_FILES"
        "OTHER_FILES"
    )

    for category in "${all_categories[@]}"; do
        eval "local files_in_category=(\"\${${category}[@]}\")"
        for file in "${files_in_category[@]}"; do
            [ $file_count -ge $MAX_FILES ] && break 2

            if [ -f "$file" ]; then
                local file_size=$(wc -c < "$file" 2>/dev/null || echo 0)

                if [ "$file_size" -gt 50000 ]; then
                    continue
                fi

                if [ $((total_chars + file_size)) -gt $MAX_CONTEXT_CHARS ]; then
                    continue
                fi

                SELECTED_FILES+=("$file")
                total_chars=$((total_chars + file_size))
                ((file_count++))
            fi
        done
    done

    SELECTED_FILE_COUNT=$file_count
    ESTIMATED_CHARS=$total_chars
}

build_file_manifest() {
    FILE_MANIFEST=""
    for file in "${SELECTED_FILES[@]}"; do
        FILE_MANIFEST+="- $file"$'\n'
    done
}

# ─────────────────────────────────────────────────────────────
# PHASE 3: CHECK EXISTING REVIEW
# ─────────────────────────────────────────────────────────────

check_existing_review() {
    if [ -f "$REVIEW_OUTPUT" ]; then
        echo -e "${YELLOW}Found existing $REVIEW_OUTPUT${NC}"
        echo ""
        echo "1) Start fresh (overwrite)"
        echo "2) Add to existing review"
        echo "3) Cancel"
        read -p "Choice [1]: " mode
        mode=${mode:-1}

        case $mode in
            1) MERGE_MODE=false ;;
            2) MERGE_MODE=true ;;
            *) echo "Cancelled."; exit 0 ;;
        esac
        echo ""
    else
        MERGE_MODE=false
    fi
}

# ─────────────────────────────────────────────────────────────
# PHASE 4: INTERVIEW & ANALYSIS
# ─────────────────────────────────────────────────────────────

run_interview() {
    echo -e "${CYAN}Starting code review interview...${NC}"
    echo ""

    PROMPT_FILE=$(mktemp)

    cat > "$PROMPT_FILE" << 'PROMPT'
You are an expert code reviewer specializing in bugs, security, performance, and code quality.

Your job is to:
1. Interview the developer using AskUserQuestion to understand their concerns
2. Analyze the codebase files
3. Generate a review.json file with discovered issues

## IMPORTANT: Use AskUserQuestion Tool

You MUST use the AskUserQuestion tool for the interview. Do NOT just ask questions in plain text.

## Interview Phases

### Phase 1: What Do You Want to Change?
START HERE. Use AskUserQuestion to ask the user directly what they want to change or improve.
Ask an open-ended question like: "What do you want to change or improve in this codebase?"
Let them explain their goals before diving into bug detection or code quality analysis.

This could be:
- Specific features they want to add or modify
- Problems they've noticed
- Areas they want to refactor
- Performance or security concerns

### Phase 2: Review Context
Use AskUserQuestion to understand:
- What areas of the codebase are you most concerned about?
- Are there any known issues or user-reported bugs?
- Have there been recent changes that might have introduced problems?
- Which areas are most critical to the application?

### Phase 3: Issue Type Focus
Use AskUserQuestion with options:
- Which issue types should be prioritized?
  Options: bugs, performance, security, refactoring opportunities, edge cases, all of the above
- What severity threshold matters most?
  Options: critical issues only, critical and high, all severities

### Phase 4: Scope Definition
Use AskUserQuestion to clarify:
- Are there specific directories or files to focus on?
- Are there files or patterns to exclude from review?
- How deep should the analysis go?
  Options: surface level (quick scan), moderate (standard review), thorough (deep dive)

## After Interview

Analyze the codebase files provided below and generate issues based on the interview responses.

## Files Available for Analysis

PROMPT

    # Append file list
    echo "" >> "$PROMPT_FILE"
    echo "The following files are available in this codebase:" >> "$PROMPT_FILE"
    echo '```' >> "$PROMPT_FILE"
    echo "$FILE_MANIFEST" >> "$PROMPT_FILE"
    echo '```' >> "$PROMPT_FILE"
    echo "" >> "$PROMPT_FILE"

    # Append file contents (limited)
    echo "## File Contents" >> "$PROMPT_FILE"
    echo "" >> "$PROMPT_FILE"

    for file in "${SELECTED_FILES[@]}"; do
        echo "### $file" >> "$PROMPT_FILE"
        echo '```' >> "$PROMPT_FILE"
        head -n $MAX_FILE_LINES "$file" 2>/dev/null >> "$PROMPT_FILE" || echo "(Could not read file)"
        echo '```' >> "$PROMPT_FILE"
        echo "" >> "$PROMPT_FILE"
    done

    # Continue prompt
    cat >> "$PROMPT_FILE" << 'PROMPT'

## Output Requirements

After the interview AND analysis, you MUST create exactly TWO files.
IMPORTANT: The plans/ directory already exists. Use the EXACT paths shown below.

### 1. plans/review.json (NOT review.json in root!)

Use the Write tool to create the file at path: plans/review.json
Create a JSON array with discovered issues. Format:
```json
[
  {
    "category": "bug|performance|security|refactor|edge-case",
    "severity": "critical|high|medium|low",
    "description": "Clear description of the issue",
    "file": "path/to/affected/file.ts",
    "line": 42,
    "steps": [
      "How to reproduce/verify the issue",
      "Suggested fix approach",
      "How to verify the fix worked"
    ],
    "passes": false
  }
]
```

### Category Definitions:
- **bug**: Logic errors, null checks, off-by-one errors, race conditions
- **performance**: N+1 queries, missing memoization, expensive operations in loops
- **security**: Input validation issues, injection vulnerabilities, secrets exposure
- **refactor**: Code duplication, overly complex functions, poor naming
- **edge-case**: Missing error handling, boundary conditions, empty state handling

### Severity Definitions:
- **critical**: Security vulnerabilities, data loss risk, application crashes
- **high**: Major functional bugs, significant performance issues
- **medium**: Minor bugs, moderate code quality issues
- **low**: Style issues, minor optimizations, nice-to-have improvements

### 2. review-progress.txt (in the project root)

Use the Write tool to create the file at path: review-progress.txt
Create a progress file with:
```
# Review Progress Log

## [Today's Date] - Code Review Session

### Interview Summary
- Areas of concern: [from interview]
- Focus types: [from interview]
- Scope: [from interview]

### Files Analyzed
- [list of files reviewed]

### Summary of Findings
- Critical issues: [count]
- High issues: [count]
- Medium issues: [count]
- Low issues: [count]

### Key Patterns Found
- [Notable patterns or recurring issues]

---
```

## Guidelines

1. Be specific - include file paths and line numbers when possible
2. Be actionable - every issue should have clear fix steps
3. Be conservative - don't flag non-issues or stylistic preferences unless asked
4. Prioritize by severity - list critical issues first
5. Group related issues when they share the same root cause

## Begin

Start by using AskUserQuestion to ask about the areas of the codebase the user is most concerned about.
PROMPT

    # Run Claude with interview mode
    echo -e "${YELLOW}Launching Claude for interview...${NC}"
    echo ""

    claude --permission-mode acceptEdits "$PROMPT_FILE"

    rm -f "$PROMPT_FILE"
}

# ─────────────────────────────────────────────────────────────
# PHASE 5: SUCCESS MESSAGE
# ─────────────────────────────────────────────────────────────

print_success() {
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║     Review Complete!                              ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════╝${NC}"
    echo ""

    if [ -f "$REVIEW_OUTPUT" ]; then
        local issue_count=$(grep -c '"passes": false' "$REVIEW_OUTPUT" 2>/dev/null || echo "0")
        echo -e "Issues found: ${YELLOW}$issue_count${NC}"
        echo ""
        echo "Files created:"
        echo -e "  ${BLUE}$REVIEW_OUTPUT${NC} - Issue PRD (RALPH-compatible)"
        [ -f "$PROGRESS_FILE" ] && echo -e "  ${BLUE}$PROGRESS_FILE${NC} - Review progress log"
        echo ""
        echo -e "${CYAN}Next steps:${NC}"
        echo "  1. Review the issues: cat $REVIEW_OUTPUT | jq ."
        echo "  2. Filter critical: cat $REVIEW_OUTPUT | jq '.[] | select(.severity == \"critical\")'"
        echo ""
        echo "  To fix with RALPH:"
        echo "    cp $REVIEW_OUTPUT plans/prd.json"
        echo "    ./ralph.sh 10"
    else
        echo -e "${YELLOW}No review.json was created. Claude may need more guidance.${NC}"
    fi
    echo ""
}

# ─────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────

main() {
    print_banner
    detect_project_type
    detect_monorepo

    mkdir -p plans

    echo -e "${YELLOW}Collecting files for analysis...${NC}"
    categorize_files
    apply_context_limits
    build_file_manifest

    echo -e "Files available for review: ${GREEN}$SELECTED_FILE_COUNT${NC}"
    echo -e "Estimated context: ${BLUE}~$((ESTIMATED_CHARS / 1000))K chars${NC}"
    echo ""

    check_existing_review
    run_interview
    print_success
}

main "$@"
