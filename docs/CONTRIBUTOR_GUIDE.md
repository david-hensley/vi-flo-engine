# VI-FLO Engine: Contributor Guide

## One-Time Setup (Do this once per machine)

### 1. Install Required Software
- **Git**: Download from git-scm.com
- **Python 3.x**: For running/modifying setup scripts
- **R 4.0+**: For the main codebase
- **GitHub account**: Create at github.com

### 2. Configure Git Identity
Do this in the Terminal / PowerShell
```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

### 3. Clone the Repository
```bash
cd /path/where/you/want/it
git clone https://github.com/david-hensley/vi-flo-engine.git
cd vi-flo-engine
```

### 4. Run Setup
- Windows: Double-click `setup_win.exe`
- This sets environment variables and creates your datamap

---

## Daily Workflow: Making Changes

### Before You Start Coding
```bash
# 1. Navigate to repo
cd /path/to/vi-flo-engine

# 2. Make sure you're on main branch
git status

# 3. Pull latest changes from GitHub
git pull origin main

# 4. Read what's changed
git log --oneline -5        # Last 5 commits
cat CHANGELOG.md            # Or open in text editor
```

### While You're Coding
- Make small, logical changes
- Test as you go
- Take notes for the commit message

### After You Finish a Logical Unit of Work

**Step 1: Stage your changes**
```bash
git add .                   # Stages all changed files
# OR
git add path/to/file.R      # Stage specific files
```

**Step 2: Commit locally**
```bash
git commit -m "Brief description of what you did"
```

**Good commit message examples:**
- `"Add function to calculate daily rainfall totals"`
- `"Fix bug in sensor ID parsing for slope loggers"`
- `"Update datamap to support new geospatial folder"`

**Step 3: Push to GitHub** (when ready)
```bash
git push origin main
```

---

## Versioning: When to Bump Version Numbers

### Version Format: MAJOR.MINOR.PATCH (e.g., 0.2.3)

**Bump PATCH (0.0.X):** Bug fixes, small tweaks, documentation  
**Bump MINOR (0.X.0):** New features, new functions, but backwards compatible  
**Bump MAJOR (X.0.0):** Breaking changes (not until 1.0.0 release)  

### How to Create a New Version

**Step 1: Update CHANGELOG.md**
```markdown
## [0.1.0] - 2025-01-15
### Added
- New function `import_zentra_data()` for automated downloads
- Support for slope logger metadata in deployment log

### Fixed
- Corrected path handling in datamapper for external data sources
```

**Step 2: Create git tag**
```bash
git tag -a v0.1.0 -m "Release v0.1.0: Zentra automation"
```

**Step 4: Push everything including tags**
```bash
git push origin main
git push origin v0.1.0
```

---

## Quick Reference: Common Git Commands

```bash
# See what's changed
git status

# See commit history
git log --oneline

# See all tags (versions)
git tag

# Undo last commit (keeps changes)
git reset --soft HEAD~1

# Discard all local changes (DANGEROUS!)
git reset --hard HEAD

# See what's different from last commit
git diff
```

---

## When Things Go Wrong

**"fatal: Unable to create index.lock"**
→ Another git process is running. Close all terminals/editors, then:
```bash
rm .git/index.lock
```

**"I committed to the wrong branch"**
→ Contact someone who knows git better than you :)

**"I forgot to pull before making changes"**
→ Commit your changes, then `git pull origin main` will usually merge automatically

---

## Notes for Future You

- Don't forget to actually TEST your changes before committing
- Write commit messages for someone (including yourself in 6 months) who has no context
- When in doubt, commit MORE frequently with smaller changes
- The CHANGELOG is for humans; git commits are for tracking every detail
- Always pull before you start working to avoid merge conflicts
