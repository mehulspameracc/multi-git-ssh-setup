# Enhanced GitHub SSH Architecture v0.4

## accounts.json Schema
```json
{
  "account": "work",
  "email": "user@company.com",
  "private_key": "~/.ssh/github/github_work",
  "public_key": "~/.ssh/github/github_work.pub",
  "created_at": "2025-08-26T18:25:43Z",
  "last_used": "2025-08-26T18:30:15Z"
}
```

## Key Security Features
1. **Email Validation** - Enforced during key generation
2. **Audit Trails** - Timestamped account activity tracking
3. **Isolated Storage** - Keys never leave ~/.ssh/github
4. **Auto-Expiry** - Optional key rotation via last_used dates

## UI Design
```mermaid
graph TD
    A[Numbered Menu] --> B[Email Display]
    B --> C[Repo Configuration]
    C --> D[Auto-gitignore]
