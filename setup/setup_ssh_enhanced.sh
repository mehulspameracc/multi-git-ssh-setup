#!/bin/bash
GITHUB_DIR="$HOME/.ssh/github"
CONFIG="$GITHUB_DIR/config"
ACCOUNTS_JSON="$GITHUB_DIR/accounts.json"
DEFAULTS_JSON="$GITHUB_DIR/account_defaults.json"

# Initialize directories and files
mkdir -p "$GITHUB_DIR"
touch "$CONFIG"
[ -f "$ACCOUNTS_JSON" ] || echo "[]" > "$ACCOUNTS_JSON"
[ -f "$DEFAULTS_JSON" ] || echo '{"name":"","email":""}' > "$DEFAULTS_JSON"

# Check existing include
MAIN_CONFIG="$HOME/.ssh/config"
if ! grep -q "Include github/config" "$MAIN_CONFIG"; then
    echo -e "\nInclude github/config" >> "$MAIN_CONFIG"
fi

# Account setup flow
echo "📋 Enter GitHub account aliases (comma-separated):"
IFS=',' read -ra accounts <<< "$(read -r input; echo $input)"

for account in "${accounts[@]}"; do
    account=$(echo "$account" | xargs) # Trim whitespace
    account_clean=$(echo "$account" | tr -cd '[:alnum:]_')
    key_private="$GITHUB_DIR/github_$account_clean"
    key_public="$key_private.pub"
    
    # Check existing registration
    existing=$(jq -e ".[] | select(.account == \"$account\")" "$ACCOUNTS_JSON")
    if [ $? -eq 0 ]; then
        echo "⚠️  Account '$account' already registered!"
        read -p "Overwrite/Skip/Abort? (o/s/a) [s] " choice
        case "${choice:-s}" in
            o|O)
                echo "♻️ Removing existing registration..."
                jq "del(.[] | select(.account == \"$account\"))" "$ACCOUNTS_JSON" > tmp && mv tmp "$ACCOUNTS_JSON"
                rm -f "$key_private" "$key_public" 2>/dev/null
                ;;
            a|A)
                echo "❌ Aborted by user"
                exit 1
                ;;
            *)
                echo "⏩ Skipping duplicate account"
                continue
                ;;
        esac
    fi

    # Check SSH config conflicts
    if grep -q "^Host github-$account_clean" "$CONFIG"; then
        echo "⚠️ SSH config entry exists for github-$account_clean!"
        read -p "Replace existing? (y/n) [n] " choice
        if [[ "${choice:-n}" =~ ^[Yy] ]]; then
            sed -i "/^Host github-$account_clean/,+3d" "$CONFIG"
        else
            echo "⏩ Skipping SSH config update"
            continue
        fi
    fi
    
    if [ ! -f "$key_private" ]; then
        # Key generation
        # Validate email format
        while true; do
            read -p "Enter GitHub email for '$account': " email
            if [[ "$email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
                break
            else
                echo "Invalid email format! Must be valid email address"
            fi
        done
        ssh-keygen -t ed25519 -f "$key_private" -N '' -C "$email"
        
        # Store full metadata
        jq --arg acc "$account" --arg eml "$email" --arg priv "$key_private" --arg pub "$key_public" \
            '. += [{
                "account": $acc,
                "email": $eml,
                "private_key": $priv,
                "public_key": $pub,
                "created_at": "'$(date +%Y-%m-%d)'",
                "last_used": "'$(date +%Y-%m-%d)'"
            }]' "$ACCOUNTS_JSON" > tmp && mv tmp "$ACCOUNTS_JSON"
        
        # Add to JSON registry
        jq --arg acc "$account" --arg priv "$key_private" --arg pub "$key_public" \
            '. += [{"account":$acc,"private_key":$priv,"public_key":$pub}]' \
            "$ACCOUNTS_JSON" > tmp && mv tmp "$ACCOUNTS_JSON"
            
        # SSH config
        echo -e "Host github-$account_clean\n  HostName github.com\n  User git\n  IdentityFile $key_private\n" >> "$CONFIG"
        
        # Verification workflow
        echo -e "\n🔐 Key for '$account' copied! Steps:"
        echo "1. Log into GitHub.com"
        echo "2. Add this SSH key"
        echo "3. LOG OUT of GitHub"
        echo "Browser opening in 3 seconds..."
        sleep 3
        cat "$key_public" | pbcopy || cat "$key_public"
        open "https://github.com/settings/ssh/new"
        read -p "✅ Press Enter AFTER completing steps above..."
        
        # Connection test
        echo -n "🔍 Verifying SSH access... "
        if ssh -T git@github-$account_clean 2>&1 | grep -q "successfully authenticated"; then
            echo "✅ Success!"
        else
            echo "⚠️  Verification failed! Check key permissions."
        fi
    fi
done

echo "🚀 Setup complete! Restart terminals to apply changes"
