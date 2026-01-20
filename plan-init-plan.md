# Plan-Init Tool - Project Plan

## Overview
A CLI planning tool that helps create well-structured PRD files through guided interviews, following the masterclass principles. Part of the RALPH ecosystem.

## User Story
As a developer, I want to run `plan-init` to be guided through breaking down my project into properly-sized features with clear verification steps, so I can generate a prd.json ready for RALPH automation.

---

## Core Workflow

```
plan-init
    │
    ├── 1. PROJECT INTAKE
    │   ├── Ask for project description
    │   ├── Offer template selection (or custom)
    │   └── Suggest initial feature breakdown
    │
    ├── 2. FEATURE BUILDING
    │   ├── For each feature:
    │   │   ├── Define description
    │   │   ├── Add verification steps
    │   │   ├── Check size (warn if too big)
    │   │   └── Suggest splits if needed
    │   └── Option: deep-dive with Claude
    │
    ├── 3. VALIDATION
    │   ├── Review each feature
    │   ├── Completeness check (missing features?)
    │   └── Priority ordering
    │
    └── 4. OUTPUT
        ├── Generate prd.json
        └── Save template (optional)
```

---

## Features

### Feature 1: Project Intake - Description Capture
**Category:** core
**Description:** Prompt user for project description and understand what they're building
**Steps:**
- Display welcome message and explain the process
- Ask user to describe their project in 2-3 sentences
- Parse key concepts (what type of app, main functionality)
- Confirm understanding with user
**Passes:** false

### Feature 2: Project Intake - Template Selection
**Category:** core
**Description:** Offer project templates or let user start from scratch
**Steps:**
- Check for saved custom templates in ~/.plan-init/templates/
- Display available templates (built-in + custom)
- Let user select template or choose "blank"
- If template selected, load starter features for customization
**Passes:** false

### Feature 3: Project Intake - Initial Feature Suggestion
**Category:** core
**Description:** Based on project description, suggest initial feature breakdown
**Steps:**
- Analyze project description keywords
- Suggest relevant feature categories (auth, data, UI, API, etc.)
- Display suggested features as starting point
- Let user accept, modify, or start from scratch
**Passes:** false

### Feature 4: Feature Building - Add Feature Flow
**Category:** core
**Description:** Guided flow to add a single feature with all required fields
**Steps:**
- Prompt for feature category (functional, ui, api, data, etc.)
- Prompt for feature description (what it does)
- Prompt for verification steps (how to test)
- Display complete feature for confirmation
- Add to feature list
**Passes:** false

### Feature 5: Feature Building - Size Warning System
**Category:** core
**Description:** Detect features that may be too large for one RALPH iteration
**Steps:**
- Analyze feature description for complexity keywords
- Check number of verification steps (warn if > 5)
- Check if description contains multiple actions (and, then, also)
- Display warning if feature seems too large
- Suggest splitting into smaller features
**Passes:** false

### Feature 6: Feature Building - Auto-Split Suggestions
**Category:** core
**Description:** Propose how to break large features into smaller ones
**Steps:**
- Parse feature description for logical breakpoints
- Generate 2-3 smaller feature suggestions
- Display split options to user
- Let user accept split, modify, or keep original
- If accepted, replace original with split features
**Passes:** false

### Feature 7: Feature Building - Verification Step Helper
**Category:** core
**Description:** Help users write good verification steps
**Steps:**
- After feature description, ask "How would you verify this works?"
- Suggest common verification patterns based on category
- Prompt for each step until user says done
- Ensure steps are specific and testable
**Passes:** false

### Feature 8: Claude Deep-Dive Integration
**Category:** integration
**Description:** Separate script to invoke Claude for detailed feature interviews
**Steps:**
- Create plan-claude.sh as companion script
- Script passes current prd.json to Claude
- Prompts Claude to use AskUserQuestion for deep technical/UX questions
- Claude outputs refined features
- Merge Claude's output back into prd.json
**Passes:** false

### Feature 9: Validation - Feature Review
**Category:** validation
**Description:** Review each feature and allow edits before finalizing
**Steps:**
- Display all features in numbered list
- Let user select feature to edit or confirm
- For edits: allow changing description, steps, category
- Mark reviewed features
- Continue until all reviewed
**Passes:** false

### Feature 10: Validation - Completeness Check
**Category:** validation
**Description:** Probing questions to find missing features or edge cases
**Steps:**
- Ask about error handling (what if X fails?)
- Ask about edge cases (empty states, limits)
- Ask about user flows (first-time user, returning user)
- Suggest features for any gaps identified
- Let user add or skip suggested features
**Passes:** false

### Feature 11: Validation - Priority Ordering
**Category:** validation
**Description:** Help user order features by priority and dependency
**Steps:**
- Display all features
- Ask which features depend on others
- Ask which are highest priority / MVP
- Reorder list based on dependencies + priority
- Display final ordered list for confirmation
**Passes:** false

### Feature 12: Output - Generate prd.json
**Category:** output
**Description:** Generate the final RALPH-compatible prd.json file
**Steps:**
- Format all features as JSON array
- Each feature has: category, description, steps, passes (false)
- Write to plans/prd.json (create plans/ if needed)
- Display success message with file path
- Show next steps (run ralph-init if not done, then ralph.sh)
**Passes:** false

### Feature 13: Output - Save as Template
**Category:** output
**Description:** Let user save their feature set as a reusable template
**Steps:**
- After generating prd.json, ask if user wants to save as template
- If yes, prompt for template name
- Save to ~/.plan-init/templates/{name}.json
- Strip project-specific details, keep structure
- Confirm template saved
**Passes:** false

### Feature 14: Iteration - Load Existing PRD
**Category:** iteration
**Description:** Load and modify an existing prd.json file
**Steps:**
- Check if plans/prd.json exists
- If exists, ask: create new, or modify existing?
- If modify: load features into working list
- Show current features, allow add/edit/delete
- Preserve completed features (passes: true)
**Passes:** false

### Feature 15: Main Menu Navigation
**Category:** ux
**Description:** Clear menu system for navigating the tool
**Steps:**
- Display main menu with options: New Project, Modify Existing, Use Template, Help
- Handle user selection
- Allow returning to menu at any point (e.g., 'm' for menu)
- Show progress indicator (Step 2/4: Feature Building)
**Passes:** false

---

## Technical Implementation

### File Structure
```
plan-init/
├── plan-init.sh        # Main CLI tool (bash)
├── plan-claude.sh      # Claude deep-dive script
└── README.md           # Documentation
```

### User Data Location
```
~/.plan-init/
└── templates/          # Custom saved templates
    ├── webapp.json
    ├── api.json
    └── ...
```

### Generated Output
```
project/
└── plans/
    └── prd.json        # RALPH-compatible PRD
```

### Built-in Templates (Starter)
1. **Web App** - Auth, CRUD, UI components, navigation
2. **API Service** - Endpoints, validation, error handling, docs
3. **CLI Tool** - Commands, flags, help, config
4. **Library** - Core functions, types, exports, docs

### Size Detection Heuristics
- Description > 100 characters → warning
- Contains "and" multiple times → suggest split
- More than 5 verification steps → warning
- Keywords: "complete", "full", "entire" → warning

---

## Integration with RALPH Ecosystem

```
plan-init.sh  →  prd.json  →  ralph-init.sh  →  ralph.sh
   (plan)         (PRD)        (scaffold)       (execute)
```

**Workflow:**
1. Run `plan-init` to create your PRD
2. Run `ralph-init` to scaffold RALPH files (uses your prd.json)
3. Run `ralph.sh` to execute the build loop

---

## Success Criteria

1. User can create a complete prd.json through guided prompts
2. Features are properly sized for RALPH iterations
3. Each feature has clear verification steps
4. User can save and reuse templates
5. Can load and modify existing prd.json
6. Claude integration works for deep technical questions
7. Output is 100% compatible with ralph.sh

---

## Out of Scope (Future)
- GUI/web interface
- Direct git integration
- Multi-user collaboration
- AI-generated features (beyond Claude deep-dive)
- Project estimation/timeline features
