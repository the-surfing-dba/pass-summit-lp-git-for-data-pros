<#
    Apply-BranchProtection — lock down the demo repo's release branches using the
    GitHub REST API via `gh`. Run it LIVE on stage to show how one approval on
    `prerelease` cascades to `main` (see the workflows in .github/workflows/).

    What it enforces:
      main:
        - Pull request required before merge (no direct pushes).
        - The gitleaks secret-scan status check must pass.
        - 0 approvals — the single human review already happened at prerelease.
        - No force-pushes, no deletion.
      prerelease:
        - Pull request required before merge, with 1 approving review — the one
          human gate the cascade fans out from.
        - Force-push + deletion allowed so demo/reset-demoscript.ps1 can realign
          it back to main.

    Requires: gh CLI, authenticated with `gh auth login` and repo admin rights.
    The check name(s) must match the `name:` of the required job in
    .github/workflows/ci.yml — that string IS the status-check context.
#>

[CmdletBinding(SupportsShouldProcess)]
param
    (
        [string] $Repo   = 'the-surfing-dba/pass-summit-lp-git-for-data-pros',

        # Must match the `name:` of the required job in ci.yml. Only gitleaks is
        # a REQUIRED check on main — the lint jobs run but don't gate the merge.
        [string[]] $RequiredChecks = @(
            'Secret scan (gitleaks)'
        )
    )

# Fail fast if gh isn't available or authenticated.
if (-not (Get-Command gh -ErrorAction SilentlyContinue))
    {
        throw "gh CLI not found. Install it: https://cli.github.com/"
    }  # end if (gh missing)

<#######################################
 #######################################
   Build the per-branch protection payloads
 #######################################
 #######################################>
# main: require a PR + the gitleaks check, but 0 approvals — the review already
#       happened at the prerelease gate and cascaded here.
$mainBody = [ordered]@{
    required_status_checks = [ordered]@{
        strict   = $false         # up-to-date not required (prerelease descends from main)
        contexts = $RequiredChecks
    }
    enforce_admins = $false       # admins can still bootstrap/repair
    required_pull_request_reviews = [ordered]@{
        dismiss_stale_reviews           = $false
        require_code_owner_reviews      = $false
        required_approving_review_count = 0
    }
    restrictions       = $null
    allow_force_pushes = $false
    allow_deletions    = $false
}

# prerelease: the single human gate — a PR + 1 approval. Force-push/delete stay
#             open so the reset script can realign it back to main.
$preBody = [ordered]@{
    required_status_checks = $null
    enforce_admins = $false
    required_pull_request_reviews = [ordered]@{
        dismiss_stale_reviews           = $false
        require_code_owner_reviews      = $false
        required_approving_review_count = 1
    }
    restrictions       = $null
    allow_force_pushes = $true
    allow_deletions    = $true
}

<#######################################
 #######################################
   Apply it to both branches
 #######################################
 #######################################>
$targets = @(
    [pscustomobject]@{ Branch = 'main';       Body = $mainBody },
    [pscustomobject]@{ Branch = 'prerelease'; Body = $preBody }
)

foreach ($t in $targets)
    {
        $json = $t.Body | ConvertTo-Json -Depth 6
        if ($PSCmdlet.ShouldProcess("$Repo@$($t.Branch)", "Apply branch protection"))
            {
                try
                    {
                        $json | gh api `
                            --method PUT `
                            -H "Accept: application/vnd.github+json" `
                            "repos/$Repo/branches/$($t.Branch)/protection" `
                            --input -
                        Write-Host "Branch protection applied to $Repo@$($t.Branch)." -ForegroundColor Green
                    }
                catch
                    {
                        Write-Error "Failed to apply branch protection to $($t.Branch): $($_.Exception.Message)"
                        throw
                    }  # end try/catch (apply $($t.Branch))
            }  # end if (ShouldProcess $($t.Branch))
    }  # end foreach (target)

<#######################################
 #######################################
   Show the result
 #######################################
 #######################################>
foreach ($b in 'main', 'prerelease')
    {
        Write-Host "`nCurrent protection on ${b}:" -ForegroundColor Cyan
        gh api "repos/$Repo/branches/$b/protection" `
            --jq '{required_reviews: .required_pull_request_reviews.required_approving_review_count, checks: .required_status_checks.contexts, strict: .required_status_checks.strict, force_pushes: .allow_force_pushes.enabled}'
    }  # end foreach (show)
