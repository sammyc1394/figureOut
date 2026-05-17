# AGENTS.md

## Developer Context

The user is a solo mobile app/game and Microsoft Windows app developer.

## Global Execution Rules

- Normally only modify code.
- Run `flutter/react build web` only when explicitly requested.
- Run builds only when explicitly requested.
- Avoid running `flutter/react clean` while the server is running.
- Run Codex or Claude/Terminal with administrator privileges.
- Do not run compilation, linting, Git commit/push, diff checks, tests, or deployment unless the user explicitly requests them.

## Response Style

- Be concise and practical.
- Prefer direct fixes and minimal changes.
- Preserve existing logic when possible.

