# Enhanced GitHub SSH Setup v2.0 - Windows PowerShell
# Feature parity with bash v2: jq-free (PowerShell JSON), colors, key gen, validation, clipboard, browser, verification
# Requires OpenSSH (Windows 10+ built-in) and PowerShell 5.1+

param(
    [string]$Accounts = ""  # Optional: Comma-separated accounts as param
)

# Check for OpenSSH availability
if (-not (Get-Command ssh -ErrorAction SilentlyContinue)) {
    Write-Host "${EMOJI_ERROR} OpenSSH not found in PATH. Please install OpenSSH Client via Windows Settings > Apps > Optional Features." -ForegroundColor Red
    exit 1
}

# Paths (Windows style)
$GITHUB_DIR = "$env:USERPROFILE\.ssh\github"
$CONFIG = "$GITHUB_DIR\config"
$ACCOUNTS_JSON = "$GITHUB_DIR\accounts.json"
$DEFAULTS_JSON = "$GITHUB_DIR\account_defaults.json"

# ANSI Colors (PowerShell supports)
$RED = 'Red'
$GREEN = 'Green'
$YELLOW = 'Yellow'
$BLUE = 'Blue'
$PURPLE = 'Magenta'
$CYAN = 'Cyan'
$WHITE = 'White'

# Emojis (Unicode)
$EMOJI_ROCKET = "🚀"
$EMOJI_KEY = "🔑"
$EMOJI_CHECK = "✅"
$EMOJI_WARN = "⚠️"
$EMOJI_ERROR = "❌"
$EMOJI_GITHUB = "🐙"
$EMOJI_CLIPBOARD = "📋"
$EMOJI_LOCK = "🔒"
$EMOJI_MAG = "🔍"
$EMOJI_COMPUTER = "💻"
$EMOJI_PARTY = "🎉"
$EMOJI_CLOCK = "⏰"

# Function to print colored output
function Write-Color {
    param(
        [string]$Text,
        [string]$Color = "White"
    )
    Write-Host $Text -ForegroundColor $Color
}

# Function to print emoji colored
function Write-Emoji {
    param(
        [string]$Emoji,
        [string]$Text,
        [string]$Color = "White"
    )
    Write-Host "$Emoji $Text" -ForegroundColor $Color
}

# Simple spinner function for parity with bash spinner (dot-based animation)
function Show-Spinner {
    param(
        [string]$Message,
        [int]$Duration = 30
    )
    Write-Host $Message -NoNewline -ForegroundColor Cyan
    for ($i = 0; $i -lt $Duration; $i++) {
        if ($i % 5 -eq 0) { Write-Host -NoNewline "." }
        Start-Sleep -Milliseconds 1000
    }
    Write-Host ""
}

# JSON helpers (PowerShell native, no jq)
function Add-AccountToJson {
    param([string]$Account, [string]$Email, [string]$PrivKey, [string]$PubKey)
    
    if (-not (Test-Path $ACCOUNTS_JSON) -or ((Get-Content $ACCOUNTS_JSON -Raw) -eq '')) {
        $jsonArray = @()
    } else {
        $jsonArray = Get-Content $ACCOUNTS_JSON -Raw | ConvertFrom-Json
    }
    
    $newEntry = [PSCustomObject]@{
        account = $Account
        email = $Email
        private_key = $PrivKey
        public_key = $PubKey
        created_at = Get-Date -Format "yyyy-MM-dd"
        last_used = Get-Date -Format "yyyy-MM-dd"
    }
    
    $jsonArray += $newEntry
    $jsonArray | ConvertTo-Json -Depth 10 | Out-File $ACCOUNTS_JSON -Encoding UTF8
}

function Test-AccountExists {
    param([string]$Account)
    
    if (Test-Path $ACCOUNTS_JSON) {
        $jsonArray = Get-Content $ACCOUNTS_JSON -Raw | ConvertFrom-Json
        return ($jsonArray | Where-Object { $_.account -eq $Account })
    }
    return $false
}

function Remove-AccountFromJson {
    param([string]$Account)
    
    if (Test-Path $ACCOUNTS_JSON) {
        $jsonArray = Get-Content $ACCOUNTS_JSON -Raw | ConvertFrom-Json
        $jsonArray = $jsonArray | Where-Object { $_.account -ne $Account }
        $jsonArray | ConvertTo-Json -Depth 10 | Out-File $ACCOUNTS_JSON -Encoding UTF8
    }
}

function Get-AccountList {
    if (Test-Path $ACCOUNTS_JSON) {
        $jsonArray = Get-Content $ACCOUNTS_JSON -Raw | ConvertFrom-Json
        return $jsonArray.account
    }
    return @()
}

# Initialize directories
Write-Color "${EMOJI_COMPUTER} Initializing environment..." Cyan
New-Item -Path $GITHUB_DIR -ItemType Directory -Force | Out-Null
if (-not (Test-Path $ACCOUNTS_JSON)) { "[]" | Out-File $ACCOUNTS_JSON -Encoding UTF8 }
if (-not (Test-Path $CONFIG)) { New-Item $CONFIG -ItemType File | Out-Null }
if (-not (Test-Path $DEFAULTS_JSON)) { '{"name":"","email":""}' | Out-File $DEFAULTS_JSON -Encoding UTF8 }

# Check existing include in main config
$MAIN_CONFIG = "$env:USERPROFILE\.ssh\config"
if (-not (Test-Path $MAIN_CONFIG)) { New-Item $MAIN_CONFIG -ItemType File | Out-Null }
if (-not (Select-String -Path $MAIN_CONFIG -Pattern "Include \~\.ssh\\github\\config")) {
    Write-Color "${EMOJI_WARN} Adding SSH config include..." Yellow
    "`nInclude ~/.ssh/github/config" | Add-Content $MAIN_CONFIG
}

# Account input
if ($Accounts) {
    $accounts = $Accounts -split ',' | ForEach-Object { $_.Trim() }
} else {
    $accountsInput = Read-Host "${EMOJI_CLIPBOARD} Enter GitHub account aliases (comma-separated)"
    $accounts = $accountsInput -split ',' | ForEach-Object { $_.Trim() }
}

Write-Color "${EMOJI_ROCKET} Enhanced GitHub SSH Setup v2.0" Cyan
Write-Color "================================`n" White
Write-Color "This script will help you set up multiple GitHub accounts with SSH keys" Blue
Write-Color "No external dependencies required - works on Windows with OpenSSH!`n" Blue

# Account setup loop
foreach ($account in $accounts) {
    if ([string]::IsNullOrWhiteSpace($account)) { continue }
    
    $accountClean = $account -replace '[^a-zA-Z0-9_]', '_'
    $keyPrivate = "$GITHUB_DIR\github_$accountClean"
    $keyPublic = "$keyPrivate.pub"
    
    Write-Emoji $EMOJI_GITHUB "Processing account: $account" White
    
    # Check existing
    $existing = Test-AccountExists $account
    if ($existing) {
        Write-Color "Account '$account' already registered!" Yellow
        $choice = Read-Host "Overwrite/Skip/Abort? (o/s/a) [s]"
        switch ($choice.ToLower()) {
            'o' {
                Write-Color "Removing existing registration..." White
                Remove-AccountFromJson $account
                Remove-Item $existing.private_key -ErrorAction SilentlyContinue
                Remove-Item $existing.public_key -ErrorAction SilentlyContinue
            }
            'a' {
                Write-Color "Aborted by user" Red
                exit 1
            }
            default {
                Write-Color "Skipping duplicate account" Yellow
                continue
            }
        }
    }
    
    # Check SSH config conflicts
    if (Test-Path $CONFIG) {
        $hostEntry = "Host github-$accountClean"
        if (Select-String -Path $CONFIG -Pattern "^$hostEntry") {
            Write-Color "SSH config entry exists for github-$accountClean!" Yellow
            $choice = Read-Host "Replace existing? (y/n) [n]"
            if ($choice.ToLower() -eq 'y') {
                # Improved block removal using regex for entire Host block
                $blockPattern = "(?ms)^$hostEntry\s*\n(^\s*(HostName|User|IdentityFile).*?\n)*"
                $content = Get-Content $CONFIG -Raw
                $newContent = $content -replace $blockPattern, ""
                $newContent | Out-File $CONFIG -Encoding UTF8
                Write-Color "Replaced existing SSH config entry." Yellow
            } else {
                Write-Color "Skipping SSH config update" Yellow
                continue
            }
        }
    }
    
    if (-not (Test-Path $keyPrivate)) {
        # Email validation
        do {
            $email = Read-Host "${EMOJI_LOCK} Enter GitHub email for '$account'"
            if ($email -match '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$') {
                break
            } else {
                Write-Color "Invalid email format! Must be valid email address" Red
            }
        } while ($true)
        
        Write-Color "Generating ED25519 SSH key..." White
        Show-Spinner "Generating key (this may take a moment)..." 15
        $keygenOutput = ssh-keygen -t ed25519 -f "$keyPrivate" -N "" -C "$email" 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Color "${EMOJI_ERROR} Key generation failed. Output: $keygenOutput" Red
            Write-Color "Ensure OpenSSH supports ED25519 and try again (fallback to rsa if needed)." Yellow
            exit 1
        }
        
        # Add to JSON
        Add-AccountToJson $account $email $keyPrivate $keyPublic
        
        # SSH config
        $configEntry = @"
Host github-$accountClean
  HostName github.com
  User git
  IdentityFile $keyPrivate

"@
        Add-Content -Path $CONFIG -Value $configEntry -Encoding UTF8
    }
    
    # Enhanced workflow with box art (translated to PS)
    Write-Host "`n" -NoNewline
    Write-Host "╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
    Write-Host "║                ${EMOJI_GITHUB} GITHUB SSH KEY SETUP ${EMOJI_GITHUB}                          ║" -ForegroundColor Magenta
    Write-Host "╚══════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Magenta
    
    Write-Color "${EMOJI_KEY} SSH Key copied to clipboard! ${EMOJI_CLIPBOARD}" Yellow
    Write-Color "Follow these steps EXACTLY:`n" White
    
    Write-Emoji $EMOJI_GITHUB "Step 1: Open GitHub.com in your browser" Cyan
    Write-Host "         (Browser will open automatically in 3 seconds)" -ForegroundColor Yellow
    
    Start-Sleep -Seconds 3
    
    Write-Emoji $EMOJI_GITHUB "Step 2: Go to Settings → SSH and GPG keys → New SSH key" Cyan
    
    Write-Emoji $EMOJI_GITHUB "Step 3: Paste the key below and give it a title" Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
    Get-Content $keyPublic
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
    
    Write-Emoji $EMOJI_GITHUB "Step 4: IMPORTANT: Log OUT of GitHub completely!" Cyan
    Write-Host "         This step is crucial for verification to work" -ForegroundColor Red
    
    # Copy to clipboard
    Get-Content $keyPublic | Set-Clipboard
    Write-Emoji $EMOJI_CHECK "Key copied to clipboard automatically!" Green
    
    # Open browser
    Start-Process "https://github.com/settings/ssh/new"
    
    Read-Host "${EMOJI_CLOCK} Press Enter AFTER completing ALL 4 steps above"
    
    # Verification (simplified, direct like bash v2)
    Write-Color "Testing SSH connection... (This may take up to 30 seconds)" Cyan
    Show-Spinner "Verifying connection..." 30
    $output = ssh -T git@github-$accountClean 2>&1
    if ($output -match "successfully authenticated") {
        Write-Color "SUCCESS! SSH connection verified for $account" Green
        Write-Color "You can now use: git@github-$accountClean:your-repo.git" Cyan
    } else {
        Write-Color "Verification failed for $account" Red
        Write-Color "Possible issues:" Yellow
        Write-Color "  • Did you complete all 4 steps above?" Yellow
        Write-Color "  • Did you log OUT of GitHub completely?" Yellow
        Write-Color "  • Check if the key was added correctly in GitHub settings" Yellow
        Write-Color "  • Try running: ssh -T git@github-$accountClean" Cyan
    }
}

Write-Emoji $EMOJI_PARTY "Setup complete!" Green
Write-Color "Restart PowerShell or refresh your environment (close and reopen terminal)." White
Write-Color "To add SSH keys to repos, use: .\\repo\\create_repo_account.ps1 (or bash equivalent in Git Bash)." White
Write-Color "To validate setup, run: .\\utils\\validate_setup.ps1 (or bash equivalent)." White