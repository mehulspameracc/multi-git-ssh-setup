# GitHub Multi-Account SSH Manager v0.3

## Features
- 🛡️ Secure per-account SSH keys with ED25519
- 🔄 Cross-platform support (Windows/Linux/Mac)
- 🔍 Automated connection verification
- 📋 JSON-based account registry
- 🧩 Modular SSH config management

## Quick Start
```bash
# Unix/Mac
curl -O https://example.com/setup_ssh_enhanced.sh
chmod +x setup_ssh_enhanced.sh
./setup_ssh_enhanced.sh

# Windows (Admin)
iwr -Uri https://example.com/setup_ssh_enhanced.ps1 -OutFile setup_ssh_enhanced.ps1
.\setup_ssh_enhanced.ps1
```

## Usage
```bash
# Create repo association
cd your-project
../enhanced-0.2/repo/create_repo_account.sh

# Validate setup
../enhanced-0.2/utils/validate_setup.sh
```

## Security
- Keys stored in isolated directory
- Annual key rotation recommended
- Never commit .git-account files
