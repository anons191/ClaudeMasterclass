#!/bin/bash

# RALPH Ecosystem Installer
# Installs plan-init, plan-claude, and ralph-init to ~/bin

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

REPO="https://raw.githubusercontent.com/anons191/ClaudeMasterclass/main"
INSTALL_DIR="$HOME/bin"

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════╗"
echo "║     RALPH Ecosystem Installer         ║"
echo "╚═══════════════════════════════════════╝"
echo -e "${NC}"

# Create install directory
mkdir -p "$INSTALL_DIR"

# Download scripts
echo -e "${YELLOW}Downloading tools...${NC}"

curl -sL "$REPO/plan-init.sh" -o "$INSTALL_DIR/plan-init"
curl -sL "$REPO/plan-claude.sh" -o "$INSTALL_DIR/plan-claude"
curl -sL "$REPO/ralph-init.sh" -o "$INSTALL_DIR/ralph-init"
curl -sL "$REPO/ralph-existing.sh" -o "$INSTALL_DIR/ralph-existing"

# Make executable
chmod +x "$INSTALL_DIR/plan-init"
chmod +x "$INSTALL_DIR/plan-claude"
chmod +x "$INSTALL_DIR/ralph-init"
chmod +x "$INSTALL_DIR/ralph-existing"

echo -e "${GREEN}✓ Downloaded plan-init${NC}"
echo -e "${GREEN}✓ Downloaded plan-claude${NC}"
echo -e "${GREEN}✓ Downloaded ralph-init${NC}"
echo -e "${GREEN}✓ Downloaded ralph-existing${NC}"

# Check if ~/bin is in PATH
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

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     Installation Complete!            ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
echo ""
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
echo ""
