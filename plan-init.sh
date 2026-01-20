#!/bin/bash

# Plan-Init: PRD Builder for RALPH Loop
# Creates well-structured prd.json through guided interviews
# Part of the RALPH ecosystem

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Config
TEMPLATE_DIR="$HOME/.plan-init/templates"
FEATURES=()
PROJECT_DESCRIPTION=""

# --- Utility Functions ---

print_header() {
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════╗"
    echo "║     Plan-Init: PRD Builder            ║"
    echo "║     RALPH Ecosystem                   ║"
    echo "╚═══════════════════════════════════════╝"
    echo -e "${NC}"
}

print_step() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}$1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_feature() {
    local idx=$1
    local category=$2
    local description=$3
    local steps=$4

    echo -e "${GREEN}[$idx]${NC} ${BOLD}$description${NC}"
    echo -e "    Category: ${YELLOW}$category${NC}"
    echo -e "    Steps: $steps"
}

confirm() {
    read -p "$1 (y/n): " choice
    [[ "$choice" =~ ^[Yy]$ ]]
}

# --- Template Functions ---

init_template_dir() {
    mkdir -p "$TEMPLATE_DIR"
}

list_templates() {
    echo "Available templates:"
    echo -e "  ${GREEN}1)${NC} webapp     - Web application (auth, CRUD, UI)"
    echo -e "  ${GREEN}2)${NC} api        - API service (endpoints, validation)"
    echo -e "  ${GREEN}3)${NC} cli        - CLI tool (commands, flags, help)"
    echo -e "  ${GREEN}4)${NC} library    - Library (core functions, exports)"
    echo -e "  ${GREEN}5)${NC} blank      - Start from scratch"

    # List custom templates
    if [ -d "$TEMPLATE_DIR" ] && [ "$(ls -A $TEMPLATE_DIR 2>/dev/null)" ]; then
        echo ""
        echo "Custom templates:"
        local i=6
        for f in "$TEMPLATE_DIR"/*.json; do
            [ -e "$f" ] || continue
            local name=$(basename "$f" .json)
            echo -e "  ${GREEN}$i)${NC} $name"
            ((i++))
        done
    fi
}

load_builtin_template() {
    local template=$1
    FEATURES=()

    case $template in
        webapp)
            add_feature_direct "functional" "User registration with email and password" \
                "Navigate to /register|Enter valid email and password|Submit form|Verify account created|Verify redirect to login"
            add_feature_direct "functional" "User login with email and password" \
                "Navigate to /login|Enter valid credentials|Submit form|Verify session created|Verify redirect to dashboard"
            add_feature_direct "functional" "User logout" \
                "Click logout button|Verify session destroyed|Verify redirect to login"
            add_feature_direct "ui" "Navigation bar with links" \
                "Verify nav bar visible on all pages|Verify links work|Verify active state shown"
            add_feature_direct "ui" "Responsive layout for mobile" \
                "View on mobile viewport|Verify layout adapts|Verify touch-friendly elements"
            ;;
        api)
            add_feature_direct "functional" "Health check endpoint" \
                "GET /health|Verify 200 response|Verify response body"
            add_feature_direct "functional" "CRUD endpoints for main resource" \
                "POST creates resource|GET retrieves resource|PUT updates resource|DELETE removes resource"
            add_feature_direct "functional" "Input validation on all endpoints" \
                "Send invalid data|Verify 400 response|Verify error message describes issue"
            add_feature_direct "functional" "Error handling returns consistent format" \
                "Trigger various errors|Verify consistent JSON structure|Verify appropriate status codes"
            ;;
        cli)
            add_feature_direct "functional" "Help command shows usage" \
                "Run with --help|Verify all commands listed|Verify descriptions shown"
            add_feature_direct "functional" "Version command shows version" \
                "Run with --version|Verify version number displayed"
            add_feature_direct "functional" "Main command executes core functionality" \
                "Run main command|Verify expected output|Verify exit code 0 on success"
            add_feature_direct "functional" "Error messages are helpful" \
                "Run with invalid input|Verify clear error message|Verify suggested fix if applicable"
            ;;
        library)
            add_feature_direct "functional" "Core functions work as documented" \
                "Import library|Call main functions|Verify expected return values"
            add_feature_direct "functional" "Type definitions are accurate" \
                "Check TypeScript types|Verify no type errors in usage|Verify IntelliSense works"
            add_feature_direct "functional" "Exports are properly configured" \
                "Import in CommonJS|Import in ESM|Verify both work"
            ;;
    esac
}

# --- Feature Management ---

add_feature_direct() {
    local category=$1
    local description=$2
    local steps=$3
    FEATURES+=("$category|$description|$steps")
}

add_feature_interactive() {
    print_step "Add New Feature"

    echo "Categories: functional, ui, api, data, config, docs"
    read -p "Category: " category
    category=${category:-functional}

    echo ""
    read -p "Description (what this feature does): " description

    if [ -z "$description" ]; then
        echo -e "${RED}Description required. Feature not added.${NC}"
        return
    fi

    # Size check
    check_feature_size "$description"

    echo ""
    echo "Verification steps (how to test this works):"
    echo "Enter each step, empty line when done:"

    local steps=""
    local step_num=1
    while true; do
        read -p "  Step $step_num: " step
        [ -z "$step" ] && break
        if [ -n "$steps" ]; then
            steps="$steps|$step"
        else
            steps="$step"
        fi
        ((step_num++))
    done

    if [ -z "$steps" ]; then
        echo -e "${YELLOW}Suggesting verification steps...${NC}"
        steps=$(suggest_verification_steps "$category" "$description")
        echo "Suggested: $steps"
        if ! confirm "Use these steps?"; then
            read -p "Enter your steps (separated by |): " steps
        fi
    fi

    FEATURES+=("$category|$description|$steps")
    echo -e "${GREEN}✓ Feature added${NC}"
}

check_feature_size() {
    local description=$1
    local warnings=()

    # Check description length
    if [ ${#description} -gt 100 ]; then
        warnings+=("Description is long (>${#description} chars)")
    fi

    # Check for multiple actions
    local and_count=$(echo "$description" | grep -o " and " | wc -l)
    if [ $and_count -gt 1 ]; then
        warnings+=("Contains multiple 'and' - might be multiple features")
    fi

    # Check for scope keywords
    if echo "$description" | grep -qi "complete\|full\|entire\|all"; then
        warnings+=("Contains scope keywords (complete/full/entire/all)")
    fi

    if [ ${#warnings[@]} -gt 0 ]; then
        echo ""
        echo -e "${YELLOW}⚠ SIZE WARNING:${NC}"
        for w in "${warnings[@]}"; do
            echo -e "  ${YELLOW}• $w${NC}"
        done
        echo ""
        echo "Large features may fail in a single RALPH iteration."
        if confirm "Would you like suggestions to split this feature?"; then
            suggest_split "$description"
        fi
    fi
}

suggest_split() {
    local description=$1
    echo ""
    echo -e "${CYAN}Split suggestions:${NC}"

    # Simple split heuristics
    if echo "$description" | grep -qi " and "; then
        echo "This feature mentions multiple things. Consider splitting:"
        IFS=' and ' read -ra parts <<< "$description"
        local i=1
        for part in "${parts[@]}"; do
            echo -e "  ${GREEN}$i)${NC} $part"
            ((i++))
        done
    else
        echo "Consider breaking into:"
        echo -e "  ${GREEN}1)${NC} Setup/configuration for: $description"
        echo -e "  ${GREEN}2)${NC} Core implementation of: $description"
        echo -e "  ${GREEN}3)${NC} Testing/verification for: $description"
    fi
    echo ""
}

suggest_verification_steps() {
    local category=$1
    local description=$2

    case $category in
        ui)
            echo "Verify element is visible|Verify styling is correct|Verify interaction works"
            ;;
        api)
            echo "Send request|Verify response status|Verify response body"
            ;;
        functional)
            echo "Perform the action|Verify expected result|Verify no errors"
            ;;
        data)
            echo "Create test data|Verify data is stored|Verify data can be retrieved"
            ;;
        *)
            echo "Verify feature works|Check for errors|Confirm expected behavior"
            ;;
    esac
}

list_features() {
    if [ ${#FEATURES[@]} -eq 0 ]; then
        echo -e "${YELLOW}No features yet.${NC}"
        return
    fi

    echo ""
    local i=1
    for feature in "${FEATURES[@]}"; do
        IFS='|' read -r category description steps <<< "$feature"
        local step_count=$(echo "$steps" | tr '|' '\n' | wc -l)
        print_feature "$i" "$category" "$description" "$step_count steps"
        ((i++))
    done
    echo ""
}

edit_feature() {
    list_features
    [ ${#FEATURES[@]} -eq 0 ] && return

    read -p "Feature number to edit (or 'c' to cancel): " num
    [[ "$num" == "c" ]] && return

    if ! [[ "$num" =~ ^[0-9]+$ ]] || [ "$num" -lt 1 ] || [ "$num" -gt ${#FEATURES[@]} ]; then
        echo -e "${RED}Invalid selection${NC}"
        return
    fi

    local idx=$((num - 1))
    IFS='|' read -r category description steps <<< "${FEATURES[$idx]}"

    echo ""
    echo "Current: $description"
    echo "Category: $category"
    echo "Steps: $steps"
    echo ""
    echo "1) Edit description"
    echo "2) Edit category"
    echo "3) Edit steps"
    echo "4) Delete feature"
    echo "5) Cancel"
    read -p "Choice: " choice

    case $choice in
        1)
            read -p "New description: " new_desc
            [ -n "$new_desc" ] && FEATURES[$idx]="$category|$new_desc|$steps"
            ;;
        2)
            read -p "New category: " new_cat
            [ -n "$new_cat" ] && FEATURES[$idx]="$new_cat|$description|$steps"
            ;;
        3)
            echo "Enter new steps (separated by |):"
            read -p "> " new_steps
            [ -n "$new_steps" ] && FEATURES[$idx]="$category|$description|$new_steps"
            ;;
        4)
            unset 'FEATURES[$idx]'
            FEATURES=("${FEATURES[@]}")
            echo -e "${GREEN}Feature deleted${NC}"
            ;;
    esac
}

delete_feature() {
    list_features
    [ ${#FEATURES[@]} -eq 0 ] && return

    read -p "Feature number to delete (or 'c' to cancel): " num
    [[ "$num" == "c" ]] && return

    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le ${#FEATURES[@]} ]; then
        local idx=$((num - 1))
        unset 'FEATURES[$idx]'
        FEATURES=("${FEATURES[@]}")
        echo -e "${GREEN}Feature deleted${NC}"
    fi
}

# --- Project Intake ---

get_project_description() {
    print_step "Step 1: Project Description"

    echo "Describe your project in 2-3 sentences."
    echo "What are you building? What's its main purpose?"
    echo ""
    read -p "> " PROJECT_DESCRIPTION

    echo ""
    echo -e "Got it: ${CYAN}$PROJECT_DESCRIPTION${NC}"
    echo ""
}

select_template() {
    print_step "Step 2: Starting Point"

    list_templates
    echo ""
    read -p "Select template (1-5, or number for custom): " choice

    case $choice in
        1) load_builtin_template "webapp" && echo -e "${GREEN}Loaded webapp template${NC}" ;;
        2) load_builtin_template "api" && echo -e "${GREEN}Loaded api template${NC}" ;;
        3) load_builtin_template "cli" && echo -e "${GREEN}Loaded cli template${NC}" ;;
        4) load_builtin_template "library" && echo -e "${GREEN}Loaded library template${NC}" ;;
        5) echo "Starting blank" ;;
        *)
            # Try to load custom template
            local i=6
            for f in "$TEMPLATE_DIR"/*.json; do
                [ -e "$f" ] || continue
                if [ "$i" == "$choice" ]; then
                    load_custom_template "$f"
                    echo -e "${GREEN}Loaded custom template${NC}"
                    break
                fi
                ((i++))
            done
            ;;
    esac
}

load_custom_template() {
    local file=$1
    FEATURES=()

    # Parse JSON template (simple parsing)
    while IFS= read -r line; do
        if [[ "$line" =~ \"category\":\ *\"([^\"]+)\" ]]; then
            current_category="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ \"description\":\ *\"([^\"]+)\" ]]; then
            current_description="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ \"steps\":\ *\[ ]]; then
            current_steps=""
            in_steps=true
        elif [[ "$line" =~ \] ]] && [ "$in_steps" = true ]; then
            in_steps=false
            if [ -n "$current_category" ] && [ -n "$current_description" ]; then
                FEATURES+=("$current_category|$current_description|$current_steps")
            fi
            current_category=""
            current_description=""
        elif [ "$in_steps" = true ] && [[ "$line" =~ \"([^\"]+)\" ]]; then
            step="${BASH_REMATCH[1]}"
            if [ -n "$current_steps" ]; then
                current_steps="$current_steps|$step"
            else
                current_steps="$step"
            fi
        fi
    done < "$file"
}

suggest_features() {
    print_step "Step 3: Feature Suggestions"

    echo "Based on your description, here are suggested feature areas:"
    echo ""

    local suggestions=()

    # Simple keyword matching
    if echo "$PROJECT_DESCRIPTION" | grep -qi "user\|login\|auth\|account"; then
        suggestions+=("User authentication (login, register, logout)")
    fi
    if echo "$PROJECT_DESCRIPTION" | grep -qi "api\|endpoint\|rest\|graphql"; then
        suggestions+=("API endpoints with validation")
    fi
    if echo "$PROJECT_DESCRIPTION" | grep -qi "ui\|interface\|page\|dashboard\|form"; then
        suggestions+=("User interface components")
    fi
    if echo "$PROJECT_DESCRIPTION" | grep -qi "data\|database\|store\|save"; then
        suggestions+=("Data persistence and retrieval")
    fi
    if echo "$PROJECT_DESCRIPTION" | grep -qi "cli\|command\|terminal"; then
        suggestions+=("Command-line interface")
    fi

    if [ ${#suggestions[@]} -eq 0 ]; then
        suggestions+=("Core functionality")
        suggestions+=("Error handling")
        suggestions+=("Configuration")
    fi

    local i=1
    for s in "${suggestions[@]}"; do
        echo -e "  ${GREEN}$i)${NC} $s"
        ((i++))
    done

    echo ""
    echo "You can add these as features in the next step, or create your own."
    read -p "Press Enter to continue..."
}

# --- Validation ---

validate_completeness() {
    print_step "Validation: Completeness Check"

    echo "Let's check for missing features..."
    echo ""

    local missing=()

    # Check for common missing pieces
    local has_error_handling=false
    local has_validation=false
    local has_config=false

    for feature in "${FEATURES[@]}"; do
        if echo "$feature" | grep -qi "error"; then
            has_error_handling=true
        fi
        if echo "$feature" | grep -qi "valid"; then
            has_validation=true
        fi
        if echo "$feature" | grep -qi "config\|setting"; then
            has_config=true
        fi
    done

    [ "$has_error_handling" = false ] && missing+=("Error handling - what happens when things fail?")
    [ "$has_validation" = false ] && missing+=("Input validation - how do you handle bad input?")

    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${YELLOW}Potentially missing:${NC}"
        for m in "${missing[@]}"; do
            echo -e "  • $m"
        done
        echo ""
        if confirm "Add features for any of these?"; then
            for m in "${missing[@]}"; do
                if confirm "Add: $m?"; then
                    read -p "Description: " desc
                    [ -n "$desc" ] && add_feature_direct "functional" "$desc" "Verify it handles the case|Check error messages"
                fi
            done
        fi
    else
        echo -e "${GREEN}Looks complete!${NC}"
    fi

    # Edge cases
    echo ""
    echo "Quick edge case check:"
    if confirm "Have you considered empty states (no data)?"; then
        :
    else
        echo "Consider adding a feature for empty state handling"
    fi

    if confirm "Have you considered error states?"; then
        :
    else
        echo "Consider adding features for error scenarios"
    fi
}

validate_priority() {
    print_step "Validation: Priority Ordering"

    echo "Current feature order:"
    list_features

    echo "Features should be ordered by:"
    echo "  1. Dependencies (what must be built first)"
    echo "  2. Priority (most important for MVP)"
    echo ""

    if confirm "Would you like to reorder features?"; then
        echo "Enter the new order as numbers separated by spaces"
        echo "Example: 3 1 2 4 (moves feature 3 to first position)"
        read -p "> " order

        if [ -n "$order" ]; then
            local new_features=()
            for num in $order; do
                if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le ${#FEATURES[@]} ]; then
                    new_features+=("${FEATURES[$((num-1))]}")
                fi
            done

            if [ ${#new_features[@]} -eq ${#FEATURES[@]} ]; then
                FEATURES=("${new_features[@]}")
                echo -e "${GREEN}Reordered!${NC}"
                list_features
            else
                echo -e "${RED}Invalid order, keeping original${NC}"
            fi
        fi
    fi
}

review_features() {
    print_step "Validation: Feature Review"

    echo "Review each feature:"
    echo ""

    local i=0
    for feature in "${FEATURES[@]}"; do
        IFS='|' read -r category description steps <<< "$feature"

        echo -e "${BOLD}Feature $((i+1)):${NC}"
        echo -e "  Description: $description"
        echo -e "  Category: $category"
        echo -e "  Steps: $(echo $steps | tr '|' ', ')"
        echo ""

        if ! confirm "  Is this correct?"; then
            echo "  1) Edit  2) Delete  3) Skip"
            read -p "  Choice: " choice
            case $choice in
                1)
                    read -p "  New description (or Enter to keep): " new_desc
                    [ -n "$new_desc" ] && FEATURES[$i]="$category|$new_desc|$steps"
                    ;;
                2)
                    unset 'FEATURES[$i]'
                    ;;
            esac
        fi
        ((i++))
    done

    # Rebuild array to remove gaps
    FEATURES=("${FEATURES[@]}")
    echo -e "${GREEN}Review complete${NC}"
}

# --- Output ---

generate_prd_json() {
    print_step "Generating prd.json"

    mkdir -p plans

    local output="["
    local first=true

    for feature in "${FEATURES[@]}"; do
        IFS='|' read -r category description steps <<< "$feature"

        [ "$first" = false ] && output+=","
        first=false

        output+=$'\n  {'
        output+=$'\n    "category": "'"$category"'",'
        output+=$'\n    "description": "'"$description"'",'
        output+=$'\n    "steps": ['

        local step_first=true
        IFS='|' read -ra step_array <<< "$steps"
        for step in "${step_array[@]}"; do
            [ "$step_first" = false ] && output+=","
            step_first=false
            output+=$'\n      "'"$step"'"'
        done

        output+=$'\n    ],'
        output+=$'\n    "passes": false'
        output+=$'\n  }'
    done

    output+=$'\n]'

    echo "$output" > plans/prd.json
    echo -e "${GREEN}✓ Created plans/prd.json${NC}"
}

save_as_template() {
    if confirm "Save this as a reusable template?"; then
        read -p "Template name: " name

        if [ -n "$name" ]; then
            init_template_dir
            cp plans/prd.json "$TEMPLATE_DIR/$name.json"
            echo -e "${GREEN}✓ Saved to ~/.plan-init/templates/$name.json${NC}"
        fi
    fi
}

# --- Load Existing ---

load_existing_prd() {
    if [ ! -f "plans/prd.json" ]; then
        echo "No existing prd.json found"
        return 1
    fi

    echo -e "${YELLOW}Found existing plans/prd.json${NC}"
    echo "1) Create new (overwrite)"
    echo "2) Modify existing"
    echo "3) Cancel"
    read -p "Choice: " choice

    case $choice in
        1) FEATURES=(); return 0 ;;
        2) load_custom_template "plans/prd.json"; return 0 ;;
        3) return 1 ;;
    esac
}

# --- Feature Building Menu ---

feature_building_menu() {
    print_step "Step 4: Feature Building"

    while true; do
        echo ""
        echo "Features: ${#FEATURES[@]}"
        echo ""
        echo "1) Add feature"
        echo "2) List features"
        echo "3) Edit feature"
        echo "4) Delete feature"
        echo "5) Deep-dive with Claude"
        echo "6) Done - proceed to validation"
        echo ""
        read -p "Choice: " choice

        case $choice in
            1) add_feature_interactive ;;
            2) list_features ;;
            3) edit_feature ;;
            4) delete_feature ;;
            5)
                echo ""
                echo -e "${CYAN}To deep-dive with Claude, run:${NC}"
                echo -e "  ${BOLD}./plan-claude.sh${NC}"
                echo ""
                echo "This will have Claude interview you about technical"
                echo "and UX details using the AskUserQuestion tool."
                read -p "Press Enter to continue..."
                ;;
            6)
                if [ ${#FEATURES[@]} -eq 0 ]; then
                    echo -e "${RED}Add at least one feature first${NC}"
                else
                    break
                fi
                ;;
        esac
    done
}

# --- Main Menu ---

main_menu() {
    while true; do
        print_header
        echo "1) New project"
        echo "2) Modify existing prd.json"
        echo "3) Quick start with template"
        echo "4) Help"
        echo "5) Exit"
        echo ""
        read -p "Choice: " choice

        case $choice in
            1) run_full_workflow ;;
            2)
                if load_existing_prd; then
                    feature_building_menu
                    run_validation
                    run_output
                fi
                ;;
            3) run_template_workflow ;;
            4) show_help ;;
            5) exit 0 ;;
        esac
    done
}

run_full_workflow() {
    FEATURES=()
    get_project_description
    select_template
    suggest_features
    feature_building_menu
    run_validation
    run_output
}

run_template_workflow() {
    FEATURES=()
    select_template
    list_features
    if confirm "Customize these features?"; then
        feature_building_menu
    fi
    run_validation
    run_output
}

run_validation() {
    review_features
    validate_completeness
    validate_priority
}

run_output() {
    generate_prd_json
    save_as_template

    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║     PRD Generation Complete!          ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
    echo ""
    echo "Created: plans/prd.json with ${#FEATURES[@]} features"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "  1. Review plans/prd.json"
    echo "  2. Run ./ralph-init.sh to scaffold RALPH files"
    echo "  3. Run ./ralph.sh to start building"
    echo ""

    read -p "Press Enter to return to menu..."
}

show_help() {
    echo ""
    echo -e "${BOLD}Plan-Init Help${NC}"
    echo ""
    echo "This tool helps you create well-structured PRD files for use"
    echo "with the RALPH loop automation system."
    echo ""
    echo -e "${BOLD}Workflow:${NC}"
    echo "  1. Describe your project"
    echo "  2. Choose a starting template (or blank)"
    echo "  3. Add/edit features with verification steps"
    echo "  4. Validate completeness and priority"
    echo "  5. Generate prd.json"
    echo ""
    echo -e "${BOLD}Tips:${NC}"
    echo "  • Keep features small - one RALPH iteration each"
    echo "  • Be specific in verification steps"
    echo "  • Use Claude deep-dive for complex features"
    echo ""
    echo -e "${BOLD}Files:${NC}"
    echo "  • Output: plans/prd.json"
    echo "  • Templates: ~/.plan-init/templates/"
    echo ""
    read -p "Press Enter to continue..."
}

# --- Entry Point ---

init_template_dir

# Check for command line arguments
if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    show_help
    exit 0
fi

main_menu
