#!/usr/bin/env python3
"""
Enhanced GitHub SSH Setup v2.0 - Python Cross-Platform Version
Full feature parity with bash v2.sh and ps1: multi-account SSH setup, JSON registry,
key generation, config updates, GitHub guidance, verification.
Cross-platform (Linux/macOS/Windows): Uses stdlib (json, subprocess, pathlib, webbrowser),
rich for colors/spinner/TUI (auto-installs if missing), optional platform clipboard via subprocess.
Requires: Python 3.6+, OpenSSH (install via package manager/Settings).
Auto-installs rich. Run: python setup_ssh_enhanced_v2.py [accounts]
"""

import argparse
import json
import os
import platform
import re
import shutil
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path
import webbrowser

# Auto-install rich if not available
try:
    from rich.console import Console
    from rich.markdown import Markdown
    from rich.panel import Panel
    from rich.progress import Progress, SpinnerColumn, TextColumn
    from rich.prompt import Prompt, Confirm
    from rich.table import Table
    from rich.text import Text
    RICH_AVAILABLE = True
except ImportError:
    print("Installing rich for better UX...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "rich", "--user"])
    from rich.console import Console
    from rich.markdown import Markdown
    from rich.panel import Panel
    from rich.progress import Progress, SpinnerColumn, TextColumn
    from rich.prompt import Prompt, Confirm
    from rich.table import Table
    from rich.text import Text
    RICH_AVAILABLE = True

# Load spinners from JSON for custom animation
SPINNERS_PATH = Path(__file__).parent.parent / "utils" / "external" / "spinners.json"
if SPINNERS_PATH.exists():
    with open(SPINNERS_PATH, "r") as f:
        SPINNERS = json.load(f)
else:
    SPINNERS = {"dots": {"interval": 80, "frames": [".", "..", "..."]}}

def custom_spinner(message, spinner_name="arrow3", duration=30):
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

# Emojis (Unicode, cross-platform)
EMOJIS = {
    "rocket": "🚀",
    "key": "🔑",
    "check": "✅",
    "warn": "⚠️",
    "error": "❌",
    "github": "🐙",
    "clipboard": "📋",
    "lock": "🔒",
    "mag": "🔍",
    "computer": "💻",
    "party": "🎉",
    "clock": "⏰",
}

# Paths (cross-platform with pathlib)
HOME = Path.home()
SSH_DIR = HOME / ".ssh"
GITHUB_DIR = SSH_DIR / "github"
CONFIG = GITHUB_DIR / "config"
ACCOUNTS_JSON = GITHUB_DIR / "accounts.json"
DEFAULTS_JSON = GITHUB_DIR / "account_defaults.json"
MAIN_CONFIG = SSH_DIR / "config"

def print_colored(text, color="white"):
    if RICH_AVAILABLE:
        console.print(text, style=color)
    else:
        print(text)

def print_emoji(text, emoji_key, color="white"):
    emoji = EMOJIS.get(emoji_key, "")
    print_colored(f"{emoji} {text}", color)

def show_spinner(message, duration=30):
    if RICH_AVAILABLE:
        with Progress(
            SpinnerColumn(),
            TextColumn(f"[cyan]{message}[/cyan]"),
            console=console,
            transient=True,
        ) as progress:
            task = progress.add_task("", total=None)
            time.sleep(duration)
    else:
        custom_spinner(message, "arrow3", duration)

def run_command(cmd_list, check=True, capture_output=True, timeout=60, cwd=None):
    """Run command cross-platform with subprocess."""
    try:
        result = subprocess.run(
            cmd_list, check=check, capture_output=capture_output, text=True, timeout=timeout, cwd=cwd
        )
        return result
    except subprocess.TimeoutExpired:
        print_colored(f"{EMOJIS['error']} Command timed out: {' '.join(cmd_list)}", "red")
        sys.exit(1)
    except subprocess.CalledProcessError as e:
        print_colored(f"{EMOJIS['error']} Command failed: {e}", "red")
        if capture_output and e.stdout:
            print_colored(f"Stdout: {e.stdout}", "yellow")
        if capture_output and e.stderr:
            print_colored(f"Stderr: {e.stderr}", "yellow")
        sys.exit(1)
    except FileNotFoundError:
        print_colored(f"{EMOJIS['error']} Command not found: {cmd_list[0]}. Ensure OpenSSH is installed.", "red")
        sys.exit(1)

def copy_to_clipboard(content):
    """Cross-platform clipboard copy without extra deps."""
    sys_name = platform.system()
    try:
        if sys_name == "Darwin":  # macOS
            run_command(["pbcopy"], input=content, check=True, capture_output=False)
        elif sys_name == "Windows":
            run_command(["clip"], input=content, check=True, capture_output=False, shell=True)
        elif sys_name == "Linux":
            # Assume xclip or wl-clipboard; fallback to print
            try:
                run_command(["xclip", "-selection", "clipboard"], input=content, check=True, capture_output=False)
            except:
                run_command(["wl-copy"], input=content, check=True, capture_output=False)
        else:
            raise NotImplementedError
        return True
    except:
        return False

def get_accounts_json():
    if ACCOUNTS_JSON.exists():
        with open(ACCOUNTS_JSON, "r", encoding="utf-8") as f:
            return json.load(f)
    return []

def save_accounts_json(accounts):
    GITHUB_DIR.mkdir(parents=True, exist_ok=True)
    with open(ACCOUNTS_JSON, "w", encoding="utf-8") as f:
        json.dump(accounts, f, indent=2)

def account_exists(account_name):
    accounts = get_accounts_json()
    return next((a for a in accounts if a.get("account") == account_name), None)

def add_account_to_json(account, email, priv_key, pub_key):
    accounts = get_accounts_json()
    new_entry = {
        "account": account,
        "email": email,
        "private_key": str(priv_key),
        "public_key": str(pub_key),
        "created_at": datetime.now().strftime("%Y-%m-%d"),
        "last_used": datetime.now().strftime("%Y-%m-%d"),
    }
    accounts.append(new_entry)
    save_accounts_json(accounts)

def remove_account_from_json(account):
    accounts = get_accounts_json()
    accounts = [a for a in accounts if a.get("account") != account]
    save_accounts_json(accounts)

def validate_email(email):
    pattern = r"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"
    return re.match(pattern, email) is not None

def check_ssh_available():
    try:
        run_command(["ssh", "-V"], check=True, capture_output=True)
        return True
    except:
        return False

def main():
    parser = argparse.ArgumentParser(description="Enhanced GitHub SSH Setup v2.0 (Cross-Platform)")
    parser.add_argument("accounts", nargs="?", help="Comma-separated account aliases")
    args = parser.parse_args()

    if not check_ssh_available():
        print_colored(f"{EMOJIS['error']} OpenSSH not found. Install via package manager (apt/brew/choco) or Windows Settings.", "red")
        sys.exit(1)

    # Initialize
    GITHUB_DIR.mkdir(parents=True, exist_ok=True)
    if not ACCOUNTS_JSON.exists():
        save_accounts_json([])
    if not CONFIG.exists():
        CONFIG.touch()
    if not DEFAULTS_JSON.exists():
        with open(DEFAULTS_JSON, "w") as f:
            json.dump({"name": "", "email": ""}, f)

    # Main config include
    MAIN_CONFIG.parent.mkdir(exist_ok=True)
    if MAIN_CONFIG.exists():
        with open(MAIN_CONFIG, "r", encoding="utf-8") as f:
            content = f.read()
        if "Include ~/.ssh/github/config" not in content:
            with open(MAIN_CONFIG, "a", encoding="utf-8") as f:
                f.write("\nInclude ~/.ssh/github/config\n")
            print_emoji("Added SSH config include", "warn", "yellow")

    # Accounts input
    if args.accounts:
        accounts = [a.strip() for a in args.accounts.split(",") if a.strip()]
    else:
        accounts_input = Prompt.ask("Enter GitHub account aliases (comma-separated)") if RICH_AVAILABLE else input("Enter GitHub account aliases (comma-separated): ")
        accounts = [a.strip() for a in accounts_input.split(",") if a.strip()]

    if RICH_AVAILABLE:
        console.print(Panel("Enhanced GitHub SSH Setup v2.0", title=EMOJIS["rocket"], style="cyan"))
    print_colored(f"{EMOJIS['rocket']} Enhanced GitHub SSH Setup v2.0", "cyan")
    print_colored("This script sets up multiple GitHub accounts with SSH keys (cross-platform!)", "blue")

    for account in accounts:
        account_clean = re.sub(r"[^a-zA-Z0-9_]", "_", account)
        key_private = GITHUB_DIR / f"github_{account_clean}"
        key_public = key_private.with_suffix(".pub")

        print_emoji(f"Processing account: {account}", "github", "white")

        existing = account_exists(account)
        if existing:
            print_colored(f"{EMOJIS['warn']} Account '{account}' already registered!", "yellow")
            choice = Prompt.ask("Overwrite/Skip/Abort", choices=["o", "s", "a"], default="s") if RICH_AVAILABLE else input("Overwrite/Skip/Abort (o/s/a) [s]: ").lower() or "s"
            if choice == "o":
                remove_account_from_json(account)
                key_private.unlink(missing_ok=True)
                key_public.unlink(missing_ok=True)
                print_colored("Removing existing registration...", "white")
            elif choice == "a":
                print_colored("Aborted by user", "red")
                sys.exit(1)
            else:
                print_colored("Skipping duplicate account", "yellow")
                continue

        # SSH config conflict
        if CONFIG.exists():
            with open(CONFIG, "r", encoding="utf-8") as f:
                content = f.read()
            host_entry = f"Host github-{account_clean}"
            if host_entry in content:
                print_colored(f"{EMOJIS['warn']} SSH config entry exists for github-{account_clean}!", "yellow")
                replace = Confirm.ask("Replace existing?") if RICH_AVAILABLE else input("Replace existing? (y/n) [n]: ").lower() == "y"
                if replace:
                    # Remove block with regex
                    block_pattern = re.compile(rf"(?ms)^{re.escape(host_entry)}\s*\n(^\s*(HostName|User|IdentityFile).*?\n)*", re.MULTILINE)
                    new_content = block_pattern.sub("", content)
                    with open(CONFIG, "w", encoding="utf-8") as f:
                        f.write(new_content)
                    print_colored("Replaced existing SSH config entry.", "yellow")
                else:
                    print_colored("Skipping SSH config update", "yellow")
                    continue

        if not key_private.exists():
            # Email
            while True:
                email = Prompt.ask(f"{EMOJIS['lock']} Enter GitHub email for '{account}'") if RICH_AVAILABLE else input(f"{EMOJIS['lock']} Enter GitHub email for '{account}': ")
                if validate_email(email):
                    break
                print_colored("Invalid email format! Must be valid email address", "red")

            print_colored("Generating ED25519 SSH key...", "white")
            show_spinner("Generating key (this may take a moment)...", 15)
            cmd = ["ssh-keygen", "-t", "ed25519", "-f", str(key_private), "-N", "", "-C", email]
            result = run_command(cmd, timeout=30)
            if result.returncode != 0:
                print_colored(f"{EMOJIS['error']} Key generation failed: {result.stderr}", "red")
                print_colored("Ensure OpenSSH supports ED25519 (try rsa fallback manually).", "yellow")
                sys.exit(1)

            add_account_to_json(account, email, key_private, key_public)

            # SSH config
            config_entry = f"""Host github-{account_clean}
  HostName github.com
  User git
  IdentityFile {key_private}

"""
            with open(CONFIG, "a", encoding="utf-8") as f:
                f.write(config_entry)

        # Guidance
        if RICH_AVAILABLE:
            console.print(Panel(Markdown(f"# {EMOJIS['github']} GITHUB SSH KEY SETUP {EMOJIS['github']}"), style="magenta"))
        else:
            print("\n" + "="*60)
            print(f"{EMOJIS['github']} GITHUB SSH KEY SETUP {EMOJIS['github']}")
            print("="*60)

        print_colored(f"{EMOJIS['key']} SSH Key copied to clipboard! {EMOJIS['clipboard']}", "yellow")
        print_colored("Follow these steps EXACTLY:", "white")

        print_colored(f"{EMOJIS['github']} Step 1: Open GitHub.com in your browser", "cyan")
        print_colored("(Browser will open automatically in 3 seconds)", "yellow")
        time.sleep(3)
        webbrowser.open("https://github.com/settings/ssh/new")

        print_colored(f"{EMOJIS['github']} Step 2: Go to Settings → SSH and GPG keys → New SSH key", "cyan")

        print_colored(f"{EMOJIS['github']} Step 3: Paste the key below and give it a title", "cyan")
        print_colored("="*50, "yellow")
        with open(key_public, "r", encoding="utf-8") as f:
            print(f.read())
        print_colored("="*50, "yellow")

        print_colored(f"{EMOJIS['github']} Step 4: IMPORTANT: Log OUT of GitHub completely!", "cyan")
        print_colored("This step is crucial for verification to work", "red")

        # Clipboard
        with open(key_public, "r", encoding="utf-8") as f:
            content = f.read()
        if copy_to_clipboard(content):
            print_emoji("Key copied to clipboard automatically!", "check", "green")
        else:
            print_colored(f"{EMOJIS['warn']} Could not auto-copy. Manual copy from: {key_public}", "yellow")

        if RICH_AVAILABLE:
            Prompt.ask(f"{EMOJIS['clock']} Press Enter AFTER completing ALL 4 steps above")
        else:
            input(f"{EMOJIS['clock']} Press Enter AFTER completing ALL 4 steps above: ")

        # Verification
        print_colored("Testing SSH connection... (This may take up to 30 seconds)", "cyan")
        show_spinner("Verifying connection...", 30)
        cmd = ["ssh", "-T", f"git@github-{account_clean}"]
        result = run_command(cmd, capture_output=True, timeout=30)
        if "successfully authenticated" in result.stdout.lower():
            print_emoji(f"SUCCESS! SSH connection verified for {account}", "check", "green")
            print_colored(f"You can now use: git@github-{account_clean}:your-repo.git", "cyan")
        else:
            print_emoji(f"Verification failed for {account}", "error", "red")
            print_colored("Possible issues:", "yellow")
            print_colored("  • Did you complete all 4 steps above?", "yellow")
            print_colored("  • Did you log OUT of GitHub completely?", "yellow")
            print_colored("  • Check if the key was added correctly in GitHub settings", "yellow")
            print_colored(f"  • Try running: ssh -T git@github-{account_clean}", "cyan")

    print_emoji("Setup complete!", "party", "green")
    print_colored("Restart your terminal/PowerShell for changes to take effect.", "white")
    print_colored("To add SSH keys to repos, use: python repo/create_repo_account_v3.py", "white")
    print_colored("To validate setup, run Python equivalent of utils/validate_setup_v2.sh (create if needed).", "white")

if __name__ == "__main__":
    main()