#!/bin/bash

# RALPH Existing - Onboard Existing Codebases to RALPH
# Uses Claude to analyze your codebase and generate a smart PRD
# Usage: ralph-existing or ./ralph-existing.sh

set -e

# ─────────────────────────────────────────────────────────────
# CONFIGURATION
# ─────────────────────────────────────────────────────────────
MAX_FILES=50
MAX_FILE_LINES=500
MAX_CONTEXT_CHARS=80000

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
    echo "║     RALPH Existing - Codebase Analyzer            ║"
    echo "║     Smart PRD Generation for Existing Projects    ║"
    echo "╚═══════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# ─────────────────────────────────────────────────────────────
# PHASE 1: PRE-ANALYSIS SETUP
# ─────────────────────────────────────────────────────────────

check_existing_ralph() {
    local existing=()
    [ -f "ralph.sh" ] && existing+=("ralph.sh")
    [ -f "ralph-once.sh" ] && existing+=("ralph-once.sh")
    [ -f "plans/prd.json" ] && existing+=("plans/prd.json")
    [ -f "progress.txt" ] && existing+=("progress.txt")

    if [ ${#existing[@]} -gt 0 ]; then
        echo -e "${YELLOW}Existing RALPH files found:${NC}"
        for f in "${existing[@]}"; do
            echo "  - $f"
        done
        echo ""
        echo "Options:"
        echo "  1) Merge - Keep existing PRD, add new analysis findings"
        echo "  2) Replace - Overwrite everything with fresh analysis"
        echo "  3) Cancel"
        echo ""
        read -p "Choice [1]: " choice
        choice=${choice:-1}

        case $choice in
            1) MERGE_MODE=true ;;
            2) MERGE_MODE=false ;;
            *) echo "Cancelled."; exit 0 ;;
        esac
        echo ""
    else
        MERGE_MODE=false
    fi
}

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
        TEST_CMD="$PKG_MANAGER test"
        TYPECHECK_CMD="$PKG_MANAGER run typecheck"
    elif [ -f "pyproject.toml" ] || [ -f "requirements.txt" ]; then
        PROJECT_TYPE="python"
        PKG_MANAGER=""
        TEST_CMD="pytest"
        TYPECHECK_CMD="mypy ."
    elif [ -f "go.mod" ]; then
        PROJECT_TYPE="go"
        PKG_MANAGER=""
        TEST_CMD="go test ./..."
        TYPECHECK_CMD="go vet ./..."
    elif [ -f "Cargo.toml" ]; then
        PROJECT_TYPE="rust"
        PKG_MANAGER=""
        TEST_CMD="cargo test"
        TYPECHECK_CMD="cargo check"
    else
        PROJECT_TYPE="generic"
        PKG_MANAGER=""
        TEST_CMD="echo 'TODO: Add your test command'"
        TYPECHECK_CMD="echo 'TODO: Add your typecheck command'"
    fi

    echo -e "${GREEN}Detected project type: ${YELLOW}$PROJECT_TYPE${NC}"
    if [ -n "$PKG_MANAGER" ]; then
        echo -e "  Package manager: ${BLUE}$PKG_MANAGER${NC}"
    fi
    echo ""
}

check_project_size() {
    local file_count
    if [ -d ".git" ]; then
        file_count=$(git ls-files --cached --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
    else
        file_count=$(find . -type f ! -path "*/node_modules/*" ! -path "*/.git/*" ! -path "*/vendor/*" ! -path "*/dist/*" ! -path "*/build/*" 2>/dev/null | wc -l | tr -d ' ')
    fi

    if [ "$file_count" -lt 5 ]; then
        echo -e "${YELLOW}This project has very few source files ($file_count).${NC}"
        echo "Consider using ralph-init for new projects instead."
        read -p "Continue anyway? (y/N): " continue_anyway
        if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
            exit 0
        fi
        echo ""
    fi

    TOTAL_FILES=$file_count
}

detect_monorepo() {
    # Check for common monorepo patterns
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
# PHASE 2: INTELLIGENT FILE COLLECTION
# ─────────────────────────────────────────────────────────────

generate_file_tree() {
    echo -e "${YELLOW}Generating file tree...${NC}"

    if [ -d ".git" ]; then
        FILE_TREE=$(git ls-tree -r --name-only HEAD "$FOCUS_DIR" 2>/dev/null | head -200 | sed 's/^/  /')
    else
        FILE_TREE=$(find "$FOCUS_DIR" -type f \
            ! -path "*/node_modules/*" \
            ! -path "*/.git/*" \
            ! -path "*/vendor/*" \
            ! -path "*/dist/*" \
            ! -path "*/build/*" \
            ! -path "*/__pycache__/*" \
            ! -name "*.min.js" \
            ! -name "*.min.css" \
            ! -name "*.map" \
            ! -name "*.lock" \
            ! -name "package-lock.json" \
            2>/dev/null | head -200 | sed 's/^/  /')
    fi
}

categorize_files() {
    # Arrays to hold files by category
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
                # Check directory patterns
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
    echo -e "${YELLOW}Selecting files for analysis...${NC}"

    SELECTED_FILES=()
    local total_chars=0
    local file_count=0

    # Priority order: config, entry, routes, models, components, tests, other
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

                # Skip files that are too large
                if [ "$file_size" -gt 50000 ]; then
                    continue
                fi

                # Check if adding this file exceeds context limit
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
    echo -e "  Total project files: ${YELLOW}$TOTAL_FILES${NC}"
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

confirm_analysis_scope() {
    read -p "Proceed with analysis? (Y/n): " proceed
    if [[ "$proceed" =~ ^[Nn]$ ]]; then
        echo ""
        echo "Options:"
        echo "  1) Focus on specific directory"
        echo "  2) Adjust file limit"
        echo "  3) Cancel"
        read -p "Choice: " adjust_choice

        case $adjust_choice in
            1)
                read -p "Enter directory to focus on: " FOCUS_DIR
                categorize_files
                apply_context_limits
                build_manifest
                confirm_analysis_scope
                ;;
            2)
                read -p "Max files to analyze [$MAX_FILES]: " new_max
                MAX_FILES=${new_max:-$MAX_FILES}
                apply_context_limits
                build_manifest
                confirm_analysis_scope
                ;;
            *)
                echo "Cancelled."
                exit 0
                ;;
        esac
    fi
    echo ""
}

# ─────────────────────────────────────────────────────────────
# PHASE 3: CLAUDE ANALYSIS
# ─────────────────────────────────────────────────────────────

build_analysis_prompt() {
    echo -e "${YELLOW}Building analysis prompt...${NC}"

    PROMPT_FILE=$(mktemp)

    cat > "$PROMPT_FILE" << 'PROMPT_HEADER'
You are an expert code analyst helping onboard an existing codebase to the RALPH development system.

## Your Task

Analyze this codebase and produce a structured JSON analysis. Be thorough but conservative - only list features you can clearly see evidence for in the code.

PROMPT_HEADER

    cat >> "$PROMPT_FILE" << CONTEXT
## Project Context

Project Type: $PROJECT_TYPE
Package Manager: ${PKG_MANAGER:-N/A}
Total Files: $TOTAL_FILES
Files Analyzed: $SELECTED_FILE_COUNT

## File Tree (first 200 files)

\`\`\`
$FILE_TREE
\`\`\`

## File Contents

CONTEXT

    # Add file contents
    for file in "${SELECTED_FILES[@]}"; do
        local ext="${file##*.}"
        local category="source"

        # Determine category for context
        case "$file" in
            *config*|package.json|*.toml|*.yaml|*.yml) category="CONFIG" ;;
            *main*|*index*|*app*|*server*) category="ENTRY" ;;
            *route*|*api*|*page*|*endpoint*) category="ROUTE" ;;
            *model*|*schema*|*type*|*entity*) category="MODEL" ;;
            *test*|*spec*) category="TEST" ;;
            *component*|*view*|*widget*) category="COMPONENT" ;;
        esac

        echo "### $file ($category)" >> "$PROMPT_FILE"
        echo "\`\`\`$ext" >> "$PROMPT_FILE"
        head -n $MAX_FILE_LINES "$file" 2>/dev/null >> "$PROMPT_FILE" || echo "(Could not read file)"
        echo "\`\`\`" >> "$PROMPT_FILE"
        echo "" >> "$PROMPT_FILE"
    done

    cat >> "$PROMPT_FILE" << 'PROMPT_OUTPUT'

## Output Format

Respond with ONLY valid JSON (no markdown code blocks, no explanation before or after). Use this exact structure:

{
  "detected_stack": {
    "language": "typescript|javascript|python|go|rust|other",
    "framework": "string or null",
    "ui_library": "string or null",
    "testing": {
      "framework": "string or null",
      "has_tests": true/false,
      "coverage_hint": "none|minimal|partial|good"
    },
    "libraries": ["list", "of", "major", "libraries"],
    "build_tool": "string or null",
    "database": "string or null"
  },
  "existing_features": [
    {
      "category": "functional|ui|api|data|config|auth",
      "description": "Clear description of what this feature does",
      "evidence": ["file.ts:function_name", "route /api/x"],
      "confidence": "high|medium|low",
      "verification_steps": [
        "How to verify this works",
        "Another verification step"
      ]
    }
  ],
  "code_structure": {
    "architecture": "monolith|microservices|serverless|spa|ssr|static|cli|library",
    "entry_points": ["list of main entry files"],
    "routes_or_pages": ["list of routes/pages found"],
    "models_or_schemas": ["list of data models"],
    "services_or_utils": ["list of service/utility modules"]
  },
  "refactoring_targets": [
    {
      "file": "path/to/file.ts",
      "issue": "Description of the problem",
      "suggestion": "How to fix it",
      "severity": "low|medium|high",
      "category": "complexity|duplication|naming|structure|performance|security"
    }
  ],
  "missing_or_incomplete": [
    {
      "area": "What's missing",
      "suggestion": "What should be added",
      "priority": "low|medium|high"
    }
  ],
  "knowledge": {
    "architecture_overview": "Detailed description of how the codebase is structured, key patterns used, data flow, and important abstractions",
    "build_commands": {
      "install": "command to install dependencies",
      "build": "command to build the project",
      "test": "command to run tests",
      "run": "command to run the project",
      "lint": "command to lint/format code (if any)"
    },
    "code_conventions": {
      "naming": "Description of naming conventions (camelCase, snake_case, file naming patterns)",
      "file_organization": "How files are organized (by feature, by type, etc.)",
      "patterns": "Common patterns used (repositories, services, controllers, hooks, etc.)",
      "important_rules": ["List of important coding rules or standards observed"]
    },
    "key_files": [
      {
        "path": "path/to/important/file",
        "purpose": "What this file does and why it's important"
      }
    ],
    "gotchas": ["List of non-obvious things a developer should know about this codebase"]
  },
  "notes_for_development": "Any important context for future development work"
}

## Guidelines

1. **Be specific** - Don't say "user authentication" if you can say "JWT-based user login with email/password"
2. **Evidence-based** - Only list features you can see evidence for in the code
3. **Confidence levels**:
   - high: Clear implementation visible
   - medium: Partial implementation or inferred from structure
   - low: Guessing from naming conventions
4. **Refactoring severity**:
   - high: Security problems, major bugs, blocking issues
   - medium: Code quality issues that should be addressed
   - low: Nice-to-have improvements
5. **Be conservative** - When in doubt, use lower confidence
6. **Skip obvious boilerplate** - Don't list "has a package.json" as a feature

Now analyze the codebase and respond with the JSON structure above.
PROMPT_OUTPUT
}

run_claude_analysis() {
    echo -e "${YELLOW}Running Claude analysis...${NC}"
    echo "(This may take a moment)"
    echo ""

    ANALYSIS_OUTPUT=$(mktemp)
    local max_retries=2
    local attempt=1

    while [ $attempt -le $max_retries ]; do
        # Run Claude with the prompt
        if cat "$PROMPT_FILE" | claude --print 2>/dev/null > "$ANALYSIS_OUTPUT"; then
            # Try to extract JSON from the response
            local json_content
            json_content=$(cat "$ANALYSIS_OUTPUT" | sed -n '/^{/,/^}$/p' | head -1000)

            # Check if we got valid JSON
            if echo "$json_content" | python3 -c "import sys, json; json.load(sys.stdin)" 2>/dev/null; then
                echo "$json_content" > "$ANALYSIS_OUTPUT"
                ANALYSIS_JSON="$ANALYSIS_OUTPUT"
                return 0
            fi
        fi

        echo -e "${YELLOW}Analysis attempt $attempt failed, retrying...${NC}"
        ((attempt++))
        sleep 2
    done

    echo -e "${RED}Analysis failed after $max_retries attempts.${NC}"
    echo "Falling back to basic detection..."
    generate_basic_analysis
}

generate_basic_analysis() {
    # Fallback: generate minimal analysis from what we detected
    ANALYSIS_OUTPUT=$(mktemp)

    cat > "$ANALYSIS_OUTPUT" << BASIC_JSON
{
  "detected_stack": {
    "language": "$PROJECT_TYPE",
    "framework": null,
    "ui_library": null,
    "testing": {
      "framework": null,
      "has_tests": ${#TEST_FILES[@]} > 0,
      "coverage_hint": "unknown"
    },
    "libraries": [],
    "build_tool": null,
    "database": null
  },
  "existing_features": [],
  "code_structure": {
    "architecture": "unknown",
    "entry_points": [$(printf '"%s",' "${ENTRY_FILES[@]}" | sed 's/,$//')]  ,
    "routes_or_pages": [],
    "models_or_schemas": [],
    "services_or_utils": []
  },
  "refactoring_targets": [],
  "missing_or_incomplete": [
    {
      "area": "Feature documentation",
      "suggestion": "Add features to the PRD manually - automatic detection failed",
      "priority": "high"
    }
  ],
  "notes_for_development": "Automatic analysis failed. Please review and update the PRD manually."
}
BASIC_JSON

    ANALYSIS_JSON="$ANALYSIS_OUTPUT"
}

save_analysis() {
    mkdir -p plans
    cp "$ANALYSIS_JSON" plans/analysis.json
    echo -e "${GREEN}Analysis saved to plans/analysis.json${NC}"
}

# ─────────────────────────────────────────────────────────────
# PHASE 4: INTERACTIVE REFINEMENT
# ─────────────────────────────────────────────────────────────

display_analysis_summary() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Analysis Results${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo ""

    # Extract and display key info using python for JSON parsing
    python3 << PYTHON_DISPLAY
import json
import sys

try:
    with open('$ANALYSIS_JSON', 'r') as f:
        data = json.load(f)

    stack = data.get('detected_stack', {})
    print(f"  Language: {stack.get('language', 'unknown')}")
    if stack.get('framework'):
        print(f"  Framework: {stack.get('framework')}")
    if stack.get('ui_library'):
        print(f"  UI Library: {stack.get('ui_library')}")
    if stack.get('database'):
        print(f"  Database: {stack.get('database')}")

    libs = stack.get('libraries', [])
    if libs:
        print(f"  Libraries: {', '.join(libs[:5])}")

    print()

    features = data.get('existing_features', [])
    print(f"  Existing features detected: {len(features)}")
    for f in features[:5]:
        conf = f.get('confidence', 'unknown')
        print(f"    - [{conf}] {f.get('description', 'unnamed')[:60]}")
    if len(features) > 5:
        print(f"    ... and {len(features) - 5} more")

    print()

    refactors = data.get('refactoring_targets', [])
    print(f"  Refactoring suggestions: {len(refactors)}")
    for r in refactors[:3]:
        sev = r.get('severity', 'unknown')
        print(f"    - [{sev}] {r.get('issue', 'unnamed')[:50]}")
    if len(refactors) > 3:
        print(f"    ... and {len(refactors) - 3} more")

    missing = data.get('missing_or_incomplete', [])
    if missing:
        print()
        print(f"  Missing/incomplete areas: {len(missing)}")
        for m in missing[:3]:
            pri = m.get('priority', 'unknown')
            print(f"    - [{pri}] {m.get('area', 'unnamed')[:50]}")

except Exception as e:
    print(f"  Could not parse analysis: {e}")
PYTHON_DISPLAY

    echo ""
}

confirm_refinement_options() {
    echo -e "${YELLOW}PRD Generation Options:${NC}"
    echo ""

    read -p "Include refactoring tasks in PRD? (y/N): " include_refactor
    INCLUDE_REFACTORING=$([[ "$include_refactor" =~ ^[Yy]$ ]] && echo true || echo false)

    read -p "Include 'missing feature' suggestions? (Y/n): " include_missing
    INCLUDE_MISSING=$([[ ! "$include_missing" =~ ^[Nn]$ ]] && echo true || echo false)

    echo ""
}

# ─────────────────────────────────────────────────────────────
# PHASE 5: PRD GENERATION
# ─────────────────────────────────────────────────────────────

generate_prd_from_analysis() {
    echo -e "${YELLOW}Generating PRD from analysis...${NC}"

    mkdir -p plans

    python3 << PYTHON_PRD
import json

# Load analysis
with open('$ANALYSIS_JSON', 'r') as f:
    data = json.load(f)

prd = []

# Add existing features (passes: true)
for feature in data.get('existing_features', []):
    prd.append({
        "category": feature.get('category', 'functional'),
        "description": feature.get('description', 'Unknown feature'),
        "steps": feature.get('verification_steps', ['Verify feature works as expected']),
        "passes": True
    })

# Add refactoring tasks if requested (passes: false)
if '$INCLUDE_REFACTORING' == 'true':
    for target in data.get('refactoring_targets', []):
        prd.append({
            "category": "refactor",
            "description": f"Refactor: {target.get('suggestion', target.get('issue', 'Unknown'))}",
            "steps": [
                f"Review {target.get('file', 'target file')}",
                f"Address: {target.get('issue', 'the identified issue')}",
                "Run tests to verify no regressions",
                "Update documentation if needed"
            ],
            "passes": False
        })

# Add missing/incomplete items if requested (passes: false)
if '$INCLUDE_MISSING' == 'true':
    for missing in data.get('missing_or_incomplete', []):
        prd.append({
            "category": missing.get('area', 'feature').lower().replace(' ', '_')[:20],
            "description": missing.get('suggestion', 'Add missing functionality'),
            "steps": [
                "Implement the feature",
                "Add appropriate tests",
                "Verify integration with existing code"
            ],
            "passes": False
        })

# Load existing PRD if merging
if '$MERGE_MODE' == 'true':
    try:
        with open('plans/prd.json', 'r') as f:
            existing_prd = json.load(f)

        # Add existing items that aren't duplicates
        existing_descriptions = {item['description'] for item in prd}
        for item in existing_prd:
            if item['description'] not in existing_descriptions:
                prd.append(item)
    except:
        pass

# Sort: incomplete items first, then by category
prd.sort(key=lambda x: (x.get('passes', False), x.get('category', 'z')))

# Write PRD
with open('plans/prd.json', 'w') as f:
    json.dump(prd, f, indent=2)

# Print summary
done_count = sum(1 for p in prd if p.get('passes'))
todo_count = sum(1 for p in prd if not p.get('passes'))
print(f"PRD generated: {done_count} complete, {todo_count} remaining")
PYTHON_PRD

    echo -e "${GREEN}Created plans/prd.json${NC}"
}

generate_knowledge_md() {
    echo -e "${YELLOW}Generating plans/KNOWLEDGE.md...${NC}"

    python3 << 'PYTHON_KNOWLEDGE'
import json
from datetime import datetime

# Load analysis
try:
    with open('plans/analysis.json', 'r') as f:
        data = json.load(f)
except:
    data = {}

stack = data.get('detected_stack', {})
structure = data.get('code_structure', {})
knowledge = data.get('knowledge', {})
notes = data.get('notes_for_development', '')

# Build commands
build_cmds = knowledge.get('build_commands', {})
conventions = knowledge.get('code_conventions', {})
key_files = knowledge.get('key_files', [])
gotchas = knowledge.get('gotchas', [])

content = f"""# Project Knowledge Base

> Auto-generated by ralph-existing on {datetime.now().strftime('%Y-%m-%d')}
> This file is read by Claude during RALPH iterations to ensure consistent, informed development.
> **Update this file** when you discover new patterns, gotchas, or important information.

---

## Architecture Overview

{knowledge.get('architecture_overview', 'No architecture overview detected. Please add details about how this codebase is structured.')}

### Tech Stack
- **Language:** {stack.get('language', 'unknown')}
- **Framework:** {stack.get('framework', 'none detected')}
- **UI Library:** {stack.get('ui_library', 'none detected')}
- **Database:** {stack.get('database', 'none detected')}
- **Testing:** {stack.get('testing', {}).get('framework', 'none detected')}

### Code Structure
- **Architecture Type:** {structure.get('architecture', 'unknown')}
- **Entry Points:** {', '.join(structure.get('entry_points', [])[:5]) or 'none detected'}
- **Routes/Pages:** {', '.join(structure.get('routes_or_pages', [])[:5]) or 'none detected'}
- **Models/Schemas:** {', '.join(structure.get('models_or_schemas', [])[:5]) or 'none detected'}

---

## Build & Run Commands

| Action | Command |
|--------|---------|
| Install dependencies | `{build_cmds.get('install', 'npm install / pip install -r requirements.txt')}` |
| Build | `{build_cmds.get('build', 'npm run build / python setup.py build')}` |
| Run tests | `{build_cmds.get('test', 'npm test / pytest')}` |
| Run project | `{build_cmds.get('run', 'npm start / python main.py')}` |
| Lint/Format | `{build_cmds.get('lint', 'npm run lint / black .')}` |

---

## Code Conventions

### Naming Conventions
{conventions.get('naming', 'No specific naming conventions detected. Document them here as you discover them.')}

### File Organization
{conventions.get('file_organization', 'No specific file organization pattern detected. Document it here.')}

### Common Patterns
{conventions.get('patterns', 'No specific patterns detected. Document common patterns used in this codebase.')}

### Important Rules
"""

# Add important rules as bullet points
rules = conventions.get('important_rules', [])
if rules:
    for rule in rules:
        content += f"- {rule}\n"
else:
    content += "- No specific rules detected. Add important coding standards here.\n"

content += """
---

## Key Files

| File | Purpose |
|------|---------|
"""

if key_files:
    for kf in key_files[:10]:
        content += f"| `{kf.get('path', 'unknown')}` | {kf.get('purpose', 'No description')} |\n"
else:
    content += "| (none detected) | Add important files here |\n"

content += """
---

## Gotchas & Non-Obvious Things

"""

if gotchas:
    for gotcha in gotchas:
        content += f"- {gotcha}\n"
else:
    content += """- No gotchas detected yet. Add non-obvious things developers should know:
  - Environment variables needed
  - Special setup requirements
  - Known issues or workarounds
  - Performance considerations
"""

content += f"""
---

## Development Notes

{notes if notes else 'No additional notes. Add important context for development here.'}

---

## Learning Log

> Claude appends new discoveries here during RALPH iterations.
> Format: `[DATE] - What was learned`

"""

with open('plans/KNOWLEDGE.md', 'w') as f:
    f.write(content)

print("KNOWLEDGE.md generated successfully")
PYTHON_KNOWLEDGE

    echo -e "${GREEN}Created plans/KNOWLEDGE.md${NC}"
}

generate_learnings_md() {
    echo -e "${YELLOW}Generating plans/LEARNINGS.md...${NC}"

    cat > plans/LEARNINGS.md << 'LEARNINGS_CONTENT'
# Runtime Learnings & Discoveries

> This file captures what Claude learns while building features.
> Updated automatically when errors are encountered or new patterns discovered.
> **This is your debugging knowledge base** - solutions to problems encountered during development.

---

## How This File Works

When Claude encounters:
1. **Build/test errors** → Searches project docs, then web docs, then asks user
2. **Unfamiliar code patterns** → Looks for examples in codebase and documentation
3. **Solutions found** → Records them here for future reference

---

## Error Solutions

> Format: `### [DATE] Error: <description>`
> Followed by: What was tried, what worked, and why

*(No errors encountered yet)*

---

## Library/Framework Notes

> Discoveries about how specific libraries or frameworks work in this project

*(No library notes yet)*

---

## Debugging Tips

> Project-specific debugging strategies that worked

*(No debugging tips yet)*

---

## External Documentation References

> Useful external docs/resources discovered during development

*(No external references yet)*

---

## Questions Asked & Answers

> When Claude asked the user for help, record the Q&A here

*(No Q&A recorded yet)*

---
LEARNINGS_CONTENT

    echo -e "${GREEN}Created plans/LEARNINGS.md${NC}"
}

# ─────────────────────────────────────────────────────────────
# PHASE 6: RALPH FILE GENERATION
# ─────────────────────────────────────────────────────────────

generate_ralph_sh() {
    echo -e "${YELLOW}Generating ralph.sh...${NC}"

    cat > ralph.sh << 'RALPH_SCRIPT'
#!/bin/bash

# RALPH Loop - Automated AI Development
# Usage: ./ralph.sh <max_iterations>

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <iterations>"
    echo "Example: $0 10"
    exit 1
fi

mkdir -p logs
LOG_FILE="logs/ralph-$(date +%Y-%m-%d-%H-%M-%S).log"
echo "Logging to: $LOG_FILE"
echo ""

count_remaining() {
    grep -c '"passes": false' plans/prd.json 2>/dev/null || echo "0"
}

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

    echo "" >> "$LOG_FILE"
    echo "======================================== ITERATION $i ========================================" >> "$LOG_FILE"
    echo "Started: $TIMESTAMP" >> "$LOG_FILE"
    echo "Features remaining: $REMAINING" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"

    PROMPT_FILE=$(mktemp)
    OUTPUT_FILE=$(mktemp)

    cat > "$PROMPT_FILE" << 'EOF'
Read these files first for context:
- @plans/KNOWLEDGE.md (codebase architecture, conventions)
- @plans/LEARNINGS.md (error solutions, discoveries from previous iterations)
- @plans/prd.json (features to build)
- @progress.txt (what's been done)

Then:

1. Find the highest-priority feature to work on and work only on that feature.
   This should be the one YOU decide has the highest priority - not necessarily the first in the list.

2. Implement the feature following the conventions in KNOWLEDGE.md.

3. Check that the types check via: __TYPECHECK_CMD__
   And that the tests pass via: __TEST_CMD__
   (If these commands don't exist yet, set them up first)

4. Update the PRD (plans/prd.json) with the work that was done - set "passes" to true for the completed feature.

5. Append your progress to the progress.txt file.

6. If you learned something new about the codebase (architecture, conventions),
   append it to the "Learning Log" section in plans/KNOWLEDGE.md with today's date.

7. Make a git commit of that feature.

WHEN YOU ENCOUNTER ERRORS OR UNFAMILIAR CODE:
- First, check plans/LEARNINGS.md - the solution may already be documented
- Search for README.md files, docs/ folder, or inline comments in the codebase
- Use web search to find framework/library documentation if needed
- If still stuck, use AskUserQuestion to ask the user for help
- ALWAYS record what you learned in plans/LEARNINGS.md:
  - Under "Error Solutions" for build/test failures
  - Under "Library/Framework Notes" for API discoveries
  - Under "Questions Asked & Answers" if you asked the user

IMPORTANT RULES:
- ONLY WORK ON A SINGLE FEATURE
- STAY UNDER 100K CONTEXT - If a feature is too large, break it into smaller pieces
- It's better to do less and succeed than to fill up context and fail
- FOLLOW the conventions documented in KNOWLEDGE.md
- ALWAYS document solutions when you solve errors - future iterations need this!

OUTPUT STATUS UPDATES as you work using this format:
[STATUS] Reading PRD...
[STATUS] Selected feature: <feature description>
[STATUS] Creating: <filename>
[STATUS] Running: <command>
[STATUS] Tests: PASSED/FAILED
[STATUS] Looking up docs for: <topic>
[STATUS] Recording learning: <brief description>
[STATUS] Committing...

If, while implementing the feature, you notice the PRD is complete (all features have passes: true), output <promise>COMPLETE</promise>.
EOF

    if command -v stdbuf &> /dev/null; then
        cat "$PROMPT_FILE" | stdbuf -oL claude --dangerously-skip-permissions 2>&1 | tee -a "$LOG_FILE" "$OUTPUT_FILE" || true
    elif command -v gstdbuf &> /dev/null; then
        cat "$PROMPT_FILE" | gstdbuf -oL claude --dangerously-skip-permissions 2>&1 | tee -a "$LOG_FILE" "$OUTPUT_FILE" || true
    else
        cat "$PROMPT_FILE" | claude --dangerously-skip-permissions 2>&1 | tee -a "$LOG_FILE" "$OUTPUT_FILE" || true
    fi

    rm -f "$PROMPT_FILE"

    echo "" >> "$LOG_FILE"
    echo "Iteration $i completed at $(date +"%Y-%m-%d %H:%M:%S")" >> "$LOG_FILE"

    if grep -q "<promise>COMPLETE</promise>" "$OUTPUT_FILE" 2>/dev/null; then
        rm -f "$OUTPUT_FILE"
        echo ""
        echo "========================================"
        echo "  PRD COMPLETE after $i iterations!"
        echo "  Full log: $LOG_FILE"
        echo "========================================"
        exit 0
    fi

    rm -f "$OUTPUT_FILE"
done

echo ""
echo "========================================"
echo "  Reached max iterations ($1)"
echo "  PRD may not be complete"
echo "  Full log: $LOG_FILE"
echo "========================================"
RALPH_SCRIPT

    sed -i.bak "s|__TEST_CMD__|$TEST_CMD|g" ralph.sh
    sed -i.bak "s|__TYPECHECK_CMD__|$TYPECHECK_CMD|g" ralph.sh
    rm -f ralph.sh.bak

    chmod +x ralph.sh
    echo -e "${GREEN}Created ralph.sh${NC}"
}

generate_ralph_once_sh() {
    echo -e "${YELLOW}Generating ralph-once.sh...${NC}"

    cat > ralph-once.sh << 'RALPH_ONCE_SCRIPT'
#!/bin/bash

# RALPH Once - Single Iteration (Human-in-the-Loop)
# Usage: ./ralph-once.sh

set -e

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

PROMPT_FILE=$(mktemp)
cat > "$PROMPT_FILE" << 'EOF'
Read these files first for context:
- @plans/KNOWLEDGE.md (codebase architecture, conventions)
- @plans/LEARNINGS.md (error solutions, discoveries from previous iterations)
- @plans/prd.json (features to build)
- @progress.txt (what's been done)

Then:

1. Find the highest-priority feature to work on and work only on that feature.

2. Implement the feature following the conventions in KNOWLEDGE.md.

3. Check that the types check via: __TYPECHECK_CMD__
   And that the tests pass via: __TEST_CMD__

4. Update the PRD (plans/prd.json) - set "passes" to true for the completed feature.

5. Append your progress to the progress.txt file.

6. If you learned something new about the codebase (architecture, conventions),
   append it to the "Learning Log" section in plans/KNOWLEDGE.md.

7. Make a git commit of that feature.

WHEN YOU ENCOUNTER ERRORS OR UNFAMILIAR CODE:
- First, check plans/LEARNINGS.md - the solution may already be documented
- Search for README.md files, docs/ folder, or inline comments in the codebase
- Use web search to find framework/library documentation if needed
- If still stuck, use AskUserQuestion to ask the user for help
- ALWAYS record what you learned in plans/LEARNINGS.md

IMPORTANT RULES:
- ONLY WORK ON A SINGLE FEATURE
- STAY UNDER 100K CONTEXT
- FOLLOW the conventions documented in KNOWLEDGE.md
- ALWAYS document solutions when you solve errors!

OUTPUT STATUS UPDATES as you work.

If the PRD is complete (all features have passes: true), output <promise>COMPLETE</promise>.
EOF

if command -v stdbuf &> /dev/null; then
    cat "$PROMPT_FILE" | stdbuf -oL claude --dangerously-skip-permissions
elif command -v gstdbuf &> /dev/null; then
    cat "$PROMPT_FILE" | gstdbuf -oL claude --dangerously-skip-permissions
else
    cat "$PROMPT_FILE" | claude --dangerously-skip-permissions
fi

rm -f "$PROMPT_FILE"

echo ""
echo "========================================"
echo "  Iteration complete. Review changes."
echo "  Run ./ralph-once.sh again to continue."
echo "========================================"
RALPH_ONCE_SCRIPT

    sed -i.bak "s|__TEST_CMD__|$TEST_CMD|g" ralph-once.sh
    sed -i.bak "s|__TYPECHECK_CMD__|$TYPECHECK_CMD|g" ralph-once.sh
    rm -f ralph-once.sh.bak

    chmod +x ralph-once.sh
    echo -e "${GREEN}Created ralph-once.sh${NC}"
}

generate_progress_with_context() {
    echo -e "${YELLOW}Generating progress.txt with analysis context...${NC}"

    # Generate progress file with analysis context
    python3 << PYTHON_PROGRESS
import json
from datetime import datetime

# Load analysis
try:
    with open('$ANALYSIS_JSON', 'r') as f:
        data = json.load(f)
except:
    data = {}

stack = data.get('detected_stack', {})
structure = data.get('code_structure', {})
notes = data.get('notes_for_development', '')

progress = f"""# Progress Log

## {datetime.now().strftime('%Y-%m-%d')} - Codebase Analysis & RALPH Setup

### Detected Tech Stack
- Language: {stack.get('language', 'unknown')}
- Framework: {stack.get('framework', 'none detected')}
- UI Library: {stack.get('ui_library', 'none detected')}
- Database: {stack.get('database', 'none detected')}
- Testing: {stack.get('testing', {}).get('framework', 'none detected')}
- Key Libraries: {', '.join(stack.get('libraries', [])[:10]) or 'none detected'}

### Code Architecture
- Type: {structure.get('architecture', 'unknown')}
- Entry Points: {', '.join(structure.get('entry_points', [])[:5]) or 'none detected'}

### Analysis Notes
{notes if notes else 'No additional notes from analysis.'}

### Existing Features
The PRD has been pre-populated with detected features (marked as passes: true).
Review plans/prd.json and verify these are accurate.

---

## Next Steps
1. Review the auto-generated PRD in plans/prd.json
2. Verify the "passes: true" items are actually complete
3. Prioritize the remaining tasks
4. Run ./ralph-once.sh to start implementing

---

"""

with open('progress.txt', 'w') as f:
    f.write(progress)
PYTHON_PROGRESS

    echo -e "${GREEN}Created progress.txt${NC}"
}

generate_readme() {
    echo -e "${YELLOW}Generating plans/README.md...${NC}"

    cat > plans/README.md << README_CONTENT
# RALPH Loop Setup

This project has been onboarded to RALPH using automatic codebase analysis.

## Files

| File | Purpose |
|------|---------|
| \`ralph.sh\` | Automated loop - runs until PRD complete |
| \`ralph-once.sh\` | Single iteration - human reviews after each |
| \`plans/prd.json\` | Your features/requirements (auto-populated) |
| \`plans/KNOWLEDGE.md\` | Codebase knowledge (architecture, conventions) |
| \`plans/LEARNINGS.md\` | Runtime discoveries (error solutions, debugging tips) |
| \`plans/analysis.json\` | Raw codebase analysis from Claude |
| \`progress.txt\` | LLM memory - tracks what's been done |

## Quick Start

### Review the PRD
The PRD was auto-generated based on codebase analysis:
- Features marked \`"passes": true\` were detected as already implemented
- Features marked \`"passes": false\` are improvements/refactoring tasks

**Review and adjust before running RALPH!**

### Run RALPH

**Human-in-the-loop (recommended first):**
\`\`\`bash
./ralph-once.sh  # Run once
# Review the changes
./ralph-once.sh  # Run again
\`\`\`

**Automated (after building trust):**
\`\`\`bash
./ralph.sh 10  # Run up to 10 iterations
\`\`\`

## Commands

- Test: \`$TEST_CMD\`
- Typecheck: \`$TYPECHECK_CMD\`
README_CONTENT

    echo -e "${GREEN}Created plans/README.md${NC}"
}

print_success() {
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║     RALPH Setup Complete!                         ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Files created:"
    echo "  - ralph.sh             (automated loop)"
    echo "  - ralph-once.sh        (human-in-the-loop)"
    echo "  - plans/prd.json       (smart PRD from analysis)"
    echo "  - plans/KNOWLEDGE.md   (codebase knowledge base)"
    echo "  - plans/LEARNINGS.md   (runtime discoveries & error solutions)"
    echo "  - plans/analysis.json  (raw analysis data)"
    echo "  - progress.txt         (LLM memory with context)"
    echo "  - plans/README.md      (documentation)"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "  1. Review plans/prd.json - verify detected features"
    echo "  2. Adjust priorities and add any missing items"
    echo "  3. Run ./ralph-once.sh to start implementing"
    echo ""
}

# ─────────────────────────────────────────────────────────────
# CLEANUP
# ─────────────────────────────────────────────────────────────

cleanup() {
    [ -n "$PROMPT_FILE" ] && rm -f "$PROMPT_FILE"
    [ -n "$ANALYSIS_OUTPUT" ] && rm -f "$ANALYSIS_OUTPUT"
}

trap cleanup EXIT

# ─────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────

main() {
    print_banner

    # Phase 1: Pre-analysis setup
    check_existing_ralph
    detect_project_type
    check_project_size
    detect_monorepo

    # Phase 2: File collection
    generate_file_tree
    categorize_files
    apply_context_limits
    build_manifest
    confirm_analysis_scope

    # Phase 3: Claude analysis
    build_analysis_prompt
    run_claude_analysis
    save_analysis

    # Phase 4: Interactive refinement
    display_analysis_summary
    confirm_refinement_options

    # Phase 5: PRD generation
    generate_prd_from_analysis
    generate_knowledge_md
    generate_learnings_md

    # Phase 6: RALPH file generation
    generate_ralph_sh
    generate_ralph_once_sh
    generate_progress_with_context
    generate_readme

    print_success
}

main "$@"
