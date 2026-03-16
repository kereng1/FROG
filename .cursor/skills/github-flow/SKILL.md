---
name: github-flow
description: >-
  Issue-driven development workflow with short-lived branches, git and GitHub CLI.
  Use when creating branches, pull requests, issues, code reviews, or when the
  user mentions GitHub flow, issue-driven development, PR workflow, or gh commands.
---

# GitHub Flow

Issue-driven development with short-lived branches. Every change originates from an issue; every branch links to an issue. Best practice: one issue → one branch → one merge request (multiple commits acceptable). CI/CD runs on main.

## Core Principles

1. **Issue first**: Never create a branch without an issue
2. **Branch–issue link**: Branch name references the issue (e.g. `42-add-auth`)
3. **Short-lived branches**: Create, merge, delete quickly
4. **Close via commit**: Use `Fixes #123` or `Closes #123` in PR body/merge commit so the issue auto-closes

## Step-by-Step Flow

### 1. Create the Issue

Create the issue before any code. Use GitHub CLI:

```bash
gh issue create --title "Add user authentication" --body "Implement JWT-based login"
```

With labels and assignee:

```bash
gh issue create --title "Add user authentication" --body "Implement JWT-based login" \
  --label "enhancement" --assignee @me
```

Note the issue number (e.g. `42`). Use it in branch name and PR body.

### 2. Create Branch from main

Ensure main is up to date, then create a branch named after the issue:

```bash
git checkout main
git pull origin main
git checkout -b 42-add-auth
```

Branch naming: `{issue-number}-{short-description}` (e.g. `42-add-auth`, `17-fix-login-bug`).

### 3. Implement and Commit

Make changes, then commit. Include the issue reference in the commit message:

```bash
git add .
git commit -m "feat(auth): add JWT login

Implements login endpoint and token validation.
Refs #42"
```

For the final commit before PR, you can use `Fixes #42` so merging closes the issue.

### 4. Push and Open Pull Request

```bash
git push -u origin 42-add-auth
gh pr create --title "Add user authentication" --body "Fixes #42" --base main
```

Or use `--fill` to auto-fill from commits:

```bash
gh pr create --fill --body "Fixes #42"
```

**Critical**: Include `Fixes #42` or `Closes #42` in the PR body so the issue closes when merged. For longer bodies, use `--body-file pr-body.txt`.

### 5. Code Review Cycle

Reviewers leave feedback. Author iterates:

```bash
# Fetch latest main
git checkout main && git pull origin main
git checkout 42-add-auth
git rebase main   # or: git merge main

# Make fixes, then commit and push
git add .
git commit -m "fix: address review feedback"
git push
```

### 6. Gatekeeper Approval and Merge

After approval, merge (squash or merge commit):

```bash
gh pr merge --squash --delete-branch
```

`--delete-branch` removes the branch after merge. The issue closes automatically via `Fixes #42` in the PR body.

### 7. Clean Up Locally

```bash
git checkout main
git pull origin main
git branch -d 42-add-auth
```

## Quick Reference

| Action | Command |
|--------|---------|
| Create issue | `gh issue create -t "Title" -b "Body"` |
| Add label to issue | `gh issue edit 42 --add-label "bug"` |
| Add comment to issue | `gh issue comment 42 -b "Comment text"` |
| Create PR | `gh pr create -t "Title" -b "Fixes #42"` |
| Add PR comment | `gh pr comment 42 -b "Comment text"` |
| Request review | `gh pr create -r username` or `gh pr edit 42 --add-reviewer username` |
| Approve PR | `gh pr review --approve` |
| Request changes | `gh pr review -r -b "Feedback"` |
| Merge PR | `gh pr merge --squash --delete-branch` |
| View PR | `gh pr view` |
| List open PRs | `gh pr list` |

## Git Commands

| Action | Command |
|--------|---------|
| Create branch | `git checkout -b 42-add-auth` |
| Update from main | `git checkout main && git pull && git checkout 42-add-auth && git rebase main` |
| Push branch | `git push -u origin 42-add-auth` |
| Amend last commit | `git commit --amend --no-edit` |
| Force push (after rebase) | `git push --force-with-lease` |

## For Detailed Commands

See [commands.md](commands.md) for full `gh` and `git` options.
