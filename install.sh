#!/bin/bash

# RALPH Ecosystem Installer
# Installs plan-init, plan-claude, ralph-init, and ralph-existing
#
# Usage:
#   Global install (to ~/bin):  curl -sL .../install.sh | bash
#   Local install (to ./):      curl -sL .../install.sh | bash -s -- --local

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

REPO="https://raw.githubusercontent.com/anons191/let-ralph-cook/main"

# Parse arguments
LOCAL_INSTALL=false
for arg in "$@"; do
    case $arg in
        --local|-l)
            LOCAL_INSTALL=true
            shift
            ;;
    esac
done

# Set install directory based on mode
if [ "$LOCAL_INSTALL" = true ]; then
    INSTALL_DIR="."
    SUFFIX=".sh"
else
    INSTALL_DIR="$HOME/bin"
    SUFFIX=""
fi

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════╗"
echo "║     RALPH Ecosystem Installer         ║"
echo "╚═══════════════════════════════════════╝"
echo -e "${NC}"

if [ "$LOCAL_INSTALL" = true ]; then
    echo -e "${YELLOW}Installing locally to current directory...${NC}"
else
    echo -e "${YELLOW}Installing globally to ~/bin...${NC}"
    mkdir -p "$INSTALL_DIR"
fi

echo ""

# Download scripts
echo -e "${YELLOW}Downloading tools...${NC}"

curl -sL "$REPO/plan-init.sh" -o "$INSTALL_DIR/plan-init$SUFFIX"
curl -sL "$REPO/plan-claude.sh" -o "$INSTALL_DIR/plan-claude$SUFFIX"
curl -sL "$REPO/ralph-init.sh" -o "$INSTALL_DIR/ralph-init$SUFFIX"
curl -sL "$REPO/ralph-existing.sh" -o "$INSTALL_DIR/ralph-existing$SUFFIX"

# Make executable
chmod +x "$INSTALL_DIR/plan-init$SUFFIX"
chmod +x "$INSTALL_DIR/plan-claude$SUFFIX"
chmod +x "$INSTALL_DIR/ralph-init$SUFFIX"
chmod +x "$INSTALL_DIR/ralph-existing$SUFFIX"

echo -e "${GREEN}✓ Downloaded plan-init$SUFFIX${NC}"
echo -e "${GREEN}✓ Downloaded plan-claude$SUFFIX${NC}"
echo -e "${GREEN}✓ Downloaded ralph-init$SUFFIX${NC}"
echo -e "${GREEN}✓ Downloaded ralph-existing$SUFFIX${NC}"

# Only modify PATH for global install
if [ "$LOCAL_INSTALL" = false ]; then
    if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
        echo ""
        echo -e "${YELLOW}Adding ~/bin to PATH...${NC}"

        # Detect shell config file
        if [ -f "$HOME/.zshrc" ]; then
            SHELL_RC="$HOME/.zshrc"
        elif [ -f "$HOME/.bashrc" ]; then
            SHELL_RC="$HOME/.bashrc"
        elif [ -f "$HOME/.bash_profile" ]; then
            SHELL_RC="$HOME/.bash_profile"
        else
            SHELL_RC="$HOME/.profile"
        fi

        echo 'export PATH="$HOME/bin:$PATH"' >> "$SHELL_RC"
        echo -e "${GREEN}✓ Added to $SHELL_RC${NC}"
        echo ""
        echo -e "${YELLOW}Run this to use immediately:${NC}"
        echo "  export PATH=\"\$HOME/bin:\$PATH\""
        echo ""
        echo -e "${YELLOW}Or restart your terminal.${NC}"
    else
        echo -e "${GREEN}✓ ~/bin already in PATH${NC}"
    fi
fi

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     Installation Complete!            ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
echo ""

if [ "$LOCAL_INSTALL" = true ]; then
    echo "Installed to: $(pwd)"
    echo ""
    echo "Scripts available:"
    echo "  ./plan-init.sh      - Create PRD through guided interview"
    echo "  ./plan-claude.sh    - Deep-dive planning with Claude"
    echo "  ./ralph-init.sh     - Scaffold RALPH files (new projects)"
    echo "  ./ralph-existing.sh - Analyze codebase & scaffold (existing projects)"
    echo ""
    echo -e "${YELLOW}Quick Start (new project):${NC}"
    echo "  ./plan-init.sh      # Plan your features"
    echo "  ./ralph-init.sh     # Scaffold RALPH files"
    echo "  ./ralph.sh 10       # Build with Claude"
    echo ""
    echo -e "${YELLOW}Quick Start (existing project):${NC}"
    echo "  ./ralph-existing.sh # Analyze & scaffold with smart PRD"
    echo "  ./ralph-once.sh     # Build incrementally"
else
    echo "Installed to: $INSTALL_DIR"
    echo ""
    echo "Commands available:"
    echo "  plan-init      - Create PRD through guided interview"
    echo "  plan-claude    - Deep-dive planning with Claude"
    echo "  ralph-init     - Scaffold RALPH files (new projects)"
    echo "  ralph-existing - Analyze codebase & scaffold (existing projects)"
    echo ""
    echo -e "${YELLOW}Quick Start (new project):${NC}"
    echo "  cd your-project"
    echo "  plan-init        # Plan your features"
    echo "  ralph-init       # Scaffold RALPH files"
    echo "  ./ralph.sh 10    # Build with Claude"
    echo ""
    echo -e "${YELLOW}Quick Start (existing project):${NC}"
    echo "  cd your-existing-project"
    echo "  ralph-existing   # Analyze & scaffold with smart PRD"
    echo "  ./ralph-once.sh  # Build incrementally"
fi
echo ""
