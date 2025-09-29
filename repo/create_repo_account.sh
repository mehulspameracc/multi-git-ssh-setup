#!/bin/bash
GITHUB_DIR="$HOME/.ssh/github"
ACCOUNTS_JSON="$GITHUB_DIR/accounts.json"

# Get accounts with proper email
mapfile -t accounts < <(jq -r '.[] | "\(.account) (\(.email))"' "$ACCOUNTS_JSON")

# Improved selection UI
echo "Select GitHub account:"
select account_info in "${accounts[@]}"; do
    account=$(echo "$account_info" | cut -d' ' -f1)
    email=$(jq -r ".[] | select(.account == \"$account\") | .email" "$ACCOUNTS_JSON")
    
    # Create .git-account with verified email
    echo "GIT_NAME=\"$account\"" > .git-account
    echo "GIT_EMAIL=\"$email\"" >> .git-account
    echo "SSH_KEY=\"$GITHUB_DIR/github_$account\"" >> .git-account
    
    # Auto-ignore sensitive files
    grep -qxF ".git-account" .gitignore || echo -e "\n# GitHub Account\n.git-account" >> .gitignore
    echo "✅ Configured for $account ($email)"
    break
done
