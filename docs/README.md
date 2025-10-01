# GitHub Multi-Account SSH Manager v0.3

## Features
- 🛡️ Secure per-account SSH keys with ED25519
- 🔄 Cross-platform support (Windows/Linux/Mac/Python)
- 🔍 Automated connection verification
- 📋 JSON-based account registry
- 🧩 Modular SSH config management
- 🐍 Python implementations with auto-install deps and custom spinners

## Quick Start
```bash
# Unix/Mac (Bash)
curl -O https://example.com/setup_ssh_enhanced.sh
chmod +x setup_ssh_enhanced.sh
./setup_ssh_enhanced.sh

# Windows (PowerShell)
iwr -Uri https://example.com/setup_ssh_enhanced.ps1 -OutFile setup_ssh_enhanced.ps1
.\setup_ssh_enhanced.ps1

# Cross-Platform (Python - auto-installs rich)
python setup/setup_ssh_enhanced_v2.py
```

## Usage
```bash
# Bash Repo Association
cd your-project
../enhanced-0.2/repo/create_repo_account_v3.sh

# Python Repo Association
python repo/create_repo_account_v3.py

# Validate Setup (Bash)
../enhanced-0.2/utils/validate_setup_v2.sh
```

## Security
- Keys stored in isolated directory (~/.ssh/github)
- Annual key rotation recommended
- Never commit .git-account files
- Python scripts auto-handle deps securely (pip --user)
