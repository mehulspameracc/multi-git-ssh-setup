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

### Python Environment Setup
The Python scripts auto-install `rich` (for colors/spinners/TUI) via `pip install --user rich` on first run. For isolated environments or faster installs:

1. **Virtual Environment (Recommended for Projects)**:
   ```bash
   # Create and activate venv
   python -m venv .venv
   source .venv/bin/activate  # Linux/macOS
   # or .venv\Scripts\activate  # Windows

   # Run script (rich installs in venv)
   python setup/setup_ssh_enhanced_v2.py

   # Deactivate when done
   deactivate
   ```

2. **User Install Flag (--user)**:
   - If auto-install fails (e.g., permissions), manually: `pip install --user rich`
   - Scripts fallback to basic output if rich unavailable.

3. **Using uv (Fast Python Tool from Astral)**:
   - Install uv: `curl -LsSf https://astral.sh/uv/install.sh | sh` (Linux/macOS) or via brew/choco.
   - Run with uv: `uv run --with rich python setup/setup_ssh_enhanced_v2.py`
   - Or install deps: `uv pip install rich` then `python setup/setup_ssh_enhanced_v2.py`
   - uv handles virtualenvs automatically for speed/isolation.

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
