#!/bin/bash

# Enhanced GitHub SSH Setup v2.0 - macOS Compatible
# Features: No jq dependency, enhanced visuals, better verification feedback

GITHUB_DIR="$HOME/.ssh/github"
CONFIG="$GITHUB_DIR/config"
ACCOUNTS_JSON="$GITHUB_DIR/accounts.json"
DEFAULTS_JSON="$GITHUB_DIR/account_defaults.json"

# Color codes for better visuals
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Emoji constants
EMOJI_ROCKET="🚀"
EMOJI_KEY="🔑"
EMOJI_CHECK="✅"
EMOJI_WARN="⚠️"
EMOJI_ERROR="❌"
EMOJI_GITHUB="🐙"
EMOJI_CLIPBOARD="📋"
EMOJI_LOCK="🔒"
EMOJI_MAG="🔍"
EMOJI_COMPUTER="💻"
EMOJI_PARTY="🎉"
EMOJI_CLOCK="⏰"

# Spinner function for progress indication
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# JSON helper functions (jq-free)
json_add_account() {
    local account="$1"
    local email="$2"
    local priv_key="$3"
    local pub_key="$4"
    
    if [ ! -f "$ACCOUNTS_JSON" ] || [ ! -s "$ACCOUNTS_JSON" ]; then
        echo "[]" > "$ACCOUNTS_JSON"
    fi
    
    # Read existing content and add new account
    local existing_content=$(cat "$ACCOUNTS_JSON")
    local new_entry="{\"account\":\"$account\",\"email\":\"$email\",\"private_key\":\"$priv_key\",\"public_key\":\"$pub_key\",\"created_at\":\"$(date +%Y-%m-%d)\",\"last_used\":\"$(date +%Y-%m-%d)\"}"
    
    if [ "$existing_content" = "[]" ]; then
        echo "[$new_entry]" > "$ACCOUNTS_JSON"
    else
        echo "${existing_content%]}],$new_entry]}" > "$ACCOUNTS_JSON"
    fi
}

json_check_account() {
    local account="$1"
    if [ -f "$ACCOUNTS_JSON" ] && grep -q "\"account\":\"$account\"" "$ACCOUNTS_JSON"; then
        return 0
    else
        return 1
    fi
}

json_remove_account() {
    local account="$1"
    if [ -f "$ACCOUNTS_JSON" ]; then
        # Simple removal using sed
        sed -i.bak "/\"account\":\"$account\"/d" "$ACCOUNTS_JSON"
        # Clean up commas
        sed -i.bak 's/},}/}/g' "$ACCOUNTS_JSON"
        sed -i.bak 's/\[{/{/g' "$ACCOUNTS_JSON"
        sed -i.bak 's/}\]}/}/g' "$ACCOUNTS_JSON"
        rm -f "${ACCOUNTS_JSON}.bak"
    fi
}

json_list_accounts() {
    if [ -f "$ACCOUNTS_JSON" ]; then
        grep -o '"account":"[^"]*"' "$ACCOUNTS_JSON" | sed 's/"account":"\([^"]*\)"/\1/g'
    fi
}

# Print header
echo -e "${CYAN}${EMOJI_ROCKET} Enhanced GitHub SSH Setup v2.0${NC}"
echo -e "${WHITE}================================${NC}"
echo -e "${BLUE}This script will help you set up multiple GitHub accounts with SSH keys${NC}"
echo -e "${BLUE}No external dependencies required - works on macOS out of the box!${NC}\n"

# Initialize directories and files
echo -e "${EMOJI_COMPUTER} Initializing environment..."
mkdir -p "$GITHUB_DIR"
touch "$CONFIG"
[ -f "$ACCOUNTS_JSON" ] || echo "[]" > "$ACCOUNTS_JSON"
[ -f "$DEFAULTS_JSON" ] || echo '{"name":"","email":""}' > "$DEFAULTS_JSON"

# Check existing include with absolute path
MAIN_CONFIG="$HOME/.ssh/config"
if ! grep -q "Include ~/.ssh/github/config" "$MAIN_CONFIG" 2>/dev/null; then
    echo -e "${EMOJI_WARN} Adding SSH config include..."
    echo -e "\nInclude ~/.ssh/github/config" >> "$MAIN_CONFIG"
fi

# Account setup flow
echo -e "\n${EMOJI_CLIPBOARD} ${WHITE}Enter GitHub account aliases (comma-separated):${NC}"
echo -e "${YELLOW}Examples: work,personal,client1${NC}"
IFS=',' read -ra accounts <<< "$(read -r input; echo $input)"

for account in "${accounts[@]}"; do
    account=$(echo "$account" | xargs) # Trim whitespace
    account_clean=$(echo "$account" | tr -cd '[:alnum:]_')
    key_private="$GITHUB_DIR/github_$account_clean"
    key_public="$key_private.pub"
    
    echo -e "\n${EMOJI_GITHUB} Processing account: ${WHITE}$account${NC}"
    
    # Check existing registration
    if json_check_account "$account"; then
        echo -e "${EMOJI_WARN} Account '$account' already registered!"
        read -p "Overwrite/Skip/Abort? (o/s/a) [s] " choice
        case "${choice:-s}" in
            o|O)
                echo -e "${EMOJI_CLOCK} Removing existing registration..."
                json_remove_account "$account"
                rm -f "$key_private" "$key_public" 2>/dev/null
                ;;
            a|A)
                echo -e "${EMOJI_ERROR} Aborted by user"
                exit 1
                ;;
            *)
                echo -e "${EMOJI_WARN} Skipping duplicate account"
                continue
                ;;
        esac
    fi

    # Check SSH config conflicts
    if grep -q "^Host github-$account_clean" "$CONFIG" 2>/dev/null; then
        echo -e "${EMOJI_WARN} SSH config entry exists for github-$account_clean!"
        read -p "Replace existing? (y/n) [n] " choice
        if [[ "${choice:-n}" =~ ^[Yy] ]]; then
            sed -i.bak "/^Host github-$account_clean/,+3d" "$CONFIG"
            rm -f "${CONFIG}.bak"
        else
            echo -e "${EMOJI_WARN} Skipping SSH config update"
            continue
        fi
    fi
    
    if [ ! -f "$key_private" ]; then
        # Key generation with email validation
        while true; do
            echo -e "${EMOJI_LOCK} Enter GitHub email for '$account': "
            read -r email
            if [[ "$email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
                break
            else
                echo -e "${EMOJI_ERROR} Invalid email format! Must be valid email address"
            fi
        done
        
        echo -e "${EMOJI_KEY} Generating ED25519 SSH key..."
        ssh-keygen -t ed25519 -f "$key_private" -N '' -C "$email" >/dev/null 2>&1
        
        # Store account metadata
        json_add_account "$account" "$email" "$key_private" "$key_public"
        
        # SSH config
        echo -e "Host github-$account_clean\n  HostName github.com\n  User git\n  IdentityFile $key_private\n" >> "$CONFIG"
        
        # Enhanced GitHub setup workflow with visual emphasis
        echo -e "\n${PURPLE}╔══════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${PURPLE}║                ${EMOJI_GITHUB} GITHUB SSH KEY SETUP ${EMOJI_GITHUB}                          ║${NC}"
        echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════════╝${NC}\n"
        
        echo -e "${EMOJI_KEY}${YELLOW} SSH Key copied to clipboard! ${EMOJI_CLIPBOARD}${NC}"
        echo -e "${WHITE}Follow these steps EXACTLY:${NC}\n"
        
        echo -e "${EMOJI_GITHUB} ${CYAN}Step 1:${NC} ${WHITE}Open GitHub.com in your browser${NC}"
        echo -e "         ${YELLOW}(Browser will open automatically in 3 seconds)${NC}"
        
        echo -e "\n${EMOJI_GITHUB} ${CYAN}Step 2:${NC} ${WHITE}Go to Settings → SSH and GPG keys → New SSH key${NC}"
        
        echo -e "\n${EMOJI_GITHUB} ${CYAN}Step 3:${NC} ${WHITE}Paste the key below and give it a title:${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        cat "$key_public"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        echo -e "\n${EMOJI_GITHUB} ${CYAN}Step 4:${NC} ${WHITE}IMPORTANT: Log OUT of GitHub completely!${NC}"
        echo -e "         ${RED}This step is crucial for verification to work${NC}"
        
        # Copy to clipboard and open browser
        if command -v pbcopy >/dev/null 2>&1; then
            cat "$key_public" | pbcopy
            echo -e "\n${EMOJI_CHECK} Key copied to clipboard automatically!"
        else
            echo -e "\n${EMOJI_WARN} Please manually copy the key above"
        fi
        
        sleep 3
        open "https://github.com/settings/ssh/new" 2>/dev/null || echo -e "${EMOJI_WARN} Please manually navigate to GitHub SSH settings"
        
        echo -e "\n${EMOJI_CLOCK} Press Enter AFTER completing ALL 4 steps above..."
        read -r
        
        # Enhanced verification with timeout and visual feedback (simplified to match manual ssh -T)
        echo -e "\n${EMOJI_MAG} Testing SSH connection... ${YELLOW}(This may take up to 30 seconds)${NC}"
        
        timeout 30 ssh -T git@github-$account_clean >/dev/null 2>&1
        if [ $? -eq 1 ]; then  # ssh -T exits 1 on success (auth ok, but no shell)
            output=$(ssh -T git@github-$account_clean 2>&1)
            if echo "$output" | grep -q "successfully authenticated"; then
                echo -e "\n${EMOJI_CHECK}${GREEN} SUCCESS! SSH connection verified for $account${NC}"
                echo -e "${WHITE}You can now use: ${CYAN}git@github-$account_clean:${NC}your-repo.git"
            else
                echo -e "\n${EMOJI_ERROR}${RED} Verification failed for $account${NC}"
                echo -e "${YELLOW}Output: $output${NC}"
                echo -e "${YELLOW}Possible issues:${NC}"
                echo -e "  • Did you complete all 4 steps above?"
                echo -e "  • Did you log OUT of GitHub completely?"
                echo -e "  • Check if the key was added correctly in GitHub settings"
                echo -e "  • Try running: ${CYAN}ssh -T git@github-$account_clean${NC}"
            fi
        else
            echo -e "\n${EMOJI_ERROR}${RED} Connection timeout or error for $account${NC}"
            echo -e "${YELLOW}Try manual: ssh -T git@github-$account_clean${NC}"
        fi
    fi
done

echo -e "\n${EMOJI_PARTY}${GREEN} Setup complete! ${EMOJI_PARTY}${NC}"
echo -e "${WHITE}Restart your terminal or run: ${CYAN}source ~/.zshrc${NC} (or ~/.bashrc)"
echo -e "${WHITE}To add SSH keys to repos, use: ${CYAN}./create_repo_account.sh${NC}"
echo -e "${WHITE}To validate setup, run: ${CYAN}./utils/validate_setup.sh${NC}"
