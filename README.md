# 🔷 Figure

[![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)](https://flutter.dev)
[![Flame](https://img.shields.io/badge/Flame-Engine-orange?style=for-the-badge)](https://flame-engine.org)


**Figure** is a high-performance casual action game developed using **Flutter** and the **Flame Engine**. The game focuses on intuitive yet diverse user interactions, where players pop various geometric shapes using specific gestures tailored to each shape's characteristics.

---

## 🎮 Key Gameplay Mechanics

Unlike typical tapping games, **Figure** requires strategic interaction based on the shape's properties:

* **Circle**: Quick tap to pop.
* **Triangle**: Draw a circle around the shape (Encircle gesture) to remove it.
* **Pentagon**: Long-press to charge the gauge before removal.
* **Rectangle**: Precision-based slice gesture to cut through the shape.
* **Hexagon**: Dynamic scaling interaction via drag.
* **Behaviors**: Implemented complex movement patterns like `Blinking` and `Orbiting` for enhanced difficulty and visual engagement.


![Figure-ezgif com-video-to-gif-converter](https://github.com/user-attachments/assets/2d418059-1216-44bb-9b4c-b951900fac0f)

## 🚀 Technical Achievements for Production
> *These features were implemented focusing on scalability and user experience for the actual app release.*

### 1. Dynamic Stage Management (Google Sheets API)
To ensure scalability and rapid balancing, I integrated the **Google Sheets API**. This allows me to update stage configurations, mission goals, and difficulty parameters in real-time without modifying the source code.

### 2. Mathematics-based Collision & Slicing
Implemented custom mathematical logic for:
* **Slice Detection**: Calculating intersections and splitting polygon components dynamically.
* **Shape-specific Physics**: Custom collision boxes and gesture triggers for non-standard polygons.

### 3. Component-Based Architecture
Leveraging Flame's `Component` system, I designed the project with highly reusable Mixins:
* `UserRemovable`: Standardizes how user input interacts with game objects.
* `OrderableShape`: Manages sequential mission logic.

## 🛠 Tech Stack

- **Framework**: Flutter
- **Game Engine**: Flame
- **Language**: Dart
- **State Management**: Flame Component Lifecycle & Flutter StatefulWidgets
- **Data Handling**: Google Sheets API (REST), JSON Parsing
- **Graphics**: SVG Rendering via `flame_svg`

---

## 📂 Project Structure (Key Modules)

* `lib/src/components/`: Core game objects (Shapes, Timer, PlayArea).
* `lib/src/functions/`: Business logic including `SliceMath`, `BlinkingBehavior`, and `SheetService`.
* `lib/src/routes/`: Game screens and navigation flow using `GoRouter`.

---

## 👥 Contributors & Team Roles

| Name | Role | Core Contributions |
| :--- | :--- | :--- |
| Robert Song | **Project Manager / Planner** | Game design, level balancing, and project roadmap management. |
| [Sam Chang](https://github.com/sammyc1394) | **Lead Developer** | Core engine architecture, game loop implementation, and system stability. |
| [Hyewon Ham](https://github.com/hyewon6588) | **Lead Developer** | State management, UI framework, and core gameplay logic. |
| **[Minsik Kim (Paul)](https://github.com/minsikpaul92)** | **Gameplay & UX Developer** | Developed core interaction algorithms (Encircle/Scaling) and optimized gameplay continuity (UX) systems. |
| Shin Park | **Art & Design** | UI/UX Design (Figma), SVG Assets, Visual Effects, and Animation assets. |

---

## 📄 Copyright
Copyright © 2025 - 2026 Figure Team (Robert Song, Sam Chang, Hyewon Ham, Minsik Kim, Shin Park). All rights reserved.  
Unauthorized use, reproduction, or distribution of this source code is strictly prohibited.
