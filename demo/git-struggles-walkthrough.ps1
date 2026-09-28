<#
    git-struggles-walkthrough.ps1  —  a STEP-THROUGH demo of the top 5 things
    new GitHub users struggle with, plus a 6th section on creating & reviewing
    a pull request in the UI. This is NOT meant to be run all at once.

    HOW TO DRIVE IT LIVE (VS Code + PowerShell extension):
      * Open this file. Put the cursor on a command line and press F8
        ("Run Selection") to send just that line to the terminal.
      * Step through ONE command at a time. 
      * Runs against THIS repo using throwaway demo/* branches and demo-*
        scratch files. The CLEANUP region at the bottom removes all of it.

    Start from the repo root:
      cd /Users/michael.dspain/Documents/PASS/pass-summit-lp-git-for-data-pros
#>

# Sanity check — start clean on main before you begin.
git switch main
git status                          # shows current branch, staged vs unstaged changes, and untracked files


#region  STRUGGLE 1  —  "Where did my changes go?"  (branch vs. working dir)
# ---------------------------------------------------------------------------
# CONCEPT: saving a file is NOT the same as it being in Git. A commit is a
#          snapshot that lives ON A BRANCH.

git switch -c demo/struggle1
# OR the older syntax (same result):  git checkout -b demo/struggle1
# OR in two steps:  git branch demo/struggle1  then  git switch demo/struggle1

Set-Content -Path demo-query.sql -Value 'SELECT * FROM customers;'

# Three states: working dir -> staged -> committed
git status -s                       # '??' = UNTRACKED (new file Git isn't watching); 'M' = MODIFIED (tracked file changed, not yet staged)
git add demo-query.sql
git status -s                       # now STAGED (green 'A') — not committed yet
git commit -m 'demo: add customer query'
git log --oneline -1                # show commit history; --oneline = one line per commit (short hash + message), -1 = just the latest

# The panic: switch away and the file "disappears"
git switch main
git status -s                       # clean — demo-query.sql is not here
Get-ChildItem demo-query.sql -ErrorAction SilentlyContinue   # nothing on main

# FIX: it was never lost. It lives on the branch. Switch back to it:
git switch demo/struggle1
Get-ChildItem demo-query.sql        # it's back
git reflog -5                       # local history of everywhere HEAD has been (switch/commit/reset/merge); your safety net for recovering "lost" commits, -5 = last 5 moves

# LESSON: run  git branch --show-current  BEFORE you commit.
#endregion


#region  STRUGGLE 2  —  git add .  sweeps in junk (big files / secrets)
# ---------------------------------------------------------------------------
# CONCEPT: `git add .` stages EVERYTHING untracked. This is how a secret or a
#          219 MB binary sneaks into a commit.

git switch main
git switch -c demo/struggle2

# The file you WANT...
Set-Content -Path demo-import.sql -Value '-- real work here'
# ...plus junk you do NOT: a leaked GitHub personal access token (PAT) + a 5 MB "backup"
Set-Content -Path demo.credential -Value 'GITHUB_TOKEN=ghp_FAKEdemoTOKENdoNOTuse0123456789abcde'   # fake PAT — the hook blocks it by FILENAME (*.credential), not by reading this value
$bytes = [byte[]]::new(5 * 1024 * 1024)
(New-Object Random).NextBytes($bytes)
[System.IO.File]::WriteAllBytes("$PWD/demo-backup.bak", $bytes)

# THE MISTAKE, on purpose: gut the .gitignore so it no longer excludes secrets/
# backups (simulates a repo with no .gitignore, or one someone "cleaned up").
# Strip the *.credential and *.bak rules:
(Get-Content .gitignore) | Where-Object { $_ -notin '*.credential', '*.bak' } | Set-Content .gitignore
git check-ignore -v demo.credential demo-backup.bak   # NO output now = nothing is protecting them

# git add .  now sweeps in EVERYTHING untracked — secret included:
git add .
git status -s                        # -s = short format: one line per file with a two-letter code (XY)
# ^ demo.credential and demo-backup.bak are STAGED ('A') next to your real file.

# NOW TRY TO COMMIT — and watch it FAIL. git itself never blocks a commit over a
# secret (a commit is purely local), so the guardrail is a pre-commit HOOK:
# .githooks/pre-commit inspects the staged files and rejects credentials + big
# blobs — even though we just gutted .gitignore. Activate it once per clone:
#     git config core.hooksPath .githooks
git commit -m 'demo: add import tool'
# ^ REJECTED by the hook (exit code 1 — nothing gets committed):
#     BLOCKED (large file): demo-backup.bak  — 5242880 bytes (> 1048576); keep binaries out of git.
#     BLOCKED (secret):     demo.credential  — looks like a credential file; do not commit it.
#     Commit REJECTED by .githooks/pre-commit.

# FIX: unstage the junk (it stays on disk), restore .gitignore, commit the real file only.
git restore --staged demo.credential demo-backup.bak   # unstage the secret + big file
git checkout main -- .gitignore                        # bring back the real ignore rules
git status -s                                          # only demo-import.sql is staged now
git commit -m 'demo: add import tool'                  # hook passes -> commit SUCCEEDS
git show --stat HEAD                                   # only demo-import.sql is in the commit

# SECOND LINE OF DEFENSE — make the PUSH fail. The commit hook is CLIENT-SIDE and
# can be skipped with --no-verify. The pre-push hook (.githooks/pre-push) scans the
# COMMITS you're about to push and rejects the whole push. Watch it block:
git add -f demo.credential demo-backup.bak            # force past .gitignore again
git commit --no-verify -m 'sneak the secret past the commit hook'   # pre-commit SKIPPED -> commit succeeds
git push -u origin demo/struggle2                    # pre-push scans the commit and REJECTS:
# ^ BLOCKED (large file): demo-backup.bak  — 5242880 bytes (> 1048576) in a pushed commit.
#   BLOCKED (secret):     demo.credential  — credential file in a pushed commit; do not push it.
#   Push REJECTED by .githooks/pre-push.   (nothing reached the server)

# RECOVER: the secret is in your COMMIT, not just the working tree — rewrite it out:
git reset --soft HEAD~1                               # undo the --no-verify commit, keep changes staged
git restore --staged demo.credential demo-backup.bak # unstage the junk
git checkout main -- .gitignore                       # ignore rules back
#   (if it had already been PUSHED/shared: ROTATE the secret, then scrub with
#    git filter-repo / BFG — you cannot un-leak it.)

# WHY BOTH HOOKS + THE SERVER: pre-commit stops you early, pre-push stops a
# --no-verify bypass, and server-side guards (GitHub push protection -> GH013,
# ci.yml gitleaks) catch anyone who never ran  git config core.hooksPath .githooks .
#endregion


#region  STRUGGLE 3  —  decoding push rejections (against THIS repo's remote)
# ---------------------------------------------------------------------------

## 3a. PROTECTED MAIN — a direct push is blocked
git switch main
Set-Content -Path demo-hotfix.sql -Value '-- urgent fix'
git add demo-hotfix.sql
git commit -m 'demo: direct edit on main'
git push origin main
# ^ REJECTED:  remote: error: GH006: Protected branch update failed for refs/heads/main.
#              remote: error: Changes must be made through a pull request.
#   (Nothing reached the remote. Your local main just has an extra commit.)

# FIX: move that work onto a branch and push the BRANCH, then open a PR.
git switch -c demo/hotfix           # the commit comes with you onto the branch
git push -u origin demo/hotfix      # this push works — feature branches aren't protected
# put local main back exactly matching the remote (drops the demo commit off main):
git switch main
git reset --hard origin/main

## 3b. FILE TOO BIG — GitHub hard-rejects anything over 100 MB
git switch -c demo/bigfile
$bytes = [byte[]]::new(5 * 1024 * 1024)
(New-Object Random).NextBytes($bytes)
[System.IO.File]::WriteAllBytes("$PWD/demo-huge.bak", $bytes)
git add -f demo-huge.bak            # -f forces past .gitignore — exactly the mistake that bit you
git commit -m 'demo: oops, committed a backup'
# If you pushed a >100 MB file, GitHub answers with:
#   remote: error: File demo-huge.bak is 219.17 MB; this exceeds GitHub's file size limit of 100.00 MB
#   remote: error: GH001: Large files detected.
#
# FIX — pull the file OUT of the commit (it's only in the last, unpushed commit):
git rm --cached demo-huge.bak       # untrack it (the file stays on disk)
git commit --amend -m 'demo: backup script (no binary)'
git status -s                       # demo-huge.bak is now untracked + ignored
git ls-tree -r -l HEAD              # confirm no big blob remains in the commit
#endregion


#region  STRUGGLE 4  —  merge conflicts (throwaway branches, this repo)
# ---------------------------------------------------------------------------
# CONCEPT: when two branches change the SAME line, Git can't choose. That's a
#          conflict — normal, not corruption.

git switch main
git switch -c demo/conflict-base
Set-Content -Path demo-grants.sql -Value 'GRANT SELECT ON dbo.customers TO analyst;'
git add demo-grants.sql
git commit -m 'demo: base grant'

# Branch A changes the line
git switch -c demo/conflict-a
Set-Content -Path demo-grants.sql -Value 'GRANT SELECT ON dbo.customers TO reader_role;'
git commit -am 'demo: grant reader_role'

# Branch B changes the SAME line differently
git switch demo/conflict-base
git switch -c demo/conflict-b
Set-Content -Path demo-grants.sql -Value 'GRANT SELECT, INSERT ON dbo.customers TO writer_role;'
git commit -am 'demo: grant writer_role'

# Merge A into B -> CONFLICT
git merge demo/conflict-a --no-edit
# ^ CONFLICT (content): Merge conflict in demo-grants.sql
git status -s                       # 'UU' = both sides changed this file
Get-Content demo-grants.sql         # see the <<<<<<< ======= >>>>>>> markers
# <<<<<<< HEAD is YOUR branch's version; >>>>>>> is the incoming branch's version.

# FIX: edit the file to the single line you actually want (delete ALL the
#      marker lines), then stage + commit:
Set-Content -Path demo-grants.sql -Value 'GRANT SELECT, INSERT ON dbo.customers TO reader_role, writer_role;'
git add demo-grants.sql
git commit --no-edit
Get-Content demo-grants.sql         # clean, resolved

# ESCAPE HATCH: if you panic MID-conflict, bail out completely with:
#   git merge --abort               # returns you to the pre-merge state, no harm done
#endregion


#region  STRUGGLE 5  —  PRs & base branches (inspect THIS repo's real PRs)
# ---------------------------------------------------------------------------
# CONCEPT: a PR merges HEAD (your branch) INTO a BASE branch. CI filters
#          usually key off the BASE. Wrong base => checks never run.

gh pr list --state open
gh pr view 8 --json number,baseRefName,headRefName,mergeStateStatus,statusCheckRollup
# ^ PR #8's base was 'prerelease', not 'main'. ci.yml only runs on PRs to main
#   (on: pull_request: branches: [main]) — so #8 shows "no checks reported"
#   even though it's perfectly MERGEABLE.

# FIX / how to avoid it: open the PR against the RIGHT base branch.
#   gh pr create --base main --head <your-branch> --fill
# Diagnosing a "stuck" PR — check its base and merge state first:
#   gh pr view <n> --json baseRefName,mergeStateStatus,statusCheckRollup
#endregion


#region  STRUGGLE 6  —  creating & reviewing a PR in the UI (VS Code + github.com)
# ---------------------------------------------------------------------------
# CONCEPT: the whole point of a branch is to propose it back via a Pull Request.
#          Most of this is CLICKING, not typing — the commands below just get
#          you to the UI. Read the # steps as your narration.

# First, make a small change on a branch and push it (so there's something to PR):
git switch main
git switch -c demo/pr-ui
Set-Content -Path demo-pr.sql -Value 'SELECT GETDATE() AS demo_run;'
git add demo-pr.sql
git commit -m 'demo: add PR-UI sample query'
git push -u origin demo/pr-ui

## OPTION A — open the PR from the terminal, straight into the browser UI:
gh pr create --base main --head demo/pr-ui --web
#   The browser opens the "Open a pull request" page. Walk the audience through:
#     1. BASE vs COMPARE at the top — base = main (where it lands),
#        compare = demo/pr-ui (your branch). This is the #1 thing to get right.
#     2. The description box is PRE-FILLED from .github/pull_request_template.md
#        (the safety checklist). Point out it appeared for free.
#     3. Click "Create pull request".
#     4. Reviewers panel auto-requests the owner from .github/CODEOWNERS.
#     5. The "Checks" section shows the ci.yml jobs running (secret scan, lint...).
#     6. "Files changed" tab — this is where a reviewer comments line-by-line
#        and clicks "Review changes" -> Approve / Request changes.
#     7. Once green + approved, the "Squash and merge" button lights up.
#        Click it, then "Delete branch".

## OPTION B — do it entirely inside VS Code (GitHub Pull Requests extension):
#     1. Open the "GitHub" view in the Activity Bar (or Source Control panel).
#     2. Click "Create Pull Request". Pick base = main, compare = demo/pr-ui.
#     3. The template fills the description; click "Create".
#     4. The PR opens IN the editor: Description, Commits, Checks, Files tabs.
#     5. Review files in the diff, add comments, then "Merge" -> "Squash".
#   No context-switch to the browser — good for people who live in VS Code.

# Reviewing SOMEONE ELSE'S PR locally (so you can actually run their code):
#   gh pr checkout <number>     # checks out their branch into your working tree
#   ...test it, run the script...
#   gh pr review <number> --approve -b 'LGTM, tested locally'
#endregion


#region  BONUS  —  visualizing history: the commit graph (CLI + UI)
# ---------------------------------------------------------------------------
# CONCEPT: branches and merges are hard to reason about as a flat list. A GRAPH
#          shows how commits connect — where branches split and where they merged
#          back. Read-only: nothing below changes the repo.

## COMMAND LINE — git log --graph
git --no-pager log --graph --oneline --all --decorate -20
#   --graph     draws the ASCII branch/merge lines on the left
#   --oneline   one commit per line (short hash + subject)
#   --all       every branch, not just the one you're on
#   --decorate  show branch/tag/HEAD labels (on by default in modern git)
#   -20         cap at 20 commits so it fits on screen
#   (dropped 'git --no-pager' opens the pager 'less' — press q to quit, / to search)

# A richer, colorized one-liner worth aliasing (call it 'git lg'):
git --no-pager log --graph --all --decorate `
    --pretty=format:'%C(auto)%h%d %s %C(dim)(%an, %ar)%C(reset)' -20
# Make it permanent so you just type  git lg :
#   git config --global alias.lg "log --graph --all --decorate --pretty=format:'%C(auto)%h%d %s %C(dim)(%an, %ar)%C(reset)'"

# Contrast: the graph shows COMMITS; the reflog shows every MOVE of HEAD
# (switch/commit/reset/merge) — your local audit trail, even for "lost" commits:
git --no-pager reflog -15

## IN THE UI — three ways, no terminal
#   1. BUILT-IN (no extension): open Source Control (Ctrl/Cmd+Shift+G). The
#      "Source Control Graph" section renders the branch/merge graph; click a
#      commit to see its diff. If hidden: SCM title-bar ... menu -> enable Graph.
#   2. GIT GRAPH extension (mhutchie.git-graph): adds a "Git Graph" button in the
#      Source Control title bar -> full interactive railroad graph; right-click a
#      commit to checkout / branch / revert / cherry-pick.
#   3. GITLENS extension: "Commit Graph" view with author lanes, search, and
#      rich hovers showing who/when/why for each commit.
# TALK TIP: run the CLI graph first (works anywhere, even over SSH), then flip to
#           the UI graph for the same history — same data, prettier picture.
#endregion


#region  CLEANUP  —  remove everything this demo created
# ---------------------------------------------------------------------------
git switch main

# close the demo PR (if you opened one in struggle 6) and delete its remote branch
gh pr close demo/pr-ui --delete-branch

# delete the pushed demo branch from struggle 3a
git push origin --delete demo/hotfix

# delete local demo branches (‑D because some hold un-merged demo commits)
git branch -D demo/struggle1 demo/struggle2 demo/hotfix demo/bigfile demo/conflict-base demo/conflict-a demo/conflict-b demo/pr-ui

# remove the scratch files (all uniquely named demo-* / demo.credential)
Remove-Item demo-query.sql, demo-import.sql, demo.credential, demo-backup.bak, demo-hotfix.sql, demo-huge.bak, demo-grants.sql, demo-pr.sql -ErrorAction SilentlyContinue

git status                          # back to clean
#endregion
