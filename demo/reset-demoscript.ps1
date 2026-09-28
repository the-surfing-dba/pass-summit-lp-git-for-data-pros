<#
    reset-demoscript.ps1  —  put the repo back to a clean state after a run of
    git-struggles-walkthrough.ps1.

    Safe to run at ANY point in the demo, including a partial run that died
    mid-merge-conflict or left a stray commit on main. It:
      * aborts any in-progress merge/rebase/cherry-pick
      * switches to main and hard-resets it to origin/main
      * realigns the remote 'prerelease' branch back to main
      * closes ALL open PRs (feature->prerelease and promote PRs the cascade opens)
      * deletes ALL remote branches except the keep-list (main + prerelease)
      * deletes the local demo branches (struggle1, struggle2, bigfile, conflict-*, pr-ui)
      * removes the demo-* / demo.credential scratch files at the repo root

    It will REFUSE to run unless origin points at this demo repo, so a stray
    hard-reset can't nuke an unrelated checkout.

    Run it whole (F5 / "Run"), not line-by-line — this one is meant to just go.
#>

$ErrorActionPreference = 'Stop'
$RepoSlug = 'pass-summit-lp-git-for-data-pros'
$KeepBranches = @('main', 'prerelease')   # remote branches this script NEVER deletes
$DemoBranches = @('struggle1', 'struggle2', 'bigfile', 'conflict-base', 'conflict-a', 'conflict-b', 'pr-ui')

# --- Move to the repo root (works no matter where you invoke it from) --------
$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot)
    {
        Write-Error "Not inside a git working tree. cd into the repo and re-run."
        return
    }  # end if (-not $repoRoot)
Set-Location $repoRoot

# --- Safety guard: only ever touch THIS repo ---------------------------------
$originUrl = git config --get remote.origin.url
if ($originUrl -notmatch [regex]::Escape($RepoSlug))
    {
        Write-Error "origin ($originUrl) is not '$RepoSlug'. Refusing to reset — wrong repo."
        return
    }  # end if (wrong repo)

Write-Host "Resetting demo state in $repoRoot" -ForegroundColor Cyan

# --- 1. Abort anything in-progress (struggle 4 can leave a live conflict) -----
$gitDir = git rev-parse --git-dir
if (Test-Path (Join-Path $gitDir 'MERGE_HEAD'))
    {
        Write-Host "  aborting in-progress merge" -ForegroundColor Yellow
        git merge --abort
    }  # end if (merge in progress)
if (Test-Path (Join-Path $gitDir 'CHERRY_PICK_HEAD'))
    {
        Write-Host "  aborting in-progress cherry-pick" -ForegroundColor Yellow
        git cherry-pick --abort
    }  # end if (cherry-pick in progress)
if ((Test-Path (Join-Path $gitDir 'rebase-merge')) -or (Test-Path (Join-Path $gitDir 'rebase-apply')))
    {
        Write-Host "  aborting in-progress rebase" -ForegroundColor Yellow
        git rebase --abort
    }  # end if (rebase in progress)

# --- 2. Land on main and reset it to the remote ------------------------------
git switch main 2>$null
git fetch --prune origin
git reset --hard origin/main
Write-Host "  main reset to origin/main" -ForegroundColor Green

# --- 2b. Realign the remote prerelease branch back to main -------------------
#     prerelease allows force-push for exactly this; keeps the cascade's start
#     point clean so the next feature->prerelease PR opens against a fresh base.
git push origin "origin/main:refs/heads/prerelease" --force 2>$null
Write-Host "  prerelease realigned to main" -ForegroundColor Green

# --- 3. Close ALL open PRs (the cascade opens bot PRs into prerelease + main) -
if (Get-Command gh -ErrorAction SilentlyContinue)
    {
        $openPrs = gh pr list --state open --json number,headRefName | ConvertFrom-Json
        foreach ($pr in $openPrs)
            {
                Write-Host "  closing PR #$($pr.number) ($($pr.headRefName))" -ForegroundColor Yellow
                gh pr close $pr.number 2>$null
            }  # end foreach (open PR)
    }
else
    {
        Write-Host "  gh not found — skipping PR close (delete branches manually if any)" -ForegroundColor DarkYellow
    }  # end if (gh available)

# --- 4. Delete ALL remote branches except the keep-list ----------------------
git fetch --prune origin
$remoteBranches = git branch -r |
    Where-Object { $_ -notmatch '->' } |                       # skip 'origin/HEAD -> origin/main'
    ForEach-Object { ($_ -replace '^\s*origin/', '').Trim() } |
    Where-Object { $_ -and ($_ -notin $KeepBranches) }
foreach ($b in $remoteBranches)
    {
        Write-Host "  deleting remote branch $b" -ForegroundColor Yellow
        git push origin --delete $b 2>$null   # protected main will refuse — harmless
    }  # end foreach (remote branch)

# --- 5. Delete local demo branches (by name) ---------------------------------
foreach ($b in $DemoBranches)
    {
        if (git branch --list $b)
            {
                Write-Host "  deleting local branch $b" -ForegroundColor Yellow
                git branch -D $b 2>$null
            }  # end if (branch exists)
    }  # end foreach (demo branch)

# --- 6. Remove scratch files (repo root only, demo-* / demo.credential) ------
$scratch = @(
    'demo-query.sql', 'demo-import.sql', 'demo.credential', 'demo-backup.bak',
    'demo-huge.bak', 'demo-grants.sql', 'demo-pr.sql'
)
Remove-Item -Path $scratch -Force -ErrorAction SilentlyContinue
# belt-and-suspenders: any stray demo-*.sql / demo-*.bak left at the root
Get-ChildItem -File -Path . -Filter 'demo-*' -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -in '.sql', '.bak', '.credential' } |
    Remove-Item -Force -ErrorAction SilentlyContinue

Write-Host "Reset complete." -ForegroundColor Cyan
git switch main 2>$null
git status
