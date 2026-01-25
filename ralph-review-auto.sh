#!/bin/bash

# RALPH Review Auto - Automated Code Quality Scan (No Interview)
# Scans codebase for bugs, security issues, and code quality problems
# Part of the RALPH ecosystem
#
# Usage: ralph-review-auto or ./ralph-review-auto.sh [options]
#
# Options:
#   --severity <level>  Filter by severity: critical, high, medium, low, all (default: all)
#   --type <type>       Filter by type: bug, performance, security, refactor, edge-case, all (default: all)
#   --focus <dir>       Focus on specific directory

set -e

# ─────────────────────────────────────────────────────────────
# CONFIGURATION
# ─────────────────────────────────────────────────────────────
MAX_FILES=50
MAX_FILE_LINES=500
MAX_CONTEXT_CHARS=80000
REVIEW_OUTPUT="plans/review.json"
PROGRESS_FILE="review-progress.txt"

# Defaults
SEVERITY_FILTER="all"
TYPE_FILTER="all"
FOCUS_DIR="."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ─────────────────────────────────────────────────────────────
# ARGUMENT PARSING
# ─────────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
    case $1 in
        --severity)
            SEVERITY_FILTER="$2"
            shift 2
            ;;
        --type)
            TYPE_FILTER="$2"
            shift 2
            ;;
        --focus)
            FOCUS_DIR="$2"
            shift 2
            ;;
        -h|--help)
            echo "RALPH Review Auto - Automated Code Quality Scan"
            echo ""
            echo "Usage: ralph-review-auto [options]"
            echo ""
            echo "Options:"
            echo "  --severity <level>  Filter: critical, high, medium, low, all (default: all)"
            echo "  --type <type>       Filter: bug, performance, security, refactor, edge-case, all (default: all)"
            echo "  --focus <dir>       Focus on specific directory"
            echo "  -h, --help          Show this help"
            echo ""
            echo "Examples:"
            echo "  ralph-review-auto                           # Scan everything"
            echo "  ralph-review-auto --severity critical       # Only critical issues"
            echo "  ralph-review-auto --type security           # Only security issues"
            echo "  ralph-review-auto --focus src/api           # Focus on src/api directory"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# ─────────────────────────────────────────────────────────────
# BANNER
# ─────────────────────────────────────────────────────────────

print_banner() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════╗"
    echo "║     RALPH Review Auto - Automated Code Scan       ║"
    echo "║     No Interview - Direct Analysis                ║"
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

    echo -e "Project type: ${YELLOW}$PROJECT_TYPE${NC}"
    echo -e "Severity filter: ${BLUE}$SEVERITY_FILTER${NC}"
    echo -e "Type filter: ${BLUE}$TYPE_FILTER${NC}"
    echo -e "Focus directory: ${BLUE}$FOCUS_DIR${NC}"
    echo ""
}

# ─────────────────────────────────────────────────────────────
# PHASE 2: FILE COLLECTION
# ─────────────────────────────────────────────────────────────

categorize_files() {
    echo -e "${YELLOW}Categorizing files...${NC}"

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
    echo -e "${YELLOW}Selecting files within context limits...${NC}"

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
        local -n files_ref=$category
        for file in "${files_ref[@]}"; do
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

build_manifest() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Analysis Manifest${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  Files to analyze:    ${GREEN}$SELECTED_FILE_COUNT${NC}"
    echo -e "  Estimated context:   ${BLUE}~$((ESTIMATED_CHARS / 1000))K chars${NC}"
    echo ""
    echo "  Categories:"
    echo "    Config files:     ${#CONFIG_FILES[@]}"
    echo "    Entry points:     ${#ENTRY_FILES[@]}"
    echo "    Routes/API:       ${#ROUTE_FILES[@]}"
    echo "    Models/Schemas:   ${#MODEL_FILES[@]}"
    echo "    Components:       ${#COMPONENT_FILES[@]}"
    echo "    Tests:            ${#TEST_FILES[@]}"
    echo ""
}

# ─────────────────────────────────────────────────────────────
# PHASE 3: BUILD ANALYSIS PROMPT
# ─────────────────────────────────────────────────────────────

build_review_prompt() {
    PROMPT_FILE=$(mktemp)

    # Build filter instructions
    local type_instruction=""
    if [ "$TYPE_FILTER" != "all" ]; then
        type_instruction="Focus ONLY on '$TYPE_FILTER' issues."
    fi

    local severity_instruction=""
    if [ "$SEVERITY_FILTER" != "all" ]; then
        case "$SEVERITY_FILTER" in
            critical)
                severity_instruction="Only report CRITICAL severity issues."
                ;;
            high)
                severity_instruction="Only report CRITICAL and HIGH severity issues."
                ;;
            medium)
                severity_instruction="Report CRITICAL, HIGH, and MEDIUM severity issues."
                ;;
        esac
    fi

    cat > "$PROMPT_FILE" << PROMPT
You are an expert code reviewer specializing in bugs, security, performance, and code quality.

## Your Task

Analyze this codebase and identify issues. ${type_instruction} ${severity_instruction}

## Issue Categories

- **bug**: Logic errors, null checks, off-by-one errors, race conditions, type errors
- **performance**: N+1 queries, missing memoization, expensive operations in loops, memory leaks
- **security**: Input validation issues, injection vulnerabilities, secrets in code, auth issues
- **refactor**: Code duplication, overly complex functions, poor naming, dead code
- **edge-case**: Missing error handling, boundary conditions, empty state handling

## Severity Levels

- **critical**: Security vulnerabilities, data loss risk, application crashes
- **high**: Major functional bugs, significant performance issues
- **medium**: Minor bugs, moderate code quality issues
- **low**: Style issues, minor optimizations

## Output Format

Respond with ONLY valid JSON (no markdown code fences, no explanation before or after):

[
  {
    "category": "bug|performance|security|refactor|edge-case",
    "severity": "critical|high|medium|low",
    "description": "Clear description of the issue",
    "file": "path/to/affected/file",
    "line": 42,
    "steps": [
      "How to reproduce/verify the issue",
      "Suggested fix approach",
      "How to verify the fix worked"
    ],
    "passes": false
  }
]

If no issues are found, return an empty array: []

## Guidelines

1. Be specific - include exact file paths and line numbers
2. Be actionable - every issue should have clear fix steps
3. Be conservative - don't flag non-issues or stylistic preferences
4. Prioritize by severity - critical issues first
5. Group related issues when they share the same root cause
6. Include the "passes": false field for RALPH compatibility

## File Contents to Analyze

PROMPT

    # Append file contents
    for file in "${SELECTED_FILES[@]}"; do
        echo "### $file" >> "$PROMPT_FILE"
        echo '```' >> "$PROMPT_FILE"
        head -n $MAX_FILE_LINES "$file" 2>/dev/null >> "$PROMPT_FILE" || echo "(Could not read file)"
        echo '```' >> "$PROMPT_FILE"
        echo "" >> "$PROMPT_FILE"
    done

    echo "" >> "$PROMPT_FILE"
    echo "Now analyze the code above and respond with ONLY the JSON array of issues." >> "$PROMPT_FILE"
}

# ─────────────────────────────────────────────────────────────
# PHASE 4: RUN ANALYSIS
# ─────────────────────────────────────────────────────────────

run_analysis() {
    echo -e "${YELLOW}Running automated code review...${NC}"
    echo ""

    ANALYSIS_OUTPUT=$(mktemp)

    if cat "$PROMPT_FILE" | claude --print > "$ANALYSIS_OUTPUT" 2>&1; then
        # Extract JSON from response
        local content=$(cat "$ANALYSIS_OUTPUT")

        # Find JSON array in response (handles potential markdown or text wrapping)
        local json_content=$(echo "$content" | sed -n '/^\[/,/^\]/p' | head -1)

        if [ -z "$json_content" ]; then
            # Try to extract JSON that might be wrapped in markdown
            json_content=$(echo "$content" | grep -o '\[.*\]' | head -1)
        fi

        if [ -n "$json_content" ]; then
            # Validate and save JSON
            if echo "$json_content" | python3 -m json.tool > /dev/null 2>&1; then
                mkdir -p plans
                echo "$json_content" | python3 -m json.tool > "$REVIEW_OUTPUT"
                echo -e "${GREEN}Analysis complete!${NC}"
            else
                # Try to extract and fix JSON
                echo "$content" > "$REVIEW_OUTPUT.raw"
                echo -e "${YELLOW}Warning: Could not parse JSON. Raw output saved to $REVIEW_OUTPUT.raw${NC}"

                # Attempt to create empty valid JSON
                echo "[]" > "$REVIEW_OUTPUT"
            fi
        else
            echo -e "${YELLOW}No JSON found in response. Creating empty review.${NC}"
            mkdir -p plans
            echo "[]" > "$REVIEW_OUTPUT"
        fi
    else
        echo -e "${RED}Error running Claude analysis${NC}"
        cat "$ANALYSIS_OUTPUT"
        rm -f "$ANALYSIS_OUTPUT"
        exit 1
    fi

    rm -f "$ANALYSIS_OUTPUT"
    rm -f "$PROMPT_FILE"
}

# ─────────────────────────────────────────────────────────────
# PHASE 5: GENERATE PROGRESS FILE
# ─────────────────────────────────────────────────────────────

generate_progress() {
    local today=$(date +%Y-%m-%d)
    local time=$(date +%H:%M:%S)

    # Count issues by severity
    local critical_count=0
    local high_count=0
    local medium_count=0
    local low_count=0

    if [ -f "$REVIEW_OUTPUT" ]; then
        critical_count=$(grep -c '"severity": "critical"' "$REVIEW_OUTPUT" 2>/dev/null || echo 0)
        high_count=$(grep -c '"severity": "high"' "$REVIEW_OUTPUT" 2>/dev/null || echo 0)
        medium_count=$(grep -c '"severity": "medium"' "$REVIEW_OUTPUT" 2>/dev/null || echo 0)
        low_count=$(grep -c '"severity": "low"' "$REVIEW_OUTPUT" 2>/dev/null || echo 0)
    fi

    local total_count=$((critical_count + high_count + medium_count + low_count))

    cat > "$PROGRESS_FILE" << PROGRESS
# Review Progress Log

## $today $time - Automated Code Review

### Scan Parameters
- Severity filter: $SEVERITY_FILTER
- Type filter: $TYPE_FILTER
- Focus directory: $FOCUS_DIR
- Files analyzed: $SELECTED_FILE_COUNT
- Estimated context: ~$((ESTIMATED_CHARS / 1000))K chars

### Summary of Findings
- Total issues: $total_count
- Critical: $critical_count
- High: $high_count
- Medium: $medium_count
- Low: $low_count

### Files Analyzed
$(printf '%s\n' "${SELECTED_FILES[@]}" | sed 's/^/- /')

---

PROGRESS
}

# ─────────────────────────────────────────────────────────────
# PHASE 6: SUCCESS MESSAGE
# ─────────────────────────────────────────────────────────────

print_success() {
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║     Automated Review Complete!                    ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════╝${NC}"
    echo ""

    if [ -f "$REVIEW_OUTPUT" ]; then
        local issue_count=$(grep -c '"passes": false' "$REVIEW_OUTPUT" 2>/dev/null || echo "0")
        local critical_count=$(grep -c '"severity": "critical"' "$REVIEW_OUTPUT" 2>/dev/null || echo 0)
        local high_count=$(grep -c '"severity": "high"' "$REVIEW_OUTPUT" 2>/dev/null || echo 0)

        echo -e "Total issues found: ${YELLOW}$issue_count${NC}"

        if [ "$critical_count" -gt 0 ]; then
            echo -e "  Critical: ${RED}$critical_count${NC}"
        fi
        if [ "$high_count" -gt 0 ]; then
            echo -e "  High: ${YELLOW}$high_count${NC}"
        fi

        echo ""
        echo "Files created:"
        echo -e "  ${BLUE}$REVIEW_OUTPUT${NC} - Issue PRD (RALPH-compatible)"
        echo -e "  ${BLUE}$PROGRESS_FILE${NC} - Review progress log"
        echo ""
        echo -e "${CYAN}Next steps:${NC}"
        echo "  View all issues:      cat $REVIEW_OUTPUT | jq ."
        echo "  Filter critical:      cat $REVIEW_OUTPUT | jq '.[] | select(.severity == \"critical\")'"
        echo "  Filter by type:       cat $REVIEW_OUTPUT | jq '.[] | select(.category == \"security\")'"
        echo ""
        echo "  To fix with RALPH:"
        echo "    cp $REVIEW_OUTPUT plans/prd.json"
        echo "    ./ralph.sh 10"
    else
        echo -e "${YELLOW}No review.json was created.${NC}"
    fi
    echo ""
}

# ─────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────

main() {
    print_banner
    detect_project_type

    categorize_files
    apply_context_limits
    build_manifest

    read -p "Proceed with analysis? (Y/n): " proceed
    if [[ "$proceed" =~ ^[Nn]$ ]]; then
        echo "Cancelled."
        exit 0
    fi

    build_review_prompt
    run_analysis
    generate_progress
    print_success
}

main "$@"
