# Private Repository Cloning Guide

## 🔐 Quick Reference for SSH-Based Cloning

### Step 1: Identify Your Account Alias
```bash
grep -o '"account":"[^"]*"' ~/.ssh/github/accounts.json
```

### Step 2: Clone Using SSH Alias Format
```bash
git clone git@github-<ALIAS>:<USERNAME>/<REPO>.git
```

### Step 3: Verify Configuration
```bash
cd <REPO>
git remote -v
ssh -T git@github-<ALIAS>
```

### Alternative: Update Existing Repository
```bash
git remote set-url origin git@github-<ALIAS>:<USERNAME>/<REPO>.git
git config user.name "<ACCOUNT NAME>"
git config user.email "<ACCOUNT EMAIL>"
```

### Key Locations
- Account registry: `~/.ssh/github/accounts.json`
- SSH configuration: `~/.ssh/github/config`
- Validation script: [`enhanced-0.2/utils/validate_setup_v2.sh`]

### Troubleshooting
- Permission issues: `chmod 600 ~/.ssh/github/github_<ACCOUNT>`
- Connection test: `ssh -T git@github-<ALIAS>`
- Full validation: `./validate_setup_v2.sh`