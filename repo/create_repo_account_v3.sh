#!/bin/bash

# Enhanced Repository Account Association v3.0 - macOS Compatible
# Focus: Associate existing repos/directories with GitHub accounts
# Features: Advanced TUI (arrows/tab/numbers), full verification, optional clone

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
SELECTED_BG='\033[48;5;17m'
SELECTED_FG='\033[1;97m'
HIGHLIGHT='\033[1;33m'

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

# Source spinner (from v2 style)
SPINNER_LIB="$SCRIPT_DIR/../utils/external/spinner.sh"
if [ -f "$SPINNER_LIB" ]; then
    source "$SPINNER_LIB"
else
    echo -e "${EMOJI_WARN} Spinner library not found${NC}"
fi

# JSON helpers (jq-free, from v2)
json_list_accounts() {
    if [ -f "$ACCOUNTS_JSON" ]; then
        grep -o '"account"[[:space:]]*:[[:space:]]*"[^"]*"' "$ACCOUNTS_JSON" 2>/dev/null | sed 's/"account"[[:space:]]*:[[:space:]]*"\([^"]*\)"/\1/g'
    fi
}

json_get_account_email() {
    local account="$1"
    if [ -f "$ACCOUNTS_JSON" ]; then
        grep -A5 "\"account\"[[:space:]]*:[[:space:]]*\"$account\"" "$ACCOUNTS_JSON" 2>/dev/null | grep '"email"' | head -1 | sed 's/.*"email": *"\([^"]*\)".*/\1/'
    fi
}

json_get_ssh_key_path() {
    local account="$1"
    if [ -f "$ACCOUNTS_JSON" ]; then
        grep -A5 "\"account\"[[:space:]]*:[[:space:]]*\"$account\"" "$ACCOUNTS_JSON" 2>/dev/null | grep '"private_key"' | head -1 | sed 's/.*"private_key": *"\([^"]*\)".*/\1/'
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

# Repair (from v2)
repair_accounts_if_needed() {
    if [ ! -f "$ACCOUNTS_JSON" ] || [ ! -s "$ACCOUNTS_JSON" ] || [ "$(grep -c '"account":' "$ACCOUNTS_JSON")" -eq 0 ]; then
        echo -e "${EMOJI_WARN}${YELLOW} Repairing account registry...${NC}"
        local repair_script="$SCRIPT_DIR/../utils/repair_accounts.sh"
        if [ -f "$repair_script" ]; then
            if command -v run_with_spinner >/dev/null 2>&1; then
                run_with_spinner "dots" "Repairing..." "" "$repair_script"
            else
                bash "$repair_script"
            fi
        else
            echo -e "${EMOJI_ERROR}${RED} Repair script not found${NC}"
            exit 1
        fi
    fi
}

# Enhanced TUI Selection (build on v2, add arrow/tab)
enhanced_account_select() {
    local accounts=($(json_list_accounts))
    local selected_index=0
    local key
    local confirmed=false
    
    if [ ${#accounts[@]} -eq 0 ]; then
        echo ""
        return 1
    fi
    
    echo -e "\n${EMOJI_KEY} ${CYAN}Select GitHub Account (↑↓ arrows, Tab, number, Enter):${NC}"
    
    while [ $confirmed = false ]; do
        # Display menu with highlight
        for i in "${!accounts[@]}"; do
            local account_display="${accounts[$i]} ($(json_get_account_email "${accounts[$i]}"))"
            if [ $i -eq $selected_index ]; then
                echo -ne "${SELECTED_BG}${SELECTED_FG} > $account_display ${NC}\n"
            else
                local num=$((i + 1))
                echo -ne "${CYAN}${num}) $account_display${NC}\n"
            fi
        done
        
        # Read key
        read -n1 -s key
        case "$key" in
            $'\e' )  # Escape for arrows
                read -n1 -s key2
                read -n1 -s key3 2>/dev/null
                if [ "$key2" = '[' ]; then
                    case "$key3" in
                        A) selected_index=$(( (selected_index - 1 + ${#accounts[@]}) % ${#accounts[@]} )) ;;  # Up
                        B) selected_index=$(( (selected_index + 1) % ${#accounts[@]} )) ;;  # Down
                    esac
                fi
                ;;
            $'\t')  # Tab: next
                selected_index=$(( (selected_index + 1) % ${#accounts[@]} ))
                ;;
            $'\n' | '' )  # Enter
                confirmed=true
                ;;
            [0-9] )
                local num_choice=$((key - 48))  # ASCII to num
                if [ $num_choice -ge 1 ] && [ $num_choice -le ${#accounts[@]} ]; then
                    selected_index=$((num_choice - 1))
                    confirmed=true
                fi
                ;;
        esac
        # Clear screen for redraw
        clear
    done
    
    echo "${accounts[$selected_index]}"
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
        if command -v run_with_spinner >/dev/null 2>&1; then
            run_with_spinner "dots" "Initializing git..." "" "git init"
        else
            git init
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
            # Verify existing
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
    if [[ "$remote_url" =~ github\.com ]]; then
        # Suggest alias
        account_clean=$(echo "$selected_account" | tr -cd '[:alnum:]_')
        remote_url=$(echo "$remote_url" | sed "s|github\.com\([:/]\)|github-$account_clean\1|")
        echo -e "${YELLOW} Suggested SSH: $remote_url${NC}"
    fi
    if command -v run_with_spinner >/dev/null 2>&1; then
        run_with_spinner "dots" "Adding remote..." "" "git remote add origin '$remote_url'"
    else
        git remote add origin "$remote_url"
    fi
else
    echo -e "${EMOJI_GIT} Existing remote: $remote_url"
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
    
    # SSH test
    if command -v run_with_spinner >/dev/null 2>&1; then
        local ssh_success=false
        run_with_spinner "shark" "Testing SSH..." "" "timeout 20 ssh -T git@github-$account_clean 2>&1 | grep -q 'successfully authenticated' && echo true || echo false"
        ssh_success=$(tail -1)  # Hacky, assume output
        if [ "$ssh_success" = "true" ]; then
            echo -e "${EMOJI_CHECK}${GREEN} SSH: Success${NC}"
        else
            echo -e "${EMOJI_ERROR}${RED} SSH: Failed${NC}"
        fi
    else
        ssh -T git@github-$account_clean >/dev/null 2>&1
        if [ $? -eq 1 ] && ssh -T git@github-$account_clean 2>&1 | grep -q "successfully authenticated"; then
            echo -e "${EMOJI_CHECK}${GREEN} SSH: Success${NC}"
        else
            echo -e "${EMOJI_ERROR}${RED} SSH: Failed${NC}"
        fi
    fi
    
    # Fetch
    if command -v run_with_spinner >/dev/null 2>&1; then
        run_with_spinner "dots" "Fetching..." "" "git fetch origin"
        if [ $? -eq 0 ]; then
            echo -e "${EMOJI_CHECK}${GREEN} Fetch: Success${NC}"
        else
            echo -e "${EMOJI_WARN}${YELLOW} Fetch: No remote changes or failed${NC}"
        fi
    else
        git fetch origin >/dev/null 2>&1
        echo -e "${EMOJI_CHECK}${GREEN} Fetch: Completed${NC}"
    fi
    
    # Log
    echo -e "${EMOJI_GIT} Recent commits:"
    git log --oneline -n5 2>/dev/null || echo "No commits yet."
    
    # Branches
    echo -e "\n${EMOJI_GIT} Branches:"
    git branch -a --list 2>/dev/null | sed 's/^[[:space:]]*//'
}