# 폴더 구조 및 코드 컨벤션

`lib/src/` 하위 폴더의 역할과 기준, 그리고 코드 컨벤션을 정리한 문서입니다.
새 파일을 만들거나 코드를 리뷰할 때 기준으로 사용합니다.

> 관련 문서(작성 예정): 요건 정의(명령어) md, 상수 정리 md

## 1. 폴더 구조

```
lib/
├── main.dart              # 앱 진입점, 초기화, GoRouter 정의
└── src/
    ├── behaviors/         # 에디터 명령어 및 명령 동작
    ├── components/        # 게임 월드의 Flame 컴포넌트
    ├── config/            # 앱/게임의 정적 설정
    ├── effect/            # 게임 내 시각/연출 효과
    ├── functions/         # 상태 없는 공용 로직/유틸리티 (필요 시 생성)
    ├── game_modes/        # 게임 모드별 진입 클래스와 컨트롤러
    ├── routes/            # 화면(Screen/Overlay)과 라우트 인자
    ├── services/          # 외부 시스템/지속 상태와 상호작용하는 서비스
    └── temp/              # 추후 삭제 예정인 임시 구현
```

### 폴더별 역할과 기준

| 폴더 | 역할 | 넣는 기준 | 현재 예시 |
|---|---|---|---|
| `behaviors/` | 에디터 명령어 해석 및 도형에 적용되는 동작 | `ShapeBehavior`를 구현하는 명령어(B/M/Z/L/C/DDr 등), wait/disappear 같은 타이밍 명령 | `BCommand`, `MCommand`, `ZCommand`, `TimingCommand`, `shapeBehavior` |
| `components/` | 게임 화면에 실제로 올라가는 객체와 그 공통 mixin/인터페이스 | `PositionComponent` 계열 도형·HUD 컴포넌트, 도형이 공유하는 mixin | `CircleShape`, `HexagonShape`, `PauseButton`, `OrderableShape`, `UserRemovable` |
| `config/` | 정적 설정 | 상수, 번역 데이터, 테마/환경/게임 설정 | `config`, `translation_data`, `theme_mode_scope` |
| `effect/` | 시각/연출 효과 | 폭발, 소멸, 패널티, 조각 낙하 등 효과와 효과용 Painter | `AttackExplosionEffect`, `CircleDisappearEffect`, `PenaltyEffect` |
| `functions/` | 상태를 갖지 않는 공용 로직 | 입력 → 계산 → 결과 형태의 순수 함수 | (현재 비어 있음) |
| `game_modes/` | 게임 모드 | 모드별 `FlameGame` 클래스와 모드 컨트롤러 | `OneSecondGame`, `endless_game_controller` |
| `routes/` | 화면 이동과 화면 UI | 라우트로 열리는 화면, 오버레이 위젯, 라우트 인자 클래스 | `MainMenu`, `StageSelect`, `PausedScreen`, `route_args` |
| `services/` | 서비스 계층 | 저장소, API, SDK, 광고, 분석, 오디오 등 외부 시스템 또는 지속 상태와 상호작용 | `HeartService`, `AdManager`, `AudioManager`, `AnalyticsService`, `SheetService` |
| `temp/` | 임시 구현 | 삭제 예정인 임시 코드. 새 코드는 넣지 않는다 | `RefreshButton`, `svgButton`, `logger` |

### 새 파일을 어디에 둘지 판단하는 순서

1. 에디터 명령어나 도형 동작인가? → `behaviors/`
2. 게임 월드에 올라가는 Flame 컴포넌트인가? → `components/`
3. 그리는 효과(폭발, 소멸 등)인가? → `effect/`
4. 외부 시스템(저장소, 네트워크, SDK)이나 지속 상태를 다루는가? → `services/`
5. 상수·설정 값인가? → `config/`
6. 라우트로 열리는 화면인가? → `routes/`
7. 상태 없는 순수 계산인가? → `functions/`
8. 게임 모드 자체인가? → `game_modes/`

### 의존 방향

- `routes/`, `game_modes/`는 `components/`, `behaviors/`, `effect/`, `services/`, `config/`를 사용할 수 있다.
- `components/`는 `behaviors/`, `effect/`, `config/`, `services/`를 사용할 수 있다.
- `config/`, `services/`는 화면(`routes/`)이나 게임 컴포넌트(`components/`)에 의존하지 않는다.

## 2. 에셋 구조

```
assets/
├── .env                   # API 키 등 비밀 값 (git 추적 대상 아님, 코드에 값 직접 기재 금지)
├── audio/                 # BGM(bgm_*.mp3), 도형별 효과음(pop_*.mp3)
├── fonts/                 # 폰트 파일 (Gaegu, Moulpali)
├── shapes/                # 게임 도형 이미지 (Circle.png, Hexagon_3x.png 등)
├── menu/
│   ├── common/            # 공통 UI 아이콘/카드 (하트, 설정, 결과 팝업, 시작 화면 등)
│   ├── mission/           # 미션 선택 화면 (미션 카드, 별, 잠금)
│   └── stage/             # 스테이지 선택 화면 (색상별 탭/카드, 스테이지 이미지)
└── (루트)                 # 위 폴더에 정리되지 않은 기존 UI 이미지와 텍스처
```

### 폴더별 기준

| 폴더 | 넣는 기준 | 예시 |
|---|---|---|
| `audio/` | 재생되는 모든 사운드. BGM은 `bgm_*`, 효과음은 도형/동작 이름 접두사 | `bgm_lofi.mp3`, `pop_circle.mp3`, `pop_hexagon_loop.mp3` |
| `fonts/` | 폰트 파일. `pubspec.yaml`의 `fonts:`에 family로 등록 | `Gaegu-Regular.ttf` |
| `shapes/` | 게임 월드에 그려지는 도형 이미지 | `Circle_3x.png`, `Pentagon.png` |
| `menu/common/` | 여러 화면에서 함께 쓰는 UI 요소 | `Heart_full.svg`, `Result_card.svg`, `bg.svg` |
| `menu/mission/` | 미션 선택 화면 전용 | `Star_3.svg`, `lock.svg` |
| `menu/stage/` | 스테이지 선택 화면 전용 | `Blue_Default.svg`, `stage_1.png` |
| 루트 | 기존에 루트에 있던 UI 이미지, 텍스처. **새 에셋은 루트에 추가하지 않는다** | `noise_texture.png`, `tutorial_hand.png` |

### 에셋 규칙

- 새 에셋은 용도에 맞는 하위 폴더에 추가한다. 화면 전용이면 해당 화면 폴더, 여러 화면에서 쓰면 `menu/common/`.
- 벡터로 표현 가능한 UI는 SVG, 질감이 있거나 래스터 이미지가 필요한 경우는 PNG를 사용한다.
- 고해상도 이미지는 `_3x` 접미사를 붙인다 (예: `Circle_3x.png`).
- 상태가 있는 UI는 `이름_상태` 형식으로 만든다 (예: `Black_Default`, `Black_Selected`, `Exit_basic`, `Exit_pressed`).
- 파일 이름에 공백을 쓰지 않는다. (기존 `Type 1_default.svg`, `Replay_button beige.png` 같은 파일은 변경하지 않는다.)
- 새 폴더를 만들면 `pubspec.yaml`의 `flutter: assets:`에 폴더 경로를 반드시 추가한다.
  `assets/`만 등록하면 하위 폴더 파일은 포함되지 않는다.
- 코드에서 에셋 경로를 문자열로 직접 반복해서 쓰지 말고, 반복되는 경로는 상수로 모아서 사용한다.
- 에셋을 삭제하거나 이동할 때는 `lib/`에서 해당 경로를 참조하는 곳이 없는지 먼저 검색한다.

## 3. 코드 컨벤션

현재 코드에서 공통으로 쓰이는 방식을 기준으로 정리했습니다. 린트는 `analysis_options.yaml`의 `flutter_lints`를 따릅니다.

### 파일/클래스 이름

- 클래스 이름은 `UpperCamelCase`, 변수·메서드는 `lowerCamelCase`, 상수는 `lowerCamelCase`(예: `maxHearts`).
- 클래스를 담는 파일 이름은 기존 코드가 PascalCase(`CircleShape.dart`)와 snake_case(`heart_service.dart`)로 섞여 있다.
  **새 파일은 snake_case를 사용한다.** 기존 파일 이름은 변경하지 않는다.
- 한 파일에는 대표 클래스 하나를 두고, 파일 이름은 그 클래스 이름과 대응시킨다.
- private 위젯/보조 클래스는 같은 파일 안에서 `_` 접두사를 붙인다 (예: `_ResultPanel`).

### import

- `lib/` 안의 파일은 `package:figureout/src/...` 절대 경로 import를 기본으로 한다.
  같은 폴더 안의 가까운 파일끼리는 상대 경로를 쓰는 경우도 있다(`behaviors/` 내부 등).
- import는 Dart/Flutter/외부 패키지, 프로젝트 파일 순서로 묶는다.

### 서비스 작성

- 전역 단일 인스턴스가 필요한 서비스는 `Service.instance` 싱글톤으로 작성한다 (`LoggerService`, `AnalyticsService`).
- 상태 없이 정적 메서드만 필요한 헬퍼는 `static` 메서드로 작성한다 (`HeartService`).
- `SharedPreferences` 키는 문자열 상수로 관리하고, 같은 키를 여러 곳에서 문자열 리터럴로 반복하지 않는다.

### 상수와 설정

- 게임/UI에서 공통으로 쓰는 값은 `config/config.dart`에 둔다 (게임 크기, 색, 폰트, 하트 개수 등).
- 번역 문자열은 `config/translation_data.dart`와 Google Sheet 번역을 통해 관리하며, 화면에 직접 문자열을 하드코딩하지 않는다.
- 비밀 값(API 키 등)은 코드에 넣지 않고 `assets/.env`에서 읽는다.

### 로그

- 디버그 로그는 `appLog(tag, message, level: ...)`(`temp/logger.dart`) 또는 `LoggerService`를 사용한다.
- 분석 이벤트는 `AnalyticsService.instance.logEvent(...)`로 보낸다.

### 주석

- 주석은 "왜 그렇게 했는지"가 필요한 곳에 쓴다. 코드만 봐도 알 수 있는 내용은 쓰지 않는다.
- 주석 언어는 한국어와 영어가 섞여 있다. 같은 파일 안에서는 하나의 언어로 통일한다.
- 사용하지 않는 코드는 주석으로 남기지 않고 삭제한다 (git 기록으로 복구 가능).

### 라우팅과 화면

- 라우트는 `main.dart`의 `GoRouter`에서 정의하고, 화면 간에 넘기는 값은 `routes/route_args.dart`의 인자 클래스를 사용한다.
- 새 화면은 `routes/`에 만들고 `main.dart`에 경로를 추가한다.

### 도형(Flame 컴포넌트) 작성

- 도형은 `components/`에 두고, 공통 동작은 mixin/추상 클래스(`OrderableShape`, `ResizableShape`, `UserRemovable`, `OverlapHighlightable`, `BlinkAlphaTarget`)로 분리한다.
- 도형에 적용되는 이동/크기 변경 같은 명령은 `behaviors/`에서 `ShapeBehavior`를 구현한다.
- 도형이 사라질 때의 연출은 `effect/`에 두고, 도형 클래스 안에 직접 그리기 코드를 늘리지 않는다.

## 4. 커밋과 PR 규칙

- 커밋 메시지는 `feat:`, `fix:`, `chore:`, `docs:`, `refactor:` 접두사를 사용한다. (예: `fix: preserve sheet spawn coordinates without clamping`)
- 브랜치 이름은 작업 성격이 드러나게 짓는다 (`feat/...`, `fix/...`, `chore/...`).
- PR 제목과 본문은 영어로 작성한다.
- 커밋과 PR에 AI 도구 표시(footer, co-author 등)를 넣지 않는다.

## 5. 알려진 정리 대상

- 파일 이름 규칙이 PascalCase와 snake_case로 섞여 있다. 새 파일부터 snake_case를 적용한다.
- `OneSecondGame.dart`가 3,000줄 이상이다. 기능 추가 시 `behaviors/`, `effect/`, `functions/`로 분리를 검토한다.
- `temp/`의 파일은 대체 구현이 생기면 삭제한다.
