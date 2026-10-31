# FigureOut

FigureOut is a Flutter mobile puzzle/action game where the player defeats
different shapes with gesture-specific attacks before the mission timer runs
out.

Stage and mission data come from the configured Google Sheet. See
[architecture and conventions](docs/architecture-and-conventions.md),
[Z movement](docs/z-movement.md), and [parabolic movement](docs/parabola-movement.md)
for maintained implementation notes.

## Tech Stack

- Flutter / Dart
- Flame
- GoRouter
- Google Sheet based stage, mission, translation, and log data
- PNG sprite gameplay shapes with Canvas paths for gestures and attack indicators
- SVG and image assets for menu and UI under `assets/`

## Run

```powershell
flutter pub get
flutter run
```

Local web preview (mobile portrait frame):

```powershell
flutter run --no-pub -d web-server --web-hostname 127.0.0.1 --web-port 5317
```

Lint after dependency resolution:

```powershell
flutter analyze --no-pub
```

The lint configuration includes `package:flutter_lints/flutter.yaml`. Native and
web platform folders are currently ignored by Git; platform setup and signing
configuration must be supplied separately for platform builds.

The app expects Google Sheet environment values in `assets/.env`.

Required keys:

- `GOOGLESHEETAPIKEY`
- `GOOGLESHEETID`

## Core Screens

- Main menu
- Stage select
- Mission select
- Game play
- Pause screen
- Mission clear popup
- Mission failed popup

## Gameplay Rules

Each shape has its own attack gesture.

- Circle: tap
- Rectangle: swipe slash, similar to Fruit Ninja
- Pentagon: long press for the health duration
- Triangle: draw a circle around it without touching another shape
- Hexagon: pinch zoom; each health point requires 20% scale change

Multiple matching shapes can be attacked at the same time when the gesture
supports it.

## Enemy Data

Enemy syntax follows the current parser and Google Sheet data.
The current Google Sheet uses the shape column for both enemies and wait rows.
There is no separate `e` command column.
In stage sheets, the parser expects the enemy/wait value in the Shape column
detected from the sheet layout; keep the shape, attack, movement, and position
fields aligned. See `SheetService` for the accepted layouts.

Basic format:

```text
ShapeSize_Order (Health)
```

Examples:

- `Circle3 (5)`
- `Triangle4 (10)`
- `Rectangle30:100 (15)`
- `Pentagon3 (10)`
- `Hexagon5 (20)`
- `Circle5_01 (10)` for ordered enemies
- `Circle5 (-1)` for dark enemies that should not be attacked

Shape size numbers map to percentage scale:

- `1` = 25%
- `2` = 50%
- `3` = 75%
- `4` = 100% default
- `5` = 125%
- `6` = 150%
- `7` = 175%
- `8` = 200%
- `9` = 250%
- `10` = 300%

Size change replaces the size number with `S(start, end, seconds)`:

```text
Circle S(4, 7, 9) (1)
Pentagon S(6, 2, 4) (2)
```

The shape spawns at size `start` and grows or shrinks to size `end` over
`seconds` seconds (same size scale as above). An order suffix still follows
it: `Circle S(4, 7, 9)_01 (1)`.

Rectangle supports explicit width, height, and an optional angle:

```text
Rectangle35:250/45 (60)
```

This means width 35, height 250 in sheet coordinate units, angle 45 degrees,
and health 60. These are dimensions, not a ratio. Rectangle dimensions do not
use the numbered size table above.

## Attack Data

Attack data uses:

```text
(attackTime, damage)
```

- Health `-1` enemies do not attack automatically.
- If the player attacks a dark enemy, the mission timer is reduced by the damage value.
- Normal enemies explode after `attackTime` if not defeated, then reduce the mission timer by `damage`.
- An initial movement `Wait` delays the start of the attack timer. A successful
  attack before expiry must not apply the expiry penalty.

## Move Data

Supported movement commands:

- `Z(x, y, speed)`: move to a point, then stop or continue to the next path command
- `Z(x, y, targetSpeed, accelerationSeconds)`: accelerate linearly from zero
  to the target speed, then continue at that speed; stop on arrival even if the
  acceleration period has not ended. Each leg, including `Back`, restarts acceleration.
- `B(x, y, speed)`: rebound movement toward a direction point, reflecting off play-area walls
- `C(radius, speed)`: clockwise circular movement
- `CC(radius, speed)`: counterclockwise circular movement
- `P(vx, vy, gravity)`: parabolic launch; see [P command](docs/parabola-movement.md)
- `L(x1, y1, x2, y2, speed)`: move repeatedly between two points
- `D(visible, hidden)`: repeat visible and hidden timing with smooth fade-in/out
- `DR(visible, hidden)`: repeat visible and hidden timing, then reappear at a random position
- `Repeat`: loop the path from the start
- `Back`: move back through the path in reverse order, then repeat from the
  initial wait; the return journey does not add another endpoint wait
- `Wait n`: before the movement, delays its start by `n` seconds; between two
  `Z` legs, holds the shape in place for `n` seconds. `Wait RND(a,b)` samples
  a new delay on each repeated visit
- `Disappear(n)`: fades the shape out and removes it `n` seconds after its `Z`
  path ends (for `B`/`C`/`D`/`DR`/`L`/`M` and `Repeat`/`Back` paths, `n`
  seconds after the movement starts); no penalty or reward, and it no longer
  blocks `Wait 0`

Timing lines share the movement cell, one command per line:

```text
Wait 2
Z(200, 0, 100)
```

```text
Z(160, 0, 250)
Disappear(3)
```

## Random Data

- `RND(a, b)` (alias `RD(a, b)`): random value between `a` and `b`
- `URD(a, b)`: unique random value between `a` and `b` within the same `Wait 0` group

## Wait Rules

- `Wait n`: wait `n` seconds before spawning the next enemy group
- `Wait 0`: wait until all current non-dark enemies and their removal effects
  have finished, including sliced Rectangle pieces
- `Wait 0` waits for newly spawned enemies to mount before checking clear state.
- Already removed or removing enemies must not block the next wave.
- `Wait` rows are written in the shape column.
- Dark enemies with health `-1` do not block `Wait 0`

## UI Requirements

- Portrait artwork reference: `1179 x 2556`
- Web preview logical frame: `393 x 852`, fitted inside the available panel
- Mobile orientation is locked to portrait
- Keep mobile touch targets at least `44 x 44`
- Avoid system font scaling breaking the UI
- Preserve smooth FPS and avoid unnecessary memory churn
- Mission result popups use a parchment panel, shared blue ribbon, and blue
  action pill buttons.
- The failed Continue button includes an AD badge; badge/icon spacing must not
  overlap button text.

## Development Notes

- Keep gameplay values in constants instead of magic numbers.
- Preserve existing game logic unless a bug fix requires changing it.
- Use Google Sheet data as the source of truth for stage and mission behavior.
- Gameplay shapes use PNG sprites and Canvas geometry; preserve referenced UI/menu SVG assets.
- Do not delete unused code without explicit approval.

## Refactoring Roadmap

Use behavior-preserving refactors first. Keep gameplay rules, Google Sheet syntax,
and UI flow unchanged unless a bug fix explicitly requires a behavior change.

Recommended order:

1. Split `lib/src/game_modes/one_second_game.dart` by responsibility.
2. Separate Google Sheet fetching from stage and enemy parsing.
3. Convert string move commands into typed internal command models.
4. Strengthen shared shape interfaces to reduce `dynamic` usage.
5. Route through typed argument objects instead of raw `Map` extras.
6. Move debug `print` output behind a logger or debug flag.
7. Review temporary or backup files only after explicit approval.

Suggested `one_second_game.dart` extraction targets:

- `mission_runner.dart`: mission flow, wait handling, spawn loop
- `game_timer_controller.dart`: mission time, penalties, rewards, time over
- `gesture_handler.dart`: tap, drag, circle, slice input state
- `shape_hit_test.dart`: shape-specific collision, enclosure, slice checks
- `mission_result_controller.dart`: clear, fail, continue, progress saving

Suggested parser extraction targets:

- `sheet_service.dart`: Google Sheet fetch only
- `stage_parser.dart`: raw rows to `StageData`
- `enemy_parser.dart`: enemy type, size, order, health, rectangle dimensions and angle
- `random_context.dart`: `RND` and `URD` resolution

Do not remove temporary or backup files without confirming they are unused and
getting explicit approval.

## Agent Execution Rules

- Normally only modify code.
- Run `flutter/react build web` only when explicitly requested.
- Run builds only when explicitly requested.
- Avoid running `flutter/react clean` while the server is running.
- Use normal privileges. Request scoped elevation only when an authorized
  command needs access outside the workspace, such as the shared Flutter SDK.
- Do not run compilation, linting, Git commit/push, diff checks, tests, or deployment unless the user explicitly requests them.

## Conversation delivery scope: 2026-10-31

The delivery includes the earlier uncommitted work from this conversation as
well as the cleanup and lint follow-up. Earlier fixes already in the baseline
history remain in place; they are not reapplied or merged from another branch.

- Web preview: fit a `393 x 852` portrait frame inside the side panel, avoid
  blocking the initial web screen on browser audio playback, and bundle the
  locally supplied `assets/.env`. Credentials themselves remain untracked.
- Stage selection: enable mouse dragging as well as touch swipes; one clickable
  indicator per loaded stage navigates to the matching page. The source sheet's
  stage ordering is preserved.
- Settings/audio: add persisted All Sounds, Sound Effects, and BGM controls in
  the existing seven UI languages; synchronize the app-bar BGM control, stop
  muted effects, guard duplicate playback starts, and repair Settings Back
  navigation and its touch area. Preference key: `figureout.audio-preferences.v1`.
- Gameplay: completely hidden D/DR shapes do not block enclosure/path checks or
  circle taps. D preserves the authored position; only DR randomizes it.
  Preserve slice endpoints through resampling/smoothing, avoid applying a drag
  penalty after a tap, and wait for sliced Rectangle pieces before `Wait 0`
  starts the next wave.
- Timing/movement: keep initial and intermediate fixed/random waits in the Z
  sequence, repeat the leading wait after `Back`, and start attack timers only
  after the initial movement wait. Match D/DR as complete command lines so the
  `D` in `RND(...)` cannot create a blinking behavior accidentally.
- Commands: smooth D/DR fade-in and fade-out; `C` clockwise and `CC`
  counterclockwise; `P(vx, vy, gravity)` parabolic launches; optional fourth Z
  argument for linear acceleration. See [P](docs/parabola-movement.md) and
  [Z](docs/z-movement.md) for parameters and behavior.
- The rejected falling-defense and Simon memory modes are absent from the
  current Dart implementation. No such mode is restored by this delivery.
- Stage/mission rows (including Stage 5 M6 Fruit Ninja and Stage 6 M3/M4
  variants/layouts) live in the [Google Sheet](https://docs.google.com/spreadsheets/d/1eKC52evyZhEPkNkCRaAINc94kCAqvzGRg3OZuIKI3Hc/edit).
  Sheet-only edits, row heights, and Google Cloud account/credential settings
  are external state, not Git changes. Their live contents were not rechecked
  or modified during this handoff.
- Include the user-approved full `pubspec.lock` changes, not only the three
  dependency removals: characters 1.4.1, matcher 0.12.20,
  material_color_utilities 0.13.0, meta 1.19.0, test_api 0.7.12, and
  vector_math 2.4.4; locked Dart requirement `>=3.11.0-0 <4.0.0`.
  This is an explicitly approved exception to the usual lockfile delivery
  restriction in the architecture document. No SDK upgrade was run for delivery.

- Include the user-approved `analysis_options.yaml` exclusions for `build/**`,
  `android/**`, and `ios/**`; `lib/` remains subject to Flutter lint rules.
  No further analysis is run during this handoff.

Only `main` and its single worktree are present. Review found no additional
local branches/worktrees requiring a separate commit or push. No merge is part
of this handoff. The lint result below belongs to the preceding authorized lint
request; this documentation/Git delivery does not rerun builds, lint, or tests.
No release build, store upload, deployment, or device/gameplay verification is
claimed by the source delivery.

## Maintenance check: 2026-10-31

- Baseline: `main` at `11f4f2e218f1da503502657fece20861b347e267`, with existing
  uncommitted gameplay, settings, and data-loading changes preserved.
- Removed 117 unreferenced assets (41,060,423 source bytes, approximately 39.2 MiB),
  four unreachable Dart files, unused helper APIs/state, and the unused direct
  dependencies `google_fonts`, `carousel_slider`, and `cupertino_icons`.
- Asset review included constructed paths for stars, stage cards, audio tracks,
  result panels, the no-hearts overlay, and the Flame pause button. Local Dart
  imports and retained asset paths resolve. These are static checks, not device QA.
- `flutter pub get --offline` completed. `analysis_options.yaml` now enables the
  declared Flutter lint rules and is no longer ignored by Git.
- `flutter analyze --no-pub`: **0 errors, 0 warnings, 93 informational findings**;
  exit code 1, so the lint run is not clean. Remaining findings include naming,
  override annotations, logging, and async `BuildContext` use. They remain visible;
  no rules were suppressed. The earlier default analyzer reported 28 findings
  before the missing lint configuration was restored; the totals are not comparable.
- No build, gameplay/device QA, commit, push, or deployment was performed for
  this cleanup. Source bytes removed are not a measured package-size reduction.

### Follow-up: resolve the remaining 93 lint findings

- Baseline: the cleanup above, with 93 informational findings and existing
  uncommitted changes preserved; branch and HEAD remain unchanged.
- Renamed 46 Dart files to `snake_case` and updated imports and documentation.
  Normalized app/type/constant names, added explicit field types and override
  annotations, matched callback parameter names, and added required braces.
- Preserved gameplay conditions and values. Removed pass-through overrides and
  the duplicate endless-mode timer field (using the same initialized base field).
  Local function declarations retain the same arguments and calculations.
- Added mounted checks after async initialization/navigation waits, including
  the endless-mode load continuation. Closed screens no longer access a stale
  context or start a game after disposal. Reward callbacks and persistence keys
  remain unchanged.
- Diagnostic messages now use the existing debug-level `LoggerService`; this
  level stays local and does not append to the logging sheet. Analytics calls
  and payloads were not changed.
- `flutter analyze --no-pub`: **No issues found** (0 errors, warnings, or infos).
  Lint rules remain enabled; no new suppressions or exclusions were added. Local imports were checked
  with exact path casing. No build or device/gameplay QA was performed.

## 2026-10-12 전역 정책 적용 범위

[공통 지침](https://github.com/ssongyc/development-policies/blob/main/AGENTS.md)의 해당 분야를 적용합니다. 새 사용자용 문구의 사전 승인, 기존 작업·서명 보존, 품질을 유지하는 자산 최적화, 언어·시트·광고·IAP 규칙과 출시 전 점검은 프로젝트의 실제 기능 범위 및 승인 예외와 함께 판단합니다. APK/AAB 공동 작업·캐시 입력·QA/출시 ABI 분리·TestFlight 제출 전용 재시도는 기존 빌드 경로에서 구현 여부를 확인해야 합니다.

이번 반영은 공통 지침 연결과 확인된 일부 소스/설정 차이의 보완이며, 전체 기능의 정책 준수나 출시 준비 완료를 뜻하지 않습니다. 기존 미커밋 변경을 보존했으며 빌드·린트·테스트·스토어 업로드는 실행하지 않았습니다. 호환성이 확인되지 않은 SDK/AGP 일괄 업그레이드, 신규 문구, 자격 증명 변경은 수행하지 않습니다.

### 2026-10-12 승인 후 검증

analyze: 실패 또는 차단(원본 로그 확인); test: 실패 또는 차단(원본 로그 확인). 앞 절의 미실행 기록은 소스 반영 당시 상태입니다. Android APK/AAB 및 기기 검증 완료를 뜻하지 않습니다. 이번 커밋에는 정책 적용 변경만 포함하며 기존 다른 작업과 생성 산출물은 보존·제외합니다.
