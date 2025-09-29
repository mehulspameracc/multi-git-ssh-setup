#!/bin/bash
# GitHub SSH Accounts Repair Tool
# Rebuilds accounts.json from existing SSH keys

GITHUB_DIR="$HOME/.ssh/github"
ACCOUNTS_JSON="$GITHUB_DIR/accounts.json"
TEMP_JSON="/tmp/accounts_temp.json"

echo -e "\033[1;34m🔧 Rebuilding GitHub accounts registry...\033[0m"

# Create accounts.json if missing
[ -f "$ACCOUNTS_JSON" ] || echo "[]" > "$ACCOUNTS_JSON"

# Start new JSON array
echo "[" > "$TEMP_JSON"

first=true
# Process all private keys
find "$GITHUB_DIR" -name 'github_*' ! -name '*.pub' | while read -r key; do
    account=$(basename "$key")
    account=${account#github_}
    pub_key="${key}.pub"
    
    # Extract email from public key comment
    if [ -f "$pub_key" ]; then
        email=$(awk '{print $NF}' "$pub_key")
    else
        email="unknown@example.com"
    fi
    
    # Add comma before new entries (except first)
    if [ "$first" = false ]; then
        echo "," >> "$TEMP_JSON"
    fi
    first=false
    
    # Add account entry
    echo "  {" >> "$TEMP_JSON"
    echo "    \"account\": \"$account\"," >> "$TEMP_JSON"
    echo "    \"email\": \"$email\"," >> "$TEMP_JSON"
    echo "    \"private_key\": \"$key\"," >> "$TEMP_JSON"
    echo "    \"public_key\": \"$pub_key\"," >> "$TEMP_JSON"
    echo "    \"created_at\": \"$(date +%Y-%m-%d)\"," >> "$TEMP_JSON"
    echo "    \"last_used\": \"$(date +%Y-%m-%d)\"" >> "$TEMP_JSON"
    echo "  }" >> "$TEMP_JSON"
done

# Close JSON array
echo "]" >> "$TEMP_JSON"

# Replace original accounts.json
mv "$TEMP_JSON" "$ACCOUNTS_JSON"

echo -e "\033[1;32m✅ Repair complete! Accounts:\033[0m"
grep -o '"account": *"[^"]*"' "$ACCOUNTS_JSON" | awk -F'"' '{print $4}'