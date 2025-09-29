# Windows Validation Script
$GITHUB_DIR = "$env:USERPROFILE\.ssh\github"
$ACCOUNTS_JSON = "$GITHUB_DIR\accounts.json"

Write-Host "=== SSH Config ==="
Get-Content "$GITHUB_DIR\config"

Write-Host "`n=== Account Registry ==="
Get-Content $ACCOUNTS_JSON | ConvertFrom-Json | Format-Table

Write-Host "`n=== Connection Tests ==="
$accounts = Get-Content $ACCOUNTS_JSON | ConvertFrom-Json
foreach ($acc in $accounts) {
    $hostname = "github-$($acc.account -replace ' ','_')"
    Write-Host -NoNewline "$($acc.account): "
    try {
        $output = ssh -T git@$hostname 2>&1
        if ($output -match "successfully authenticated") {
            Write-Host "✅ OK" -ForegroundColor Green
        } else {
            Write-Host "❌ FAIL ($output)" -ForegroundColor Red
        }
    } catch {
        Write-Host "❌ ERROR ($_)" -ForegroundColor Red
    }
}
