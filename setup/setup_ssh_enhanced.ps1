# Enhanced GitHub SSH Setup v1.0
$GITHUB_DIR = "$env:USERPROFILE\.ssh\github"
$CONFIG = "$GITHUB_DIR\config"
$ACCOUNTS_JSON = "$GITHUB_DIR\accounts.json"

# Initialize environment
New-Item -Path $GITHUB_DIR -ItemType Directory -Force
if (-not (Test-Path $ACCOUNTS_JSON)) { "[]" | Out-File $ACCOUNTS_JSON }

# Ensure main config includes our settings
$MAIN_CONFIG = "$env:USERPROFILE\.ssh\config"
if (-not (Select-String -Path $MAIN_CONFIG -Pattern "Include github\\config")) {
    "`nInclude github\config" | Add-Content $MAIN_CONFIG
}

$accounts = (Read-Host "Enter GitHub account aliases (comma-separated)") -split ',' | ForEach-Object { $_.Trim() }

foreach ($account in $accounts) {
    $accountClean = $account -replace '[^a-zA-Z0-9]', '_'
    $keyPath = "$GITHUB_DIR\github_$accountClean"

    # Check existing registrations
    $currentAccounts = [System.Collections.ArrayList]@(Get-Content $ACCOUNTS_JSON | ConvertFrom-Json)
    $existing = $currentAccounts | Where-Object { $_.account -eq $account }
    
    if ($existing) {
        Write-Host "⚠️  Account '$account' exists!"
        $choice = Read-Host "Overwrite/Keep/Both? (o/k/b) [k]"
        switch ($choice.ToLower()) {
            'o' {
                Write-Host "Removing existing..."
                $null = $currentAccounts.Remove($existing)
                Remove-Item $existing.private_key -ErrorAction SilentlyContinue
                Remove-Item $existing.public_key -ErrorAction SilentlyContinue
            }
            'b' { 
                $accountClean += "_$(Get-Date -Format yyyyMMdd)"
                $keyPath = "$GITHUB_DIR\github_$accountClean"
                Write-Host "Using new path: $keyPath"
            }
            default {
                Write-Host "Skipping..."
                continue
            }
        }
    }

    # Generate new keys if needed
    if (-not (Test-Path $keyPath)) {
        ssh-keygen -t ed25519 -f $keyPath -N '""' -C $account
        $accountData = @{
            account = $account
            private_key = $keyPath
            public_key = "$keyPath.pub"
            created = (Get-Date -Format o)
        }
        $currentAccounts.Add($accountData) | Out-Null
        $currentAccounts | ConvertTo-Json -Depth 3 | Out-File $ACCOUNTS_JSON
    }

    # Update SSH config
    $hostEntry = "Host github-$accountClean"
    if (-not (Select-String -Path $CONFIG -Pattern "^$hostEntry")) {
        Add-Content -Path $CONFIG -Value @"
Host github-$accountClean
  HostName github.com
  User git
  IdentityFile $keyPath

"@
    }

    # User workflow
    Write-Host "Public key (copied to clipboard):"
    Get-Content "$keyPath.pub" | Set-Clipboard
    Get-Content "$keyPath.pub"
    Start-Process "https://github.com/settings/ssh/new"
    Read-Host "Press Enter after adding key AND logging out"

    # Verify connection
    try {
        $output = ssh -T git@github-$accountClean 2>&1
        if ($output -match "successfully authenticated") {
            Write-Host "✅ Verified!"
        } else {
            Write-Host "❌ Verification failed: $output"
        }
    } catch {
        Write-Host "🚨 Connection error: $_"
    }
}

Write-Host "`nSetup complete. Validate with: ssh -T git@github-<account>"
