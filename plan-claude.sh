#!/bin/bash

# Plan-Claude: AI-Driven Project Planning with Claude
# Uses Claude's AskUserQuestion tool for comprehensive project interviews
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
echo "║     Plan-Claude: AI Project Planner   ║"
echo "║     RALPH Ecosystem                   ║"
echo "╚═══════════════════════════════════════╝"
echo -e "${NC}"

# Create plans directory and prompt file
mkdir -p plans
PROMPT_FILE=$(mktemp)

# Check for existing PRD
if [ -f "plans/prd.json" ]; then
    echo -e "${YELLOW}Found existing plans/prd.json${NC}"
    echo ""
    echo "1) Start fresh (overwrite)"
    echo "2) Refine existing features"
    echo "3) Add new features to existing"
    echo "4) Cancel"
    read -p "Choice [1]: " mode
    mode=${mode:-1}
else
    echo -e "${CYAN}Starting new project planning session...${NC}"
    mode=1
fi

case $mode in
    1)
        # Full interview - start fresh
        cat > "$PROMPT_FILE" << 'PROMPT'
You are an expert product manager and software architect helping plan a new project.

Your job is to conduct a thorough interview using the AskUserQuestion tool, then generate a prd.json file with well-defined, properly-sized features.

## IMPORTANT: Use AskUserQuestion Tool

You MUST use the AskUserQuestion tool to interview the user. Do NOT just ask questions in plain text - use the actual tool with structured options.

## Interview Phases

### Phase 1: What Are We Building?
START HERE. Use AskUserQuestion to ask the user to describe what they want to build.
Ask an open-ended question like: "What are we building? Describe your project idea."
Let them explain in their own words before you start categorizing or suggesting.

Follow up to understand:
- What type of project is this? (web app, API, CLI, mobile, etc.)
- What is the core problem it solves?
- Who are the target users?
- What's the MVP scope vs future features?

### Phase 2: Feature Discovery
Use AskUserQuestion to explore each major area:
- Core functionality - what MUST it do?
- User interface - what do users see/interact with?
- Data layer - what data is stored/processed?
- Integrations - external services needed?
- Authentication - how do users log in?

For each feature area, dig deeper with follow-up questions.

### Phase 3: Technical Decisions
Use AskUserQuestion for key technical choices:
- What frameworks/languages?
- What's the deployment target?
- Any specific libraries or protocols required?
- Performance or security requirements?

### Phase 4: Feature Refinement & Sizing
For each feature identified:
- Is it small enough for ONE Claude iteration? (If not, suggest splitting)
- What are the specific verification steps?
- What category is it? (functional, ui, api, data, config)

IMPORTANT: If a feature seems too large (multiple components, 'complete X system', etc.), WARN the user and suggest splitting it into smaller features.

### Phase 5: Validation
Use AskUserQuestion to confirm:
- Are there missing error handling features?
- Are there missing edge cases?
- What's the priority order?
- Final review of all features

## Output

After the interview, create TWO files:

### 1. plans/prd.json
```json
[
  {
    "category": "functional|ui|api|data|config",
    "description": "Clear, specific description",
    "steps": [
      "Verification step 1",
      "Verification step 2"
    ],
    "passes": false
  }
]
```

### 2. progress.txt
Initialize with planning session notes:
```
# Progress Log

## [Today's Date] - Project Planning Session

### Project Overview
[Summary of what was decided]

### Technical Decisions
[Key technical choices made]

### Notes for Development
[Any important context for the build phase]

---
```

## Guidelines

- Use AskUserQuestion with 2-4 clear options per question
- Ask follow-up questions when answers are vague
- Keep features SMALL - each should be completable in one RALPH iteration
- Verification steps should be specific and testable
- If unsure about something, ASK - don't assume
- Be thorough - missing features cause problems later

## Begin

Start NOW by using AskUserQuestion to ask about the project type and core purpose. Use the tool immediately.
PROMPT
        ;;

    2)
        # Refine existing features
        cat > "$PROMPT_FILE" << 'PROMPT'
You are helping refine an existing PRD (Product Requirements Document).

Read the file plans/prd.json first. Your job is to interview the user to IMPROVE these features using the AskUserQuestion tool.

## For Each Feature, Use AskUserQuestion to Explore:

1. **Clarity**: Is the description clear enough? If vague, ask clarifying questions.

2. **Sizing**: Is this feature small enough for ONE iteration?
   - If it seems large, propose how to split it
   - Use AskUserQuestion to confirm with user

3. **Verification Steps**: Are the steps specific and testable?
   - If steps are vague like 'verify it works', ask for specifics
   - What exactly should be checked?

4. **Edge Cases**: What could go wrong?
   - Error states
   - Empty states
   - Invalid input

5. **Dependencies**: Does this feature depend on others?
   - Should it be reordered?

## After Interview

Update prd.json with:
- Clearer descriptions
- Better verification steps
- Any split features
- Reordered priorities if needed

Update progress.txt with notes about what was refined and why.

## Begin

First read plans/prd.json, then start by using AskUserQuestion to ask which features the user wants to refine.
PROMPT
        ;;

    3)
        # Add new features
        cat > "$PROMPT_FILE" << 'PROMPT'
You are helping expand an existing PRD by discovering missing features.

Read the file plans/prd.json first. Your job is to find GAPS and MISSING features through an interview.

## Use AskUserQuestion to Explore Missing Areas:

1. **Error Handling** - What happens when things fail?
2. **Edge Cases** - Empty states, boundary conditions, first-time user
3. **User Flows** - Alternative paths, admin vs regular user
4. **Security** - Authentication, authorization, data protection
5. **Performance** - Loading states, pagination, caching
6. **Configuration** - What should be configurable?

## For Each New Feature Identified

Use AskUserQuestion to:
- Confirm the user wants this feature
- Define the description clearly
- Determine verification steps
- Check sizing (split if too large)

## After Interview

APPEND new features to prd.json (don't remove existing ones).
Update progress.txt with notes about what was added.

## Begin

First read plans/prd.json, then use AskUserQuestion to ask which area to explore for missing features.
PROMPT
        ;;

    4)
        echo "Cancelled."
        rm -f "$PROMPT_FILE"
        exit 0
        ;;
esac

echo ""
echo -e "${GREEN}Starting Claude interview session...${NC}"
echo -e "${CYAN}Claude will use AskUserQuestion to interview you.${NC}"
echo ""

# Run Claude interactively with the prompt
claude --permission-mode acceptEdits "$PROMPT_FILE"

# Cleanup
rm -f "$PROMPT_FILE"

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     Planning Session Complete!        ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
echo ""
echo "Files created/updated:"
echo "  - plans/prd.json   (your features)"
echo "  - progress.txt     (planning notes)"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Review plans/prd.json"
echo "  2. Run: ralph-init    (scaffold RALPH files)"
echo "  3. Run: ./ralph.sh 10 (start building)"
echo ""
