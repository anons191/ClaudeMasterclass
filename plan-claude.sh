#!/bin/bash

# Plan-Claude: Deep-Dive Planning with Claude
# Uses Claude's AskUserQuestion tool for detailed interviews
# Part of the RALPH ecosystem

set -e

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════╗"
echo "║     Plan-Claude: Deep-Dive Interview  ║"
echo "║     RALPH Ecosystem                   ║"
echo "╚═══════════════════════════════════════╝"
echo -e "${NC}"

# Check for existing PRD
PRD_FILE="plans/prd.json"
if [ -f "$PRD_FILE" ]; then
    echo -e "${GREEN}Found existing PRD: $PRD_FILE${NC}"
    echo ""
    echo "Options:"
    echo "1) Interview to refine existing features"
    echo "2) Interview to add new features"
    echo "3) Full project interview (start fresh)"
    read -p "Choice [1]: " mode
    mode=${mode:-1}
else
    echo -e "${YELLOW}No existing PRD found. Starting fresh interview.${NC}"
    mode=3
fi

case $mode in
    1)
        # Refine existing features
        echo ""
        echo -e "${CYAN}Starting refinement interview...${NC}"
        echo ""

        claude --permission-mode acceptEdits -p "@$PRD_FILE \
You are helping refine a PRD (Product Requirements Document) for a software project.

Read the PRD file provided. For each feature that seems vague or could benefit from more detail:

1. Use the AskUserQuestion tool to interview the user about:
   - Technical implementation details
   - UI/UX decisions (if applicable)
   - Edge cases and error handling
   - Acceptance criteria clarity

2. After gathering information, update the prd.json file with:
   - More specific descriptions
   - Additional verification steps
   - Any new features that emerged from the discussion

3. If a feature seems too large for one iteration, suggest splitting it and ask the user if they agree.

Guidelines:
- Ask focused questions (2-4 options per question)
- Group related questions together
- Be thorough but efficient
- Ensure each feature is small enough for one RALPH iteration
- Each feature should have clear, testable verification steps

Start by reviewing the PRD and identifying which features need refinement, then begin the interview.
"
        ;;

    2)
        # Add new features
        echo ""
        echo -e "${CYAN}Starting interview to add new features...${NC}"
        echo ""

        claude --permission-mode acceptEdits -p "@$PRD_FILE \
You are helping expand a PRD (Product Requirements Document) for a software project.

Read the existing PRD file. Then interview the user to discover additional features that may be missing.

Use the AskUserQuestion tool to explore:
1. Error handling - What happens when things fail?
2. Edge cases - Empty states, limits, boundaries?
3. User flows - First-time users, returning users, admin users?
4. Configuration - What should be configurable?
5. Performance - Any performance requirements?
6. Security - Authentication, authorization, data protection?

For each new feature identified:
1. Ask follow-up questions to define it clearly
2. Help break it down if it's too large
3. Define verification steps

After the interview, append the new features to the existing prd.json file. Each new feature should have:
- category
- description
- steps (verification criteria)
- passes: false

Keep features small and focused - one RALPH iteration each.
"
        ;;

    3)
        # Full interview
        echo ""
        echo -e "${CYAN}Starting full project interview...${NC}"
        echo ""

        mkdir -p plans

        claude --permission-mode acceptEdits -p "\
You are helping create a comprehensive PRD (Product Requirements Document) for a new software project.

Your job is to interview the user thoroughly using the AskUserQuestion tool to understand what they want to build, then create a prd.json file.

## Interview Process

### Phase 1: Project Understanding
Ask about:
- What is the project? (type, purpose, users)
- What problem does it solve?
- What's the MVP scope?

### Phase 2: Feature Discovery
For each major area, ask detailed questions:
- Core functionality - what must it do?
- User interface - what do users see and interact with?
- Data - what data is stored, retrieved, processed?
- Integrations - any external services?
- Configuration - what's customizable?

### Phase 3: Feature Refinement
For each feature identified:
- Is it small enough for one iteration? (suggest splits if not)
- What are the verification steps? (how do we know it works?)
- What category is it? (functional, ui, api, data, config)

### Phase 4: Validation
- Are there missing error handling features?
- Are there missing edge cases?
- What's the priority order?

## Output

After the interview, create plans/prd.json with this structure:
\`\`\`json
[
  {
    \"category\": \"functional|ui|api|data|config\",
    \"description\": \"Clear description of the feature\",
    \"steps\": [
      \"Verification step 1\",
      \"Verification step 2\"
    ],
    \"passes\": false
  }
]
\`\`\`

## Guidelines
- Use AskUserQuestion with 2-4 clear options
- Ask follow-up questions for vague answers
- Keep features small (completable in one RALPH iteration)
- Be thorough - missing features cause problems later
- Verification steps should be specific and testable

Begin by asking the user to describe their project.
"
        ;;
esac

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     Interview Complete!               ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
echo ""
echo "Your PRD has been updated: plans/prd.json"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Review plans/prd.json"
echo "  2. Run ./ralph-init.sh (if not done)"
echo "  3. Run ./ralph.sh to start building"
echo ""
