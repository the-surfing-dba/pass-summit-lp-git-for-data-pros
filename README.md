# pass-summit-lp-git-for-data-pros

[![ci](https://github.com/the-surfing-dba/pass-summit-lp-git-for-data-pros/actions/workflows/ci.yml/badge.svg)](https://github.com/the-surfing-dba/pass-summit-lp-git-for-data-pros/actions/workflows/ci.yml)

Demo repository for the PASS Data Summit session **"A Git Journey: from Foundations to Automation for Data Professionals."**

It holds the scripts, commands, and supporting assets used in the talk. The
sample scripts are deliberately realistic DBA/data work (backups, orphaned
users, grants, Mongo queries, AG sync) so the Git workflow demos —
branching, merge conflicts, secrets, pull requests, CI/CD, and branch
protection — land on code data professionals actually recognize.

> Some scripts contain intentional teaching anti-patterns (e.g. a hardcoded
> password) used to demonstrate what *not* to commit. See
> [Secrets](#secrets) below. Nothing here is meant for production as-is.

## Repository layout

| Path                                          | What's in it                                                                 |
| --------------------------------------------- | ---------------------------------------------------------------------------- |
| `sqlserver/`                                  | T-SQL scripts (backups, orphaned-user cleanup, PR demo scratch file)         |
| `mysql/`                                       | MySQL admin scripts                                                           |
| `mongo/`                                       | `mongosh` query scripts                                                       |
| `powershell/`                                  | dbatools / Az automation scripts                                             |
| `terraform/`                                   | Azure SQL infra as code — the "high blast-radius change" demo                 |
| `secrets/`                                     | The *right* way to handle credentials (vs. the hardcoded anti-pattern)       |
| `.github/`                                     | CI workflow, PR template, CODEOWNERS, branch-protection script               |

## Scripts by folder

### `sqlserver/`

| File                                          | Purpose                                                                       |
| --------------------------------------------- | ---------------------------------------------------------------------------- |
| `backup-yomomma.sql`                          | Striped, compressed, checksummed FULL backup + `RESTORE VERIFYONLY`          |
| `orphanedusers.sql`                           | Report orphaned DB users, auto-relink to logins, emit `CREATE LOGIN` scaffolding |
| `testpr.sql`                                  | Empty scratch file for the "open your first pull request" demo               |

### `mysql/`

| File                                          | Purpose                                                                       |
| --------------------------------------------- | ---------------------------------------------------------------------------- |
| `grant-all-michael-dspain.sql`                | Creates a user + grants — **intentionally hardcodes a password** for the secrets demo |

### `mongo/`

| File                                          | Purpose                                                                       |
| --------------------------------------------- | ---------------------------------------------------------------------------- |
| `query-customers.js`                          | `mongosh` script: counts, filtered finds, and an aggregation on `customers`  |

### `powershell/`

| File                                          | Purpose                                                                       |
| --------------------------------------------- | ---------------------------------------------------------------------------- |
| `Sync-AG-githublearningpath.ps1`              | Syncs instance-level objects across an Availability Group with dbatools       |

### `terraform/`

An Azure SQL Server + Database defined as code. `terraform validate` runs in
CI and needs **no** cloud credentials. Change `sku_name` in a branch to
demo an infra pull request that CODEOWNERS gates.

| File                                          | Purpose                                                                       |
| --------------------------------------------- | ---------------------------------------------------------------------------- |
| `main.tf`                                      | Resource group, SQL server, database, firewall rule                          |
| `variables.tf`                                 | Inputs; `sql_admin_password` is `sensitive` and comes from an env var        |
| `outputs.tf`                                   | Server FQDN, DB name, connection string (password omitted)                   |
| `terraform.tfvars.example`                     | Copy to `terraform.tfvars` (gitignored) and fill in                          |

### `secrets/`

| File                                          | Purpose                                                                       |
| --------------------------------------------- | ---------------------------------------------------------------------------- |
| `.env.example`                                 | Committable template showing *which* env vars exist — no real values         |
| `Get-DbSecret.ps1`                             | Fetch a credential from Azure Key Vault (fallback: env var); never hardcoded  |

## Session demo assets (`.github/`)

| File                                          | Demonstrates                                                                  |
| --------------------------------------------- | ---------------------------------------------------------------------------- |
| `workflows/ci.yml`                             | CI on PR: secret scan + SQL/PowerShell/Terraform lint; disabled self-hosted deploy job |
| `pull_request_template.md`                     | Auto-filled PR body with a data-team safety checklist                        |
| `CODEOWNERS`                                   | Auto-requests reviewers; blocks merge on schema/infra without owner approval |
| `apply-branch-protection.ps1`                  | One command to lock down `main` via the `gh` CLI                             |

### CI pipeline

`ci.yml` runs on every pull request to `main` and on pushes to `main`:

1. **Secret scan** (gitleaks) — fails the PR if a credential was committed.
2. **SQL lint** (sqlfluff) — T-SQL + MySQL dialects.
3. **PowerShell lint** (PSScriptAnalyzer).
4. **Terraform** — `fmt -check` + `validate` (no Azure creds needed).
5. **Deploy** (disabled) — a `self-hosted` job that shows why cloud-hosted
   runners can't reach a private database. Flip its `if:` to enable.

> The `sql-lint` job ends with `|| true` so intentionally-messy demo scripts
> stay green. Remove that in a real repo so the check actually gates the PR.

## Getting started

Clone and inspect:

```powershell
git clone https://github.com/the-surfing-dba/pass-summit-lp-git-for-data-pros.git
cd pass-summit-lp-git-for-data-pros
```

Validate the Terraform locally (same as CI):

```powershell
cd terraform
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

Provide the SQL admin password via environment variable — never a committed
file:

```powershell
$env:TF_VAR_sql_admin_password = 'S0me-Str0ng-Pass!'
```

## Branch protection

Lock down `main` so pull requests, reviews, and passing CI are required
before merge:

```powershell
pwsh ./.github/apply-branch-protection.ps1
```

Requires the `gh` CLI, `gh auth login`, and admin rights on the repo. The
required status-check names in the script must match the `name:` of each job
in `ci.yml`.

## Branching model used in the demos

`main` is always deployable. Every change goes through a short-lived branch
and a pull request:

| Prefix        | Use                                        |
| ------------- | ------------------------------------------ |
| `feature/`    | New script or capability                   |
| `bugfix/`     | Fix to an existing script                  |
| `hotfix/`     | Urgent production fix                       |
| `experiment/` | Throwaway spike / tuning                    |

## Security note

This is a teaching repo. Passwords, IPs, and server names are placeholders or
intentional anti-patterns. Do not run these scripts against production without
review, and never commit real secrets — that's the whole point of the
`secrets/` and `.gitignore` demos.
