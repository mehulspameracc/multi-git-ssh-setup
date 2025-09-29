
#!/bin/bash

# Enhanced Repository Account Setup v2.1 - macOS Compatible
# Features: Account repair, interactive selection, spinner animations

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Enhanced colors for better UI
BOLD='\033[1m'
DIM='\033[2m'
UNDERLINE='\033[4m'
REVERSE='\033[7m'

# Background colors
BG_RED='\033[41m'
BG_GREEN='\033[42m'
BG_YELLOW='\033[43m'
BG_BLUE='\033[44m'
BG_PURPLE='\033[45m'
BG_CYAN='\033[46m'
BG_WHITE='\033[47m'

# Enhanced colors for selected items
SELECTED_BG='\033[48;5;17m'  # Dark blue background
SELECTED_FG='\033[1;97m'     # Bright white text
HIGHLIGHT='\033[1;33m'       # Bright yellow for highlights

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
EMOJI_REPAIR="🔧"

# Source spinner library with robust path handling
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Try absolute path first
ABS_SPINNER_LIB="$SCRIPT_DIR/../utils/external/spinner.sh"

# Fallback to relative path
if [ ! -f "$ABS_SPINNER_LIB" ]; then
    ABS_SPINNER_LIB="./utils/external/spinner.sh"
fi

if [ -f "$ABS_SPINNER_LIB" ]; then
    source "$ABS_SPINNER_LIB"
else
    echo -e "${EMOJI_WARN} Spinner library not found at:"
    echo -e "  $ABS_SPINNER_LIB"
    echo -e "${YELLOW}Continuing without spinner animations${NC}"
fi

# JSON helper function (jq-free)
json_list_accounts() {
    if [ -f "$HOME/.ssh/github/accounts.json" ]; then
        grep -o '"account"[[:space:]]*:[[:space:]]*"[^"]*"' "$HOME/.ssh/github/accounts.json" 2>/dev/null | sed 's/"account"[[:space:]]*:[[:space:]]*"\([^"]*\)"/\1/g'
    fi
}

json_get_account_email() {
    local account="$1"
    if [ -f "$HOME/.ssh/github/accounts.json" ]; then
        grep -A5 "\"account\"[[:space:]]*:[[:space:]]*\"$account\"" "$HOME/.ssh/github/accounts.json" 2>/dev/null | grep '"email"' | head -1 | sed 's/.*"email": *"\([^"]*\)".*/\1/'
    fi
}

# .git-account file management functions
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
        # Source the file to extract variables
        source "$git_account_file"
        echo "$ACCOUNT_ALIAS:$GIT_NAME:$GIT_EMAIL:$SSH_KEY_PATH:$SSH_HOST_ALIAS"
    fi
}

write_git_account_config() {
    local account_alias="$1"
    local git_name="$2"
    local git_email="$3"
    local ssh_key_path="$4"
    local ssh_host_alias="$5"
    local output_file="$6"
    
    cat > "$output_file" << EOF
# GitHub Account Configuration
# This file associates this repository with a specific GitHub account

ACCOUNT_ALIAS="$account_alias"
GIT_NAME="$git_name"
GIT_EMAIL="$git_email"
SSH_KEY_PATH="$ssh_key_path"
SSH_HOST_ALIAS="$ssh_host_alias"

# Generated on: $(date '+%Y-%m-%d')
# Last updated: $(date '+%Y-%m-%d')
EOF
}

# .gitignore management functions
ensure_gitignore_has_git_account() {
    local gitignore_file="$1/.gitignore"
    
    # Check if .gitignore exists, create if not
    if [ ! -f "$gitignore_file" ]; then
        touch "$gitignore_file"
    fi
    
    # Check if .git-account is already in .gitignore
    if ! grep -q "^\.git-account$" "$gitignore_file" 2>/dev/null; then
        echo ".git-account" >> "$gitignore_file"
        echo -e "${EMOJI_CHECK}${GREEN} Added .git-account to .gitignore${NC}"
    fi
}

auto_select_account() {
    local git_account_file
    git_account_file=$(find_git_account_file "$(pwd)")
    
    if [ -n "$git_account_file" ]; then
        local config
        config=$(read_git_account_config "$git_account_file")
        if [ -n "$config" ]; then
            IFS=':' read -r account_alias git_name git_email ssh_key_path ssh_host_alias <<< "$config"
            echo "$account_alias"
            return 0
        fi
    fi
    
    return 1
}

switch_account() {
    local current_account="$1"
    local accounts=("${@:2}")
    
    echo -e "\n${EMOJI_KEY} Current account: ${WHITE}$current_account${NC}"
    echo -e "${EMOJI_KEY} Switch to a different account:"
    
    # Create menu of available accounts (excluding current)
    local menu_options=()
    local account_count=0
    for account in "${accounts[@]}"; do
        if [ "$account" != "$current_account" ]; then
            menu_options+=("$account")
            echo -e "  ${EMOJI_ARROW} $account"
            ((account_count++))
        fi
    done
    
    if [ $account_count -eq 0 ]; then
        echo -e "${EMOJI_WARN} No other accounts available to switch to${NC}"
        return 1
    fi
    
    echo -e "\n${EMOJI_KEY} Enter account to switch to (or press Enter to cancel):"
    read -r new_account
    
    if [ -n "$new_account" ] && printf '%s\n' "${menu_options[@]}" | grep -q "^$new_account$"; then
        # Update .git-account file with new account
        local git_account_file
        git_account_file=$(find_git_account_file "$(pwd)")
        
        if [ -n "$git_account_file" ]; then
            local git_name
            local git_email
            local ssh_key_path
            local ssh_host_alias
            
            git_name=$(json_get_account_name "$new_account")
            git_email=$(json_get_account_email "$new_account")
            ssh_key_path=$(json_get_ssh_key_path "$new_account")
            ssh_host_alias=$(json_get_ssh_host_alias "$new_account")
            
            write_git_account_config "$new_account" "$git_name" "$git_email" "$ssh_key_path" "$ssh_host_alias" "$git_account_file"
            
            echo -e "${EMOJI_CHECK}${GREEN} Account switched to: $new_account${NC}"
            echo -e "${EMOJI_CHECK}${GREEN} .git-account file updated${NC}"
            echo "$new_account"
            return 0
        fi
    fi
    
    echo -e "${EMOJI_WARN} Account switch cancelled${NC}"
    return 1
}

# Helper functions to get account details
json_get_account_name() {
    local account="$1"
    echo "$account"  # For now, use account alias as name
}

json_get_ssh_key_path() {
    local account="$1"
    if [ -f "$HOME/.ssh/github/accounts.json" ]; then
        grep -A5 "\"account\"[[:space:]]*:[[:space:]]*\"$account\"" "$HOME/.ssh/github/accounts.json" 2>/dev/null | grep '"private_key"' | head -1 | sed 's/.*"private_key": *"\([^"]*\)".*/\1/'
    fi
}

json_get_ssh_host_alias() {
    local account="$1"
    local account_clean=$(echo "$account" | tr -cd '[:alnum:]_')
    echo "github-$account_clean"
}

# Repair accounts if needed
repair_accounts_if_needed() {
    ACCOUNTS_JSON="$HOME/.ssh/github/accounts.json"
    
    # Check if accounts.json exists and has content
    if [ ! -f "$ACCOUNTS_JSON" ] || [ ! -s "$ACCOUNTS_JSON" ] || [ "$(grep -c '"account":' "$ACCOUNTS_JSON")" -eq 0 ]; then
        echo -e "${EMOJI_REPAIR}${YELLOW} Account registry missing or empty. Repairing...${NC}"
        REPAIR_SCRIPT="$SCRIPT_DIR/../utils/repair_accounts.sh"
        
        if [ -f "$REPAIR_SCRIPT" ]; then
            chmod +x "$REPAIR_SCRIPT" 2>/dev/null
            # Run repair with green star2 spinner
            SPINNER_STYLE="star2"
            run_with_spinner "Repairing account registry" \
                -s "$SPINNER_STYLE" \
                -c "\033[1;32m" \
                -- "$REPAIR_SCRIPT"
        else
            echo -e "${EMOJI_ERROR}${RED} Repair script not found!${NC}"
            echo -e "${YELLOW}Please run the setup script again.${NC}"
            exit 1
        fi
    fi
}

# Interactive account selection with simplified UI/UX
interactive_account_select() {
    accounts=($(json_list_accounts))
    
    if [ ${#accounts[@]} -eq 0 ]; then
        return ""
    fi
    
    echo -e "\n${EMOJI_KEY} ${CYAN}Select GitHub Account:${NC}"
    echo -e "${YELLOW}Available accounts:${NC}"
    
    # Simple numbered menu
    for i in "${!accounts[@]}"; do
        account_num=$((i + 1))
        echo -e "${CYAN}${account_num}) ${accounts[$i]}${NC}"
    done
    
    echo -e "${YELLOW}\n> Enter your choice (number or account name):${NC}"
    read -r choice
    
    # Check if it's a number
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -le ${#accounts[@]} ] && [ "$choice" -gt 0 ]; then
        selected_index=$((choice - 1))
        echo -e "${GREEN}✅ Selected: ${accounts[$selected_index]}${NC}"
        echo ${accounts[$selected_index]}
    else
        # Check if it matches an account name
        for account in "${accounts[@]}"; do
            if [ "$account" = "$choice" ]; then
                echo -e "${GREEN}✅ Selected: $account${NC}"
                echo "$account"
                return 0
            fi
        done
        
        # If no match, show error and ask again
        echo -e "${EMOJI_ERROR}${RED} Invalid selection. Please try again.${NC}"
        
        # Add a safety check to prevent infinite recursion
        if [ ${BASH_SUBSHELL} -gt 10 ]; then
            echo -e "${RED}ERROR: Maximum recursion depth reached${NC}"
            return ""
        fi
        
        interactive_account_select
    fi
}

# Print header
echo -e "${CYAN}${EMOJI_REPO} Enhanced Repository Account Setup v2.1${NC}"
echo -e "${WHITE}=======================================${NC}\n"

# Check if setup directory exists
if [ ! -d "$HOME/.ssh/github" ]; then
    echo -e "${EMOJI_ERROR}${RED} GitHub SSH directory not found!${NC}"
    echo -e "${YELLOW}Please run the setup script first.${NC}"
    exit 1
fi

# Repair accounts if needed and reload
repair_accounts_if_needed
accounts=($(json_list_accounts))

# Verify accounts exist
if [ ${#accounts[@]} -eq 0 ]; then
    echo -e "${EMOJI_ERROR}${RED} No accounts found after repair!${NC}"
    echo -e "${YELLOW}Running manual repair...${NC}"
    
    # Check if repair script exists
    if [ -f "$SCRIPT_DIR/../utils/repair_accounts.sh" ]; then
        echo -e "${GREEN}Repair script found!${NC}"
        "$SCRIPT_DIR/../utils/repair_accounts.sh"
    else
        echo -e "${RED}Repair script NOT found!${NC}"
        exit 1
    fi
    
    accounts=($(json_list_accounts))
    
    if [ ${#accounts[@]} -eq 0 ]; then
        echo -e "${EMOJI_ERROR}${RED} Still no accounts found!${NC}"
        echo -e "${YELLOW}Please check your SSH key directory: $HOME/.ssh/github${NC}"
        exit 1
    fi
fi

# Get repository URL
echo -e "\n${EMOJI_REPO} Enter the repository URL or path:"
echo -e "${YELLOW}Examples:${NC}"
echo -e "  ${EMOJI_ARROW} https://github.com/username/repo.git"
echo -e "  ${EMOJI_ARROW} git@github.com:username/repo.git"
echo -e "  ${EMOJI_ARROW} /path/to/existing/repo (local path)"
echo -e "${YELLOW}\nRepository URL/Path:${NC}"
read -r repo_input

# Determine if it's a local path or URL and set up repository
if [ -d "$repo_input" ]; then
    # Local repository
    repo_path="$repo_input"
    echo -e "\n${EMOJI_REPO} Using local repository: $repo_path"
    
    # Check if it's already a git repository
    if [ -d "$repo_path/.git" ]; then
        echo -e "${EMOJI_CHECK} Repository already initialized"
    else
        start_spinner "Initializing git repository"
        cd "$repo_path" || exit 1
        git init >/dev/null 2>&1
        stop_spinner $?
    fi
    
    cd "$repo_path" || exit 1
else
    # Remote repository - clone it
    # First, let the user select an account for cloning
    echo -e "${EMOJI_GITHUB} Available GitHub accounts:"
    for account in "${accounts[@]}"; do
        echo -e "  ${EMOJI_CHECK} $account"
    done
    
    echo -e "\n${EMOJI_KEY} Select account for cloning (use arrow keys, press Enter to select):"
    selected_account=$(interactive_account_select)
    if [ -z "$selected_account" ]; then
        echo -e "${EMOJI_WARN} Manual account entry"
        echo -e "\n${EMOJI_KEY} Enter account alias:"
        read -r selected_account
    fi
    
    # Validate account
    if ! printf '%s\n' "${accounts[@]}" | grep -q "^$selected_account$"; then
        echo -e "${EMOJI_ERROR}${RED} Invalid account: $selected_account${NC}"
        exit 1
    fi
    
    # Convert GitHub URL to use the SSH alias
    if [[ "$repo_input" =~ github\.com ]]; then
        # Extract username/repo from GitHub URL
        repo_path=$(echo "$repo_input" | sed 's/.*github\.com[\/:]\([^\/]*\/[^\/]*\)\.git.*/\1/')
        account_clean=$(echo "$selected_account" | tr -cd '[:alnum:]_')
        modified_url="git@github-$account_clean:$repo_path.git"
        echo -e "\n${EMOJI_KEY} Using SSH alias: $modified_url"
    else
        modified_url="$repo_input"
    fi
    
    # Clone the repository
    start_spinner "Cloning repository"
    git clone "$modified_url" repo_temp 2>/dev/null
    if [ $? -eq 0 ]; then
        stop_spinner 0
        repo_path="repo_temp"
        cd "$repo_path" || exit 1
    else
        stop_spinner 1
        echo -e "${EMOJI_ERROR}${RED} Failed to clone repository!${NC}"
        echo -e "${YELLOW}URL: $modified_url${NC}"
        exit 1
    fi
fi

# Now we're in the repository directory, check for existing .git-account file
selected_account=$(auto_select_account)

if [ -n "$selected_account" ]; then
    echo -e "${EMOJI_CHECK}${GREEN} Found existing .git-account file with account: $selected_account${NC}"
    
    # Ask if user wants to switch accounts
    echo -e "\n${EMOJI_KEY} Options:"
    echo -e "  ${EMOJI_ARROW} 1) Use current account: $selected_account"
    echo -e "  ${EMOJI_ARROW} 2) Switch to a different account"
    echo -e "  ${EMOJI_ARROW} 3) Remove .git-account and start fresh"
    echo -e "\n${EMOJI_KEY} Enter your choice (1-3) [1]:"
    read -r choice
    
    case "${choice:-1}" in
        1)
            echo -e "${EMOJI_CHECK} Using existing account: $selected_account${NC}"
            ;;
        2)
            selected_account=$(switch_account "$selected_account" "${accounts[@]}")
            if [ $? -ne 0 ]; then
                echo -e "${EMOJI_WARN} Using original account: $selected_account${NC}"
            fi
            ;;
        3)
            echo -e "${EMOJI_WARN} Removing .git-account file...${NC}"
            rm -f "$(pwd)/.git-account"
            selected_account=""
            ;;
        *)
            echo -e "${EMOJI_ERROR}${RED} Invalid choice${NC}"
            exit 1
            ;;
    esac
fi

# If no .git-account file found or user chose to start fresh, show manual selection
if [ -z "$selected_account" ]; then
    echo -e "${EMOJI_GITHUB} Available GitHub accounts:"
    for account in "${accounts[@]}"; do
        echo -e "  ${EMOJI_CHECK} $account"
    done

    # Account selection
    echo -e "${YELLOW}\n> Please select an account from the list above:${NC}"
    selected_account=$(interactive_account_select)
    
    if [ -z "$selected_account" ]; then
        echo -e "${EMOJI_WARN} Manual account entry"
        echo -e "\n${EMOJI_KEY} Enter account alias:"
        read -r selected_account
    fi

    # Validate account
    if ! printf '%s\n' "${accounts[@]}" | grep -q "^$selected_account$"; then
        echo -e "${EMOJI_ERROR}${RED} Invalid account: $selected_account${NC}"
        exit 1
    fi
    
    # Create .git-account file after successful selection
    local git_name
    local git_email
    local ssh_key_path
    local ssh_host_alias
    
    git_name=$(json_get_account_name "$selected_account")
    git_email=$(json_get_account_email "$selected_account")
    ssh_key_path=$(json_get_ssh_key_path "$selected_account")
    ssh_host_alias=$(json_get_ssh_host_alias "$selected_account")
    
    echo -e "${YELLOW}Creating .git-account file in: $(pwd)${NC}"
    echo -e "${YELLOW}Account details: $selected_account, $git_email, $ssh_key_path${NC}"
    
    # Ensure the directory exists
    mkdir -p "$(pwd)"
    
    # Write the config file
    write_git_account_config "$selected_account" "$git_name" "$git_email" "$ssh_key_path" "$ssh_host_alias" "$(pwd)/.git-account"
    
    # Verify the file was created
    if [ -f "$(pwd)/.git-account" ]; then
        echo -e "${EMOJI_CHECK}${GREEN} Successfully created .git-account file for account: $selected_account${NC}"
        echo -e "${GREEN}File location: $(pwd)/.git-account${NC}"
        # Add .git-account to .gitignore
        ensure_gitignore_has_git_account "$(pwd)"
    else
        echo -e "${EMOJI_ERROR}${RED} Failed to create .git-account file${NC}"
        echo -e "${YELLOW}Current directory: $(pwd)${NC}"
        echo -e "${YELLOW}Directory exists: $(test -d "$(pwd)" && echo "Yes" || echo "No")${NC}"
        echo -e "${YELLOW}Write permissions: $(test -w "$(pwd)" && echo "Yes" || echo "No")${NC}"
        exit 1
    fi
fi

# Configure git for the selected account
echo -e "\n${EMOJI_GIT} Configuring git for account: $selected_account"
account_email=$(json_get_account_email "$selected_account")
if [ -n "$account_email" ]; then
    git config user.name "$selected_account"
    git config user.email "$account_email"
    echo -e "${EMOJI_CHECK} Git configured with:"
    echo -e "  ${EMOJI_ARROW} Name: $selected_account"
    echo -e "  ${EMOJI_ARROW} Email: $account_email"
else
    echo -e "${EMOJI_ERROR}${RED} Could not find email for account: $selected_account${NC}"
    echo -e "${YELLOW}Please check your accounts.json file${NC}"
    exit 1
fi

# Set up remote origin if not already set
if [ -z "$(git config --get remote.origin.url)" ]; then
    if [[ "$repo_input" =~ github\.com ]]; then
        # Extract username/repo from original URL
        repo_path=$(echo "$repo_input" | sed 's/.*github\.com[\/:]\([^\/]*\/[^\/]*\)\.git.*/\1/')
        account_clean=$(echo "$selected_account" | tr -cd '[:alnum:]_')
        git remote add origin "git@github-$account_clean:$repo_path.git"
        echo -e "${EMOJI_CHECK} Remote origin set to: git@github-$account_clean:$repo_path.git"
    fi
fi

# Test the setup
echo -e "\n${EMOJI_GITHUB} Testing git configuration..."
git config --list | grep -E "user\.(name|email)" | while read -r line; do
    echo -e "  ${EMOJI_CHECK} $line"
done

# Test SSH connection
echo -e "\n${EMOJI_KEY} Testing SSH connection..."
account_clean=$(echo "$selected_account" | tr -cd '[:alnum:]_')
echo -n "  Connecting to GitHub... "

# Run SSH test with green arrow3 spinner
SPINNER_STYLE="arrow3"
run_with_spinner "Verifying SSH connection" \
    -s "$SPINNER_STYLE" \
    -c "\033[1;32m" \
    -- timeout 20 ssh -T git@github-"$account_clean" 2>&1 | grep -q "successfully authenticated"
result=$?

if [ $result -eq 0 ]; then
    echo -e "\n${EMOJI_CHECK}${GREEN} SUCCESS${NC}"
else
    echo -e "\n${EMOJI_ERROR}${RED} FAILED${NC}"
    echo -e "${YELLOW}SSH connection test failed. Check your setup.${NC}"
fi

# Final instructions
echo -e "\n${EMOJI_PARTY}${GREEN} Repository setup complete! ${EMOJI_PARTY}${NC}"
echo -e "${WHITE}Repository location: $(pwd)${NC}"
echo -e "${WHITE}Account configured: $selected_account${NC}"
echo -e "\n${EMOJI_GIT} You can now use git commands normally:"
echo -e "  ${EMOJI_ARROW} git add ."
echo -e "  ${EMOJI_ARROW} git commit -m 'Your message'"
echo -e "  ${EMOJI_ARROW} git push origin main"
echo -e "\n${EMOJI_KEY} The repository will automatically use the SSH key for $selected_account"

# Cleanup if we cloned to temp directory
if [ "$(basename "$(pwd)")" = "repo_temp" ]; then
    echo -e "\n${EMOJI_WARN} Repository cloned to temporary directory: $(pwd)"
    echo -e "${YELLOW}You can move it to your preferred location.${NC}"
fi
