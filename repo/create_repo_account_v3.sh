#!/bin/bash

# Enhanced Repository Account Association v3.0 - macOS Compatible
# Focus: Associate existing repos/directories with GitHub accounts
# Features: Reliable TUI, full verification, jq-free

# Color codes (from v2)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'

# Emojis
EMOJI_CHECK="✅"
EMOJI_ERROR="❌"
EMOJI_WARN="⚠️"
EMOJI_GITHUB="🐙"
EMOJI_KEY="🔑"
EMOJI_REPO="📁"
EMOJI_GIT="🔧"
EMOJI_PARTY="🎉"
EMOJI_CLOCK="⏰"
EMOJI_ARROW="➡️"
EMOJI_MAG="🔍"
EMOJI_ROCKET="🚀"

# Paths
GITHUB_DIR="$HOME/.ssh/github"
ACCOUNTS_JSON="$GITHUB_DIR/accounts.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Simple spinner (inline, no deps)
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while kill -0 $pid 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# JSON helpers (jq-free, from v2)
json_list_accounts() {
    if [ -f "$ACCOUNTS_JSON" ]; then
        grep -o '"account"[[:space:]]*:[[:space:]]*"[^"]*"' "$ACCOUNTS_JSON" 2>/dev/null | sed 's/"account"[[:space:]]*:[[:space:]]*"\([^"]*\)"/\1/g'
    fi
}

json_get_account_email() {
    local account="$1"
    if [ -f "$ACCOUNTS_JSON" ]; then
        grep -A5 "\"account\"[[:space:]]*:[[:space:]]*\"$account\"" "$ACCOUNTS_JSON" 2>/dev/null | grep '"email"' | head -1 | sed 's/.*"email":"\([^"]*\)".*/\1/'
    fi
}

json_get_ssh_key_path() {
    local account="$1"
    if [ -f "$ACCOUNTS_JSON" ]; then
        grep -A5 "\"account\"[[:space:]]*:[[:space:]]*\"$account\"" "$ACCOUNTS_JSON" 2>/dev/null | grep '"private_key"' | head -1 | sed 's/.*"private_key":"\([^"]*\)".*/\1/'
    fi
}

# .git-account functions (adapted from v2)
find_git_account_file() {
    local current_dir="$1"
    local search_dir="$current_dir"
    while [ "$search_dir" != "/" ]; do
        if [ -f "$search_dir/.git-account" ]; then
            echo "$search_dir/.git-account"
            return 0
        fi
        search_dir="$(dirname "$search_dir")"
    done
    return 1
}

read_git_account_config() {
    local git_account_file="$1"
    if [ -f "$git_account_file" ]; then
        source "$git_account_file"
        echo "$ACCOUNT_ALIAS:$GIT_NAME:$GIT_EMAIL:$SSH_KEY_PATH:$SSH_HOST_ALIAS:$REMOTE_REPO"
    fi
}

write_git_account_config() {
    local account_alias="$1"
    local git_name="$2"
    local git_email="$3"
    local ssh_key_path="$4"
    local ssh_host_alias="$5"
    local remote_repo="$6"
    local output_file="$7"
    
    cat > "$output_file" << EOF
# GitHub Account Configuration
# This file associates this repository with a specific GitHub account

ACCOUNT_ALIAS="$account_alias"
GIT_NAME="$git_name"
GIT_EMAIL="$git_email"
SSH_KEY_PATH="$ssh_key_path"
SSH_HOST_ALIAS="$ssh_host_alias"
REMOTE_REPO="$remote_repo"

# Generated on: $(date '+%Y-%m-%d %H:%M:%S')
# Last updated: $(date '+%Y-%m-%d %H:%M:%S')
EOF
}

ensure_gitignore_has_git_account() {
    local repo_dir="$1"
    local gitignore_file="$repo_dir/.gitignore"
    
    if [ ! -f "$gitignore_file" ]; then
        touch "$gitignore_file"
    fi
    
    if ! grep -q "^\.git-account$" "$gitignore_file" 2>/dev/null; then
        echo ".git-account" >> "$gitignore_file"
        echo -e "${EMOJI_CHECK}${GREEN} Added .git-account to .gitignore${NC}"
    fi
}

# Repair (simple call)
repair_accounts_if_needed() {
    if [ ! -f "$ACCOUNTS_JSON" ] || [ ! -s "$ACCOUNTS_JSON" ] || [ "$(grep -c '"account":' "$ACCOUNTS_JSON")" -eq 0 ]; then
        echo -e "${EMOJI_WARN}${YELLOW} Repairing account registry...${NC}"
        local repair_script="$SCRIPT_DIR/../utils/repair_accounts.sh"
        if [ -f "$repair_script" ]; then
            bash "$repair_script"
        else
            echo -e "${EMOJI_ERROR}${RED} Repair script not found. Run setup_ssh_enhanced_v2.sh first.${NC}"
            exit 1
        fi
    fi
}

# Reliable TUI Selection (numbered, no arrows for broad compatibility)
enhanced_account_select() {
    local accounts=($(json_list_accounts))
    local choice
    local selected_account=""
    local i
    local num
    local email
    local found=false
    
    if [ ${#accounts[@]} -eq 0 ]; then
        echo ""
        return 1
    fi
    
    while [ -z "$selected_account" ]; do
        clear
        echo -e "\n${EMOJI_KEY} ${CYAN}Select GitHub Account:${NC}"
        echo -e "${YELLOW}Available accounts:${NC}"
        
        # Numbered menu
        for i in "${!accounts[@]}"; do
            num=$((i + 1))
            email=$(json_get_account_email "${accounts[$i]}")
            echo -e "${CYAN}${num}) ${accounts[$i]} (${email:-No email})${NC}"
        done
        
        echo -e "${YELLOW}\nEnter choice (number or account name):${NC}"
        read -r choice
        
        found=false
        # Check number
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -le ${#accounts[@]} ] && [ "$choice" -ge 1 ]; then
            i=$((choice - 1))
            selected_account="${accounts[$i]}"
            found=true
            echo -e "${GREEN}${EMOJI_CHECK} Selected: $selected_account${NC}"
        # Check name match
        else
            for i in "${!accounts[@]}"; do
                if [ "${accounts[$i]}" = "$choice" ]; then
                    selected_account="${accounts[$i]}"
                    found=true
                    echo -e "${GREEN}${EMOJI_CHECK} Selected: $selected_account${NC}"
                    break
                fi
            done
        fi
        
        if [ "$found" = false ]; then
            echo -e "${EMOJI_ERROR}${RED} Invalid selection. Try again.${NC}"
            sleep 1  # Brief pause
        fi
    done
    
    echo "$selected_account"
}

# Main script
echo -e "${CYAN}${EMOJI_ROCKET} Enhanced Repo Account Association v3.0${NC}"
echo -e "${WHITE}========================================${NC}\n"

# Parse args
REPO_DIR="${1:-$(pwd)}"
if [ ! -d "$REPO_DIR" ]; then
    echo -e "${EMOJI_ERROR}${RED} Directory not found: $REPO_DIR${NC}"
    exit 1
fi

cd "$REPO_DIR" || exit 1
echo -e "${EMOJI_REPO} Working in: $(pwd)"

# Repair accounts
repair_accounts_if_needed
accounts=($(json_list_accounts))

if [ ${#accounts[@]} -eq 0 ]; then
    echo -e "${EMOJI_ERROR}${RED} No accounts found. Run setup_ssh_enhanced_v2.sh first.${NC}"
    exit 1
fi

# Check if git repo
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo -e "${EMOJI_WARN}${YELLOW} Not a git repository. Initialize? (y/n)${NC}"
    read -r init_choice
    if [[ "$init_choice" =~ ^[Yy] ]]; then
        echo -n "Initializing git... "
        git init >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo -e "${EMOJI_CHECK}${GREEN} Success${NC}"
        else
            echo -e "${EMOJI_ERROR}${RED} Failed${NC}"
            exit 1
        fi
        echo -e "${EMOJI_CHECK}${GREEN} Git initialized.${NC}"
    else
        exit 1
    fi
fi

# Check existing .git-account
existing_file=$(find_git_account_file "$(pwd)")
selected_account=""
if [ -n "$existing_file" ]; then
    config=$(read_git_account_config "$existing_file")
    if [ -n "$config" ]; then
        IFS=':' read -r existing_alias _ _ _ _ _ <<< "$config"
        selected_account="$existing_alias"
        echo -e "${EMOJI_WARN}${YELLOW} Existing account: $selected_account. Overwrite? (y/n)${NC}"
        read -r overwrite_choice
        if [[ "$overwrite_choice" =~ ^[Nn] ]]; then
            echo -e "${EMOJI_CHECK}${GREEN} Keeping existing config.${NC}"
            verify_setup "$selected_account"
            exit 0
        fi
    fi
fi

# Select account
selected_account=$(enhanced_account_select)
if [ -z "$selected_account" ]; then
    echo -e "${EMOJI_ERROR}${RED} No account selected.${NC}"
    exit 1
fi

# Confirm
echo -e "${HIGHLIGHT} Associate '$selected_account' ($(json_get_account_email "$selected_account")) to $(pwd)? (y/n)${NC}"
read -r confirm
if [[ "$confirm" =~ ^[Yy] ]]; then
    :  # Proceed
else
    exit 1
fi

# Remote handling
remote_url=$(git remote get-url origin 2>/dev/null)
if [ -z "$remote_url" ]; then
    echo -e "${EMOJI_GIT} No remote origin. Enter URL (e.g., git@github.com:user/repo.git): "
    read -r remote_url
    # Basic validation
    if [[ ! "$remote_url" =~ ^(git@|git://|https?://) ]]; then
        echo -e "${EMOJI_ERROR}${RED} Invalid URL format. Skipping add.${NC}"
        remote_url=""
    else
        if [[ "$remote_url" =~ github\.com ]]; then
            account_clean=$(echo "$selected_account" | tr -cd '[:alnum:]_')
            remote_url=$(echo "$remote_url" | sed "s|github\.com\([:/]\)|github-$account_clean\1|")
            echo -e "${YELLOW} Suggested SSH: $remote_url${NC}"
        fi
        echo -n "Adding remote... "
        git remote add origin "$remote_url" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo -e "${EMOJI_CHECK}${GREEN} Success${NC}"
        else
            echo -e "${EMOJI_ERROR}${RED} Failed (may already exist)${NC}"
        fi
    fi
else
    echo -e "${EMOJI_GIT} Existing remote: $remote_url"
    # Optional: Update to use account alias
    echo -e "${YELLOW}Update remote to use account alias? (y/n) [n]:${NC}"
    read -r update_choice
    if [[ "$update_choice" =~ ^[Yy] ]]; then
        account_clean=$(echo "$selected_account" | tr -cd '[:alnum:]_')
        new_url=$(echo "$remote_url" | sed "s|github\.com\([:/]\)|github-$account_clean\1|")
        git remote set-url origin "$new_url"
        echo -e "${EMOJI_CHECK}${GREEN} Updated to: $new_url${NC}"
    fi
fi

# Write .git-account
git_name="$selected_account"  # Simple, can enhance
git_email=$(json_get_account_email "$selected_account")
ssh_key_path=$(json_get_ssh_key_path "$selected_account")
ssh_host_alias="github-$(echo "$selected_account" | tr -cd '[:alnum:]_')"
write_git_account_config "$selected_account" "$git_name" "$git_email" "$ssh_key_path" "$ssh_host_alias" "$remote_url" "$(pwd)/.git-account"

# Git config
git config user.name "$git_name"
git config user.email "$git_email"

# Gitignore
ensure_gitignore_has_git_account "$(pwd)"

# Verify
verify_setup "$selected_account"

echo -e "\n${EMOJI_PARTY}${GREEN} Association complete!${NC}"

# Verification function
verify_setup() {
    local account="$1"
    local account_clean=$(echo "$account" | tr -cd '[:alnum:]_')
    
    echo -e "\n${EMOJI_MAG} Verifying setup..."
    
    # SSH test (direct, reliable)
    echo -n "${EMOJI_MAG} Testing SSH... "
    if command -v timeout >/dev/null 2>&1; then
        output=$(timeout 20 ssh -T git@github-$account_clean 2>&1)
    else
        output=$(ssh -T git@github-$account_clean 2>&1)
    fi
    if echo "$output" | grep -q "successfully authenticated"; then
        echo -e "${EMOJI_CHECK}${GREEN} Success${NC}"
    else
        echo -e "${EMOJI_ERROR}${RED} Failed${NC}"
        echo -e "${YELLOW}Output: $output${NC}"
    fi
    
    # Fetch
    echo -n "${EMOJI_GIT} Fetching... "
    git fetch origin 2>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "${EMOJI_CHECK}${GREEN} Success${NC}"
    else
        echo -e "${EMOJI_WARN}${YELLOW} No changes or failed${NC}"
    fi
    
    # Log
    echo -e "${EMOJI_GIT} Recent commits:"
    git log --oneline -n5 2>/dev/null || echo "No commits yet."
    
    # Branches
    echo -e "\n${EMOJI_GIT} Branches:"
    git branch -a 2>/dev/null | sed 's/^[[:space:]]*//'
}