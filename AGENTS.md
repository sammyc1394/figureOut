# AGENTS.md

## Developer Context

The user is a solo mobile app/game and Microsoft Windows app developer.

## Before You Start

- Before creating, moving, or editing code or assets, read `docs/architecture-and-conventions.md`.
- Follow its folder structure (`lib/src/` roles), asset structure (`assets/`), and code conventions.
- Place new files in the folder that matches their role as defined there. If a file doesn't fit any folder, ask before creating a new one.
- If a requested change conflicts with the document, point out the conflict instead of silently ignoring it.

## Global Execution Rules

- Normally only modify code.
- Run `flutter/react build web` only when explicitly requested.
- Run builds only when explicitly requested.
- Avoid running `flutter/react clean` while the server is running.
- Run Codex or Claude/Terminal with administrator privileges.
- Do not run compilation, linting, Git commit/push, diff checks, tests, or deployment unless the user explicitly requests them.

## Git & PR Attribution Rules

- NEVER add AI attribution to commits or PRs. This includes, but is not limited to:
  - "Made with Cursor" (or any similar footer/link) in PR titles/descriptions.
  - "Co-authored-by: Cursor <cursoragent@cursor.com>" (or any AI co-author) trailers in commit messages.
- When creating a commit or PR, verify no such attribution was auto-added, and remove it before finishing.

## Response Style

- Be concise and practical.
- Prefer direct fixes and minimal changes.
- Preserve existing logic when possible.

