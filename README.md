# FigureOut

FigureOut is a Flutter mobile puzzle/action game where the player defeats
different shapes with gesture-specific attacks before the mission timer runs
out.

The gameplay reference is the shared planning document:
`C:\Users\ssong\Downloads\FigureOut (1).pdf`.

## Tech Stack

- Flutter / Dart
- Flame
- GoRouter
- Google Sheet based stage, mission, translation, and log data
- Canvas-rendered gameplay shapes
- SVG and image assets for menu and UI under `assets/`

## Run

```powershell
flutter pub get
flutter run
```

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

Enemy syntax is defined by the planning document and Google Sheet data.
The current Google Sheet uses the shape column for both enemies and wait rows.
There is no separate `e` command column.
In stage sheets, the parser expects the enemy/wait value in the Shape column
immediately after the Stage/Mission marker column.

Basic format:

```text
ShapeSize_Order (Health)
```

Examples:

- `Circle3 (5)` or `C3 (5)`
- `Triangle4 (10)` or `T4 (10)`
- `Rectangle5 (15)` or `R5 (15)`
- `Pentagon3 (10)` or `P3 (10)`
- `Hexagon5 (20)` or `H5 (20)`
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

Rectangle supports aspect ratio and angle:

```text
Rectangle7/35:250/45 (60)
```

This means size 7, width:height ratio 35:250, angle 45, health 60.

## Attack Data

Attack data uses:

```text
(attackTime, damage)
```

- Health `-1` enemies do not attack automatically.
- If the player attacks a dark enemy, the mission timer is reduced by the damage value.
- Normal enemies explode after `attackTime` if not defeated, then reduce the mission timer by `damage`.

## Move Data

Supported movement commands:

- `Z(x, y, speed)`: move to a point, then stop or continue to the next path command
- `B(x, y, speed)`: rebound movement, reflecting off walls or shapes
- `C(radius, speed)`: circular movement
- `D(visible, hidden)`: repeat visible and hidden timing
- `DR(visible, hidden)`: repeat visible and hidden timing, then reappear at a random position
- `Repeat`: loop the path from the start
- `Back`: move back through the path in reverse order

## Random Data

- `RND(a, b)`: random value between `a` and `b`
- `URND(a, b)`: unique random value between `a` and `b` within the same `Wait 0` group

## Wait Rules

- `Wait n`: wait `n` seconds before spawning the next enemy group
- `Wait 0`: wait until all current non-dark enemies are defeated
- `Wait` rows are written in the shape column.
- Dark enemies with health `-1` do not block `Wait 0`

## UI Requirements

- Target reference resolution: `1179 x 2556`
- Must support responsive layouts such as `2532 x 1170`
- Keep mobile touch targets at least `44 x 44`
- Avoid system font scaling breaking the UI
- Preserve smooth FPS and avoid unnecessary memory churn

## Development Notes

- Keep gameplay values in constants instead of magic numbers.
- Preserve existing game logic unless a bug fix requires changing it.
- Use Google Sheet data as the source of truth for stage and mission behavior.
- Gameplay shapes are rendered directly with Flutter Canvas; keep UI/menu SVG assets where they are still referenced.
- Do not delete unused code without explicit approval.

## Refactoring Roadmap

Use behavior-preserving refactors first. Keep gameplay rules, Google Sheet syntax,
and UI flow unchanged unless a bug fix explicitly requires a behavior change.

Recommended order:

1. Split `lib/src/routes/OneSecondGame.dart` by responsibility.
2. Separate Google Sheet fetching from stage and enemy parsing.
3. Convert string move commands into typed internal command models.
4. Strengthen shared shape interfaces to reduce `dynamic` usage.
5. Route through typed argument objects instead of raw `Map` extras.
6. Move debug `print` output behind a logger or debug flag.
7. Review temporary or backup files only after explicit approval.

Suggested `OneSecondGame.dart` extraction targets:

- `mission_runner.dart`: mission flow, wait handling, spawn loop
- `game_timer_controller.dart`: mission time, penalties, rewards, time over
- `gesture_handler.dart`: tap, drag, circle, slice input state
- `shape_hit_test.dart`: shape-specific collision, enclosure, slice checks
- `mission_result_controller.dart`: clear, fail, continue, progress saving

Suggested parser extraction targets:

- `sheet_service.dart`: Google Sheet fetch only
- `stage_parser.dart`: raw rows to `StageData`
- `enemy_parser.dart`: enemy type, size, order, health, rectangle ratio and angle
- `random_context.dart`: `RND` and `URND` resolution

Do not remove temporary or backup files without confirming they are unused and
getting explicit approval.
