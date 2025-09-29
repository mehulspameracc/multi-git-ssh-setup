#!/bin/bash
echo "=== SSH Config Check ==="
grep -A3 "Host github-" ~/.ssh/github/config

echo "=== Account Registry ==="
jq . ~/.ssh/github/accounts.json

echo "=== Connection Tests ==="
while read -r acc; do
    echo -n "$acc: "
    if ssh -T git@github-"$acc" 2>&1 | grep -q "successfully authenticated"; then
        echo "✅ OK"
    else
        echo "❌ FAIL"
    fi
done < <(jq -r '.[].account' ~/.ssh/github/accounts.json)
