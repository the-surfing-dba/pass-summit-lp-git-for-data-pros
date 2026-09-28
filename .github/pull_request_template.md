<!--
  Pull request template — GitHub auto-loads this into the PR description box.
  Demo point: open a PR in VS Code / on GitHub and this text appears for free.
-->

## What does this change?

<!-- One or two sentences. What script/object/infra changed and why. -->

## Type of change

- [ ] New script (SQL / PowerShell / mongosh)
- [ ] Bug fix
- [ ] Schema / migration change
- [ ] Infrastructure (Terraform)
- [ ] Docs / non-code

## Target environment

- [ ] Dev
- [ ] Test
- [ ] Prod  ← requires a second reviewer

## Safety checklist (data-team specific)

- [ ] No secrets, connection strings, or passwords committed
- [ ] Destructive statements (`DROP`, `TRUNCATE`, `DELETE` without `WHERE`) are intentional and called out below
- [ ] Migration is idempotent / re-runnable, or a rollback is included
- [ ] Ran locally against a non-prod copy
- [ ] `terraform plan` reviewed (if infra changed)

## Rollback plan

<!-- How do we undo this if it goes sideways in prod? -->

## Related issue

<!-- e.g. Closes #123 -->
