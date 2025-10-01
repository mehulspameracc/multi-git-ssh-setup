#!/usr/bin/env python3
"""
Repo Account Association v3.0 - Python Cross-Platform Version
Full feature parity with bash v3.sh: List SSH accounts from JSON, TUI selection (numbered/Select via rich),
confirm, create .git-account (name/email/remote/alias/host), set git config, add to .gitignore, verify (SSH/fetch/log/branches).
Cross-platform (Linux/macOS/Windows): stdlib (json, subprocess, pathlib), rich for TUI/colors/spinner (auto-installs).
Requires: Python 3.6+, git/OpenSSH.
Auto-installs rich. Run: python repo/create_repo_account_v3.py [dir_path]
"""

import argparse
import json
import os
import platform
import re
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

# Auto-install rich if not available
try:
    from rich.console import Console
    from rich.panel import Panel
    from rich.progress import Progress, SpinnerColumn, TextColumn
    from rich.prompt import Prompt, Confirm, Select
    from rich.table import Table
    RICH_AVAILABLE = True
except ImportError:
    print("Installing rich for better UX...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "rich", "--user"])
    from rich.console import Console
    from rich.panel import Panel
    from rich.progress import Progress, SpinnerColumn, TextColumn
    from rich.prompt import Prompt, Confirm, Select
    from rich.table import Table
    RICH_AVAILABLE = True

# Load spinners from JSON for custom animation
SPINNERS_PATH = Path(__file__).parent.parent / "utils" / "external" / "spinners.json"
if SPINNERS_PATH.exists():
    with open(SPINNERS_PATH, "r") as f:
        SPINNERS = json.load(f)
else:
    SPINNERS = {"dots": {"interval": 80, "frames": [".", "..", "..."]}}

def custom_spinner(message, spinner_name="arrow3", duration=10):
    """Custom spinner using frames from spinners.json."""
    spinner = SPINNERS.get(spinner_name, SPINNERS["dots"])
    frames = spinner["frames"]
    interval = spinner.get("interval", 80) / 1000.0  # ms to s
    start_time = time.time()
    i = 0
    while time.time() - start_time < duration:
        frame = frames[i % len(frames)]
        print(f"\r{EMOJIS['mag']} {message} {frame}", end="", flush=True)
        time.sleep(interval)
        i += 1
    print("\r" + " " * len(message + frame) + "\r")  # Clear line

console = Console()

# Emojis
EMOJIS = {
    "rocket": "🚀",
    "key": "🔑",
    "check": "✅",
    "warn": "⚠️",
    "error": "❌",
    "github": "🐙",
    "folder": "📁",
    "git": "🐙",
    "select": "🔽",
    "verify": "🔍",
    "party": "🎉",
    "clock": "⏰",
}

# Paths (cross-platform)
HOME = Path.home()
SSH_DIR = HOME / ".ssh"
GITHUB_DIR = SSH_DIR / "github"
ACCOUNTS_JSON = GITHUB_DIR / "accounts.json"

GIT_ACCOUNT_FILE = ".git-account"
GITIGNORE_FILE = ".gitignore"

def print_colored(text, color="white"):
    if RICH_AVAILABLE:
        console.print(text, style=color)
    else:
        print(text)

def print_emoji(text, emoji_key, color="white"):
    emoji = EMOJIS.get(emoji_key, "")
    print_colored(f"{emoji} {text}", color)

def show_spinner(message, duration=10):
    if RICH_AVAILABLE:
        with Progress(SpinnerColumn(), TextColumn(f"[cyan]{message}[/cyan]"), console=console, transient=True) as progress:
            task = progress.add_task("", total=None)
            time.sleep(duration)
    else:
        custom_spinner(message, "arrow3", duration)

def run_command(cmd_list, check=True, capture_output=True, timeout=30, cwd=None):
    """Run command cross-platform."""
    try:
        result = subprocess.run(cmd_list, check=check, capture_output=capture_output, text=True, timeout=timeout, cwd=cwd)
        return result
    except subprocess.TimeoutExpired:
        print_colored(f"{EMOJIS['error']} Command timed out", "red")
        return None
    except subprocess.CalledProcessError as e:
        if capture_output:
            print_colored(f"{EMOJIS['error']} Command failed: {e.stderr or e.stdout}", "red")
        return None
    except FileNotFoundError:
        print_colored(f"{EMOJIS['error']} Command not found: {cmd_list[0]}. Ensure git/OpenSSH installed.", "red")
        return None

def get_accounts_json():
    if not GITHUB_DIR.exists() or not ACCOUNTS_JSON.exists():
        return []
    with open(ACCOUNTS_JSON, "r", encoding="utf-8") as f:
        return json.load(f)

def select_account(accounts):
    if not accounts:
        print_colored(f"{EMOJIS['warn']} No accounts configured. Run setup_ssh_enhanced_v2.py first.", "yellow")
        sys.exit(1)

    account_names = [acc["account"] for acc in accounts]
    if RICH_AVAILABLE:
        selected = Select("Select account to associate:", choices=account_names)
        choice = console.input(Select.get_prompt(selected))
        index = account_names.index(choice)
    else:
        print_colored("Available accounts:")
        for i, name in enumerate(account_names, 1):
            print(f"{i}. {name}")
        while True:
            try:
                index = int(input("Enter number: ")) - 1
                if 0 <= index < len(accounts):
                    break
            except ValueError:
                pass
            print_colored("Invalid choice.", "red")

    selected_acc = accounts[index]
    if Confirm.ask(f"Confirm association with {selected_acc['account']} ({selected_acc['email']})?") if RICH_AVAILABLE else input(f"Confirm {selected_acc['account']}? (y/n): ").lower() == "y":
        return selected_acc
    else:
        print_colored("Selection cancelled.", "yellow")
        sys.exit(0)

def is_git_repo(cwd):
    return (cwd / ".git").exists()

def init_git_repo(cwd):
    if Confirm.ask("Not a git repo. Initialize?") if RICH_AVAILABLE else input("Initialize git repo? (y/n): ").lower() == "y":
        run_command(["git", "init"], cwd=cwd)
        print_colored("Git repo initialized.", "green")
        return True
    else:
        print_colored("Aborted.", "red")
        sys.exit(1)

def get_remote_url(cwd):
    result = run_command(["git", "remote", "get-url", "origin"], cwd=cwd, capture_output=True)
    if result and result.returncode == 0:
        return result.stdout.strip()
    return None

def validate_remote_url(url):
    pattern = r"^git@github-[a-zA-Z0-9_]+:[\w-]+/[\w-]+\.git$"
    return re.match(pattern, url) is not None

def create_git_account(cwd, account):
    git_account_path = cwd / GIT_ACCOUNT_FILE
    if git_account_path.exists():
        if not Confirm.ask("Overwrite existing .git-account?") if RICH_AVAILABLE else input("Overwrite .git-account? (y/n): ").lower() != "y":
            print_colored("Aborted.", "red")
            sys.exit(1)

    host_alias = f"github-{account['account']}"
    remote_url = Prompt.ask("Enter remote repo URL (git@github-...:username/repo.git)") if RICH_AVAILABLE else input("Enter remote repo URL: ")
    while not validate_remote_url(remote_url):
        print_colored("Invalid URL format. Must be git@github-...:username/repo.git", "red")
        remote_url = Prompt.ask("Enter valid remote URL") if RICH_AVAILABLE else input("Enter valid remote URL: ")

    content = f"""# Git Account Configuration
account={account['account']}
email={account['email']}
name={account['account']}  # Or prompt for full name if needed
remote_url={remote_url}
host_alias={host_alias}
ssh_key={account['private_key']}
created={datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
"""
    with open(git_account_path, "w", encoding="utf-8") as f:
        f.write(content)
    print_colored(f".git-account created at {git_account_path}", "green")

def set_git_config(cwd, account):
    run_command(["git", "config", "user.name", account['account']], cwd=cwd)
    run_command(["git", "config", "user.email", account['email']], cwd=cwd)
    print_colored("Git config (user.name/email) set.", "green")

def add_to_gitignore(cwd):
    gitignore_path = cwd / GITIGNORE_FILE
    if not gitignore_path.exists():
        gitignore_path.touch()
    with open(gitignore_path, "r", encoding="utf-8") as f:
        content = f.read()
    if GIT_ACCOUNT_FILE not in content:
        with open(gitignore_path, "a", encoding="utf-8") as f:
            f.write(f"\n{GIT_ACCOUNT_FILE}")
        print_colored(f"{GIT_ACCOUNT_FILE} added to .gitignore", "green")
    else:
        print_colored(f"{GIT_ACCOUNT_FILE} already in .gitignore", "yellow")

def verify_setup(cwd, account):
    host_alias = f"github-{account['account']}"
    print_colored("Verifying setup...", "cyan")
    show_spinner("Testing SSH connection...", 10)
    result = run_command(["ssh", "-T", f"git@{host_alias}"], cwd=cwd, capture_output=True, timeout=20)
    if result and "successfully authenticated" in result.stdout.lower():
        print_emoji("SSH verified", "check", "green")
    else:
        print_colored("SSH test failed - check key addition.", "yellow")

    remote_url = get_remote_url(cwd)
    if not remote_url:
        run_command(["git", "remote", "add", "origin", Prompt.ask("Enter origin URL") if RICH_AVAILABLE else input("Enter origin URL: ")], cwd=cwd)
        print_colored("Remote origin added.", "green")
    else:
        print_colored(f"Remote origin: {remote_url}", "cyan")

    show_spinner("Fetching...", 10)
    run_command(["git", "fetch", "origin"], cwd=cwd)

    show_spinner("Checking log...", 5)
    log_result = run_command(["git", "log", "--oneline", "-1"], cwd=cwd, capture_output=True)
    if log_result:
        print_colored(f"Latest commit: {log_result.stdout.strip()}", "cyan")

    show_spinner("Listing branches...", 5)
    branch_result = run_command(["git", "branch", "-a"], cwd=cwd, capture_output=True)
    if branch_result:
        branches = [b.strip() for b in branch_result.stdout.split("\n") if b.strip()]
        print_colored(f"Branches ({len(branches)}): {', '.join(branches[:5])}...", "cyan")

    print_emoji("Verification complete!", "party", "green")

def main():
    parser = argparse.ArgumentParser(description="Associate GitHub SSH Account to Repo v3.0")
    parser.add_argument("dir_path", nargs="?", default=".", help="Directory path (default: current)")
    args = parser.parse_args()

    cwd = Path(args.dir_path).resolve()
    if not cwd.exists():
        print_colored(f"{EMOJIS['error']} Directory not found: {cwd}", "red")
        sys.exit(1)

    print_emoji(f"Working in directory: {cwd}", "folder", "cyan")

    if not is_git_repo(cwd):
        init_git_repo(cwd)

    accounts = get_accounts_json()
    selected_account = select_account(accounts)

    create_git_account(cwd, selected_account)
    set_git_config(cwd, selected_account)
    add_to_gitignore(cwd)
    verify_setup(cwd, selected_account)

    print_emoji("Repo association complete! Commit and push to test.", "party", "green")

if __name__ == "__main__":
    main()