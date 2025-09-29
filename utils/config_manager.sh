#!/bin/bash
GITHUB_DIR="$HOME/.ssh/github"
ACCOUNTS_JSON="$GITHUB_DIR/accounts.json"

list_accounts() {
    jq -r '.[].account' "$ACCOUNTS_JSON"
}

add_account() {
    jq --arg acc "$1" --arg priv "$2" --arg pub "$3" \
        '. += [{"account":$acc,"private_key":$priv,"public_key":$pub}]' \
        "$ACCOUNTS_JSON" > tmp && mv tmp "$ACCOUNTS_JSON"
}

remove_account() {
    jq "del(.[] | select(.account == \"$1\"))" "$ACCOUNTS_JSON" > tmp && mv tmp "$ACCOUNTS_JSON"
}

update_defaults() {
    jq --arg name "$1" --arg email "$2" \
        '.name = $name | .email = $email' \
        "$GITHUB_DIR/account_defaults.json" > tmp && mv tmp "$GITHUB_DIR/account_defaults.json"
}
