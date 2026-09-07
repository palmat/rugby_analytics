---
name: commit
description: Review the working tree changes and create a git commit with a well-written message. Use when the user asks to commit, save, or check in their code (e.g. "/commit", "commit this", "save my changes").
---

# Commit

Commit the current changes in this repository on the user's behalf.

## Steps

1. Run in parallel:
   - `git status` (never `-uall`)
   - `git diff` (staged + unstaged)
   - `git log --oneline -10` (match this repo's message style)
2. If there are no staged or unstaged changes and no untracked files, tell the user there's nothing to commit and stop.
3. Review untracked files and diffs for anything that looks like a secret (`.env`, credentials, API keys, tokens) or a large/binary file that doesn't belong. Flag it to the user and exclude it rather than committing it silently.
4. Stage the relevant files by name (avoid `git add -A` / `git add .`).
5. Draft a concise commit message (1-2 sentences) focused on *why* the change was made, matching the repo's existing style (see recent `git log`).
6. Create the commit via a HEREDOC so formatting is preserved, ending with:
   ```
   Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
   ```
7. Run `git status` after to confirm the commit succeeded.
8. If a pre-commit hook fails, fix the underlying issue, re-stage, and make a **new** commit — never amend and never `--no-verify`.

## Rules

- Never push. This skill only commits locally unless the user explicitly asks to push too.
- Never use destructive git operations (`reset --hard`, `checkout -- .`, `clean -f`, force-push).
- Never skip hooks or bypass signing.
- Only commit when explicitly invoked — don't run this proactively in the background.
