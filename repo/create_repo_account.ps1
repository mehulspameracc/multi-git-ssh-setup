# PowerShell Repo Account Setup v0.2
$githubDir = "$env:USERPROFILE\.ssh\github"
$accounts = Get-Content "$githubDir\accounts.json" | ConvertFrom-Json

Write-Host "`n🔑 Select GitHub Account:`n"
$index = 1
$accounts | ForEach-Object {
    Write-Host "$index) $($_.account) ($($_.email))"
    $index++
}

$choice = Read-Host "`nEnter selection number"
$account = $accounts[$choice-1]

@"
GIT_NAME="$($account.account)"
GIT_EMAIL="$($account.email)"
SSH_KEY="$($account.private_key)"
"@ | Out-File .git-account -Encoding utf8

Add-Content -Path .gitignore -Value "`n.git-account"
Write-Host "✅ Configured for $($account.account) ($($account.email))"
