#!/bin/bash

# Enhanced Validation Script v2.0 - macOS Compatible
# Features: No jq dependency, enhanced visuals, comprehensive validation

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

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
EMOJI_STAR="⭐"
EMOJI_MAG="🔍"
EMOJI_COMPUTER="💻"

# JSON helper function (jq-free)
json_list_accounts() {
    if [ -f "$HOME/.ssh/github/accounts.json" ]; then
        grep -o '"account":"[^"]*"' "$HOME/.ssh/github/accounts.json" 2>/dev/null | sed 's/"account":"\([^"]*\)"/\1/g'
    fi
}

json_get_account_email() {
    local account="$1"
    if [ -f "$HOME/.ssh/github/accounts.json" ]; then
        grep -A5 "\"account\":\"$account\"" "$HOME/.ssh/github/accounts.json" 2>/dev/null | grep '"email"' | head -1 | sed 's/.*"email":"\([^"]*\)".*/\1/'
    fi
}

json_get_account_keys() {
    local account="$1"
    if [ -f "$HOME/.ssh/github/accounts.json" ]; then
        local account_block=$(grep -A10 "\"account\":\"$account\"" "$HOME/.ssh/github/accounts.json" 2>/dev/null)
        local private_key=$(echo "$account_block" | grep '"private_key"' | sed 's/.*"private_key":"\([^"]*\)".*/\1/')
        local public_key=$(echo "$account_block" | grep '"public_key"' | sed 's/.*"public_key":"\([^"]*\)".*/\1/')
        echo "$private_key $public_key"
    fi
}

# Print header
echo -e "\n${CYAN}${EMOJI_MAG} Enhanced SSH Setup Validation v2.0 ${EMOJI_COMPUTER}${NC}"
echo -e "${WHITE}=======================================${NC}\n"

# Check if setup directory exists
if [ ! -d "$HOME/.ssh/github" ]; then
    echo -e "${EMOJI_ERROR}${RED} GitHub SSH directory not found!${NC}"
    echo -e "${YELLOW}Please run the setup script first.${NC}"
    exit 1
fi

# Check SSH config include
echo -e "${EMOJI_GITHUB} Checking SSH configuration..."
MAIN_CONFIG="$HOME/.ssh/config"
if grep -q "Include ~/.ssh/github/config" "$MAIN_CONFIG" 2>/dev/null; then
    echo -e "  ${EMOJI_CHECK} SSH config include found"
else
    echo -e "  ${EMOJI_ERROR} SSH config include missing"
    echo -e "    ${EMOJI_ARROW} Run: echo 'Include ~/.ssh/github/config' >> ~/.ssh/config"
fi

# Check GitHub config file
GITHUB_CONFIG="$HOME/.ssh/github/config"
if [ -f "$GITHUB_CONFIG" ]; then
    echo -e "\n${EMOJI_KEY} SSH Host Configurations:"
    while read -r line; do
        if [[ "$line" =~ ^Host[[:space:]] ]]; then
            host=$(echo "$line" | awk '{print $2}')
            echo -e "  ${EMOJI_CHECK} $host"
        fi
    done < "$GITHUB_CONFIG"
else
    echo -e "  ${EMOJI_ERROR} GitHub config file not found"
fi

# Check accounts registry
ACCOUNTS_JSON="$HOME/.ssh/github/accounts.json"
if [ -f "$ACCOUNTS_JSON" ]; then
    echo -e "\n${EMOJI_REPO} Registered Accounts:"
    accounts=$(json_list_accounts)
    if [ -n "$accounts" ]; then
        echo "$accounts" | while read -r account; do
            if [ -n "$account" ]; then
                email=$(json_get_account_email "$account")
                keys=$(json_get_account_keys "$account")
                key_files=($keys)
                private_key="${key_files[0]}"
                public_key="${key_files[1]}"
                
                echo -e "  ${EMOJI_CHECK} $account"
                echo -e "    ${EMOJI_ARROW} Email: $email"
                
                # Check if key files exist
                if [ -f "$private_key" ]; then
                    echo -e "    ${EMOJI_CHECK} Private key: $(basename "$private_key")"
                else
                    echo -e "    ${EMOJI_ERROR} Private key missing: $(basename "$private_key")"
                fi
                
                if [ -f "$public_key" ]; then
                    echo -e "    ${EMOJI_CHECK} Public key: $(basename "$public_key")"
                else
                    echo -e "    ${EMOJI_ERROR} Public key missing: $(basename "$public_key")"
                fi
            fi
        done
    else
        echo -e "  ${EMOJI_ERROR} No accounts found in registry"
    fi
else
    echo -e "  ${EMOJI_ERROR} Accounts registry not found"
fi

# Check SSH key permissions
echo -e "\n${EMOJI_KEY} SSH Key Permissions Check:"
if [ -d "$HOME/.ssh/github" ]; then
    find "$HOME/.ssh/github" -name "github_*" -type f | while read -r key_file; do
        if [[ "$key_file" =~ \.pub$ ]]; then
            # Public key should be readable by all
            if [ -r "$key_file" ]; then
                echo -e "  ${EMOJI_CHECK} $(basename "$key_file") - permissions OK"
            else
                echo -e "  ${EMOJI_WARN} $(basename "$key_file") - not readable"
            fi
        else
            # Private key should be 600
            perms=$(stat -f "%A" "$key_file" 2>/dev/null || stat -c "%a" "$key_file" 2>/dev/null)
            if [ "$perms" = "600" ]; then
                echo -e "  ${EMOJI_CHECK} $(basename "$key_file") - permissions 600 ✓"
            else
                echo -e "  ${EMOJI_ERROR} $(basename "$key_file") - permissions $perms (should be 600)"
                echo -e "    ${EMOJI_ARROW} Fix with: chmod 600 \"$key_file\""
            fi
        fi
    done
fi

# Connection tests
echo -e "\n${EMOJI_GITHUB} SSH Connection Tests:"
accounts=$(json_list_accounts)
if [ -n "$accounts" ]; then
    echo "$accounts" | while read -r account; do
        if [ -n "$account" ]; then
            account_clean=$(echo "$account" | tr -cd '[:alnum:]_')
            echo -n "  $account: "
            
            # Test SSH connection with timeout
            if timeout 15 ssh -T git@github-"$account_clean" 2>&1 | grep -q "successfully authenticated"; then
                echo -e "${EMOJI_CHECK}${GREEN} SUCCESS${NC}"
            else
                echo -e "${EMOJI_ERROR}${RED} FAILED${NC}"
                echo -e "    ${EMOJI_ARROW} Try: ssh -T git@github-$account_clean"
            fi
        fi
    done
else
    echo -e "  ${EMOJI_ERROR} No accounts to test"
fi

# Git configuration check
echo -e "\n${EMOJI_GIT} Global Git Configuration:"
if command -v git >/dev/null 2>&1; then
    git_user=$(git config --global user.name 2>/dev/null)
    git_email=$(git config --global user.email 2>/dev/null)
    
    if [ -n "$git_user" ]; then
        echo -e "  ${EMOJI_CHECK} Global user.name: $git_user"
    else
        echo -e "  ${EMOJI_WARN} Global user.name not set"
    fi
    
    if [ -n "$git_email" ]; then
        echo -e "  ${EMOJI_CHECK} Global user.email: $git_email"
    else
        echo -e "  ${EMOJI_WARN} Global user.email not set"
    fi
else
    echo -e "  ${EMOJI_ERROR} Git not installed"
fi

# System recommendations
echo -e "\n${EMOJI_STAR} System Status Summary:"
total_accounts=$(echo "$accounts" | wc -l | tr -d ' ')
working_connections=0

if [ -n "$accounts" ]; then
    echo "$accounts" | while read -r account; do
        if [ -n "$account" ]; then
            account_clean=$(echo "$account" | tr -cd '[:alnum:]_')
            if timeout 10 ssh -T git@github-"$account_clean" 2>&1 | grep -q "successfully authenticated"; then
                ((working_connections++))
            fi
        fi
    done
fi

if [ "$working_connections" -eq "$total_accounts" ] && [ "$total_accounts" -gt 0 ]; then
    echo -e "  ${EMOJI_PARTY}${GREEN} All systems operational! ${EMOJI_PARTY}${NC}"
elif [ "$working_connections" -gt 0 ]; then
    echo -e "  ${EMOJI_WARN}${YELLOW} Partial setup working ($working_connections/$total_accounts)${NC}"
else
    echo -e "  ${EMOJI_ERROR}${RED} Setup issues detected${NC}"
fi

# Final recommendations
echo -e "\n${EMOJI_COMPUTER} Quick Commands:"
echo -e "  ${EMOJI_ARROW} Add new account: ./setup/setup_ssh_enhanced_v0.3.sh"
echo -e "  ${EMOJI_ARROW} Setup repository: ./repo/create_repo_account_v2.sh"
echo -e "  ${EMOJI_ARROW} Test connection: ssh -T git@github-<account>"
echo -e "\n${EMOJI_CLOCK} For help, check the README.md file"

echo -e "\n${EMOJI_PARTY}${GREEN} Validation complete! ${EMOJI_PARTY}${NC}\n"
