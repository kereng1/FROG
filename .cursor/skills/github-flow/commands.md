# GitHub Flow — Command Reference

## GitHub CLI (gh)

### Issues

```bash
# Create
gh issue create --title "Title" --body "Description"
gh issue create -t "Title" -b "Description" -l "bug,help wanted" -a @me

# Add label
gh issue edit 42 --add-label "enhancement"
gh issue edit 42 --add-label "bug,help wanted"

# Remove label
gh issue edit 42 --remove-label "wontfix"

# Comment
gh issue comment 42 -b "Comment text"
gh issue comment 42 -F comment.txt

# View
gh issue view 42
gh issue list
gh issue list --state closed
```

### Pull Requests

```bash
# Create
gh pr create --title "Title" --body "Fixes #42"
gh pr create --fill --body "Fixes #42"
gh pr create -t "Title" -b "Body" -r reviewer1 -l "ready"

# Add comment
gh pr comment 42 -b "Comment text"

# Request review
gh pr edit 42 --add-reviewer username
gh pr edit 42 --add-reviewer org/team-name

# Review (gatekeeper)
gh pr review --approve
gh pr review --comment -b "Looks good"
gh pr review --request-changes -b "Please fix X"

# Merge
gh pr merge --squash --delete-branch
gh pr merge --merge --delete-branch
gh pr merge --rebase --delete-branch

# View
gh pr view
gh pr view 42
gh pr list
gh pr checks
```

### Branch and Repo

```bash
# Target another repo
gh issue create -R owner/repo -t "Title" -b "Body"
gh pr create -R owner/repo -t "Title" -b "Body"

# Auth
gh auth status
gh auth login
```

## Git

### Branch Workflow

```bash
# Create and switch
git checkout main
git pull origin main
git checkout -b 42-add-auth

# Rebase on main
git fetch origin
git rebase origin/main

# Push
git push -u origin 42-add-auth
git push --force-with-lease   # after rebase
```

### Commit

```bash
# Standard
git add .
git commit -m "feat(auth): add login"

# With body (for Fixes #42)
git commit -m "feat(auth): add login" -m "Fixes #42"

# Amend
git commit --amend -m "New message"
git commit --amend --no-edit
```

### Cleanup

```bash
# Delete local branch
git branch -d 42-add-auth
git branch -D 42-add-auth   # force

# Prune remote refs
git fetch --prune
```
