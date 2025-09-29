#!/bin/bash
# Verify SSH connection for GitHub account
account_host="$1"
ssh -T git@github-"$account_host" 2>&1 | grep -q "successfully authenticated"
exit $?
