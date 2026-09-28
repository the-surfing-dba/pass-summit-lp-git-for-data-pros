<#
    Apply-BranchProtection — lock down `main` on the demo repo using the GitHub
    REST API via the `gh` CLI. Run this LIVE on stage to show how the CI jobs
    and CODEOWNERS turn into an enforced merge gate.

    What it enforces on `main`:
      - Pull request required before merge (no direct pushes).
      - 1 approving review, and a Code Owner review (uses .github/CODEOWNERS).
      - Stale approvals dismissed when new commits land.
      - Required status checks (the CI jobs) must pass and be up to date.
      - Rules also apply to admins (enforce_admins).
      - No force-pushes, no branch deletion.

    Requires: gh CLI, authenticated with `gh auth login` and repo admin rights.
    Verify the check names match the `name:` of each job in
    .github/workflows/ci.yml — those strings ARE the status check contexts.
#>

[CmdletBinding(SupportsShouldProcess)]
param
    (
        [string] $Repo   = 'the-surfing-dba/pass-summit-lp-git-for-data-pros',
        [string] $Branch = 'main',

        # Must match the `name:` of each required job in ci.yml.
        [string[]] $RequiredChecks = @(
            'Secret scan (gitleaks)',
            'SQL lint (sqlfluff)',
            'PowerShell lint (PSScriptAnalyzer)',
            'Terraform fmt + validate'
        )
    )

# Fail fast if gh isn't available or authenticated.
if (-not (Get-Command gh -ErrorAction SilentlyContinue))
    {
        throw "gh CLI not found. Install it: https://cli.github.com/"
    }  # end if (gh missing)

<#######################################
 #######################################
   Build the protection payload
 #######################################
 #######################################>
$body = [ordered]@{
    required_status_checks = [ordered]@{
        strict   = $true          # branch must be up to date before merge
        contexts = $RequiredChecks
    }
    enforce_admins = $true
    required_pull_request_reviews = [ordered]@{
        dismiss_stale_reviews           = $true
        require_code_owner_reviews      = $true
        required_approving_review_count = 1
    }
    restrictions          = $null # no user/team push allowlist
    allow_force_pushes    = $false
    allow_deletions       = $false
    required_linear_history = $true
}

$json = $body | ConvertTo-Json -Depth 6

<#######################################
 #######################################
   Apply it
 #######################################
 #######################################>
if ($PSCmdlet.ShouldProcess("$Repo@$Branch", "Apply branch protection"))
    {
        try
            {
                $json | gh api `
                    --method PUT `
                    -H "Accept: application/vnd.github+json" `
                    "repos/$Repo/branches/$Branch/protection" `
                    --input -
                Write-Host "Branch protection applied to $Repo@$Branch." -ForegroundColor Green
            }
        catch
            {
                Write-Error "Failed to apply branch protection: $($_.Exception.Message)"
                throw
            }  # end try/catch (apply)
    }  # end if (ShouldProcess)

<#######################################
 #######################################
   Show the result
 #######################################
 #######################################>
Write-Host "`nCurrent protection on ${Branch}:" -ForegroundColor Cyan
gh api "repos/$Repo/branches/$Branch/protection" `
    --jq '{required_reviews: .required_pull_request_reviews.required_approving_review_count, code_owner_reviews: .required_pull_request_reviews.require_code_owner_reviews, checks: .required_status_checks.contexts, enforce_admins: .enforce_admins.enabled}'
