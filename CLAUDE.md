# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
flutter pub get          # Install dependencies
flutter run              # Run on connected device/emulator
flutter run -d chrome    # Run in browser
flutter test             # Run all tests
flutter test test/widget_test.dart  # Run a single test file
flutter analyze          # Static analysis / lint
flutter build apk        # Build Android APK
flutter build ios        # Build iOS
```

## Architecture

This is a Flutter (Material 3) frontend for **UPBVote**, a university project voting platform. The app supports four user roles: **Votante** (voter), **Expositor** (presenter), **Jurado** (jury), and **Secretario** (secretary). UI renders conditionally based on the active role.

### Directory layout

```
lib/
├── main.dart                  # App entry point, MaterialApp + theme
├── core/                      # Empty — reserved for utilities/constants
├── models/                    # Empty — reserved for data models
├── services/                  # Empty — reserved for API service classes
└── ui/
    ├── screens/               # One file per screen (7 screens)
    ├── shared/                # Empty — reserved for shared resources
    └── widgets/               # Empty — reserved for reusable widgets
```

### State management & navigation

- No state management library yet — plain `StatefulWidget`/`StatelessWidget`.
- Navigation uses `Navigator.push` / `Navigator.pushReplacement` with `MaterialPageRoute`.
- Role context is passed directly through screen constructors (e.g., `userRole` string).

### Theme

Defined in `main.dart` using `ThemeData` with Material 3:
- Primary: `#B71C1C` (UPB red)
- Secondary: `#263238` (dark slate)

### Backend

The `http` package is included but no service layer exists yet. The intended backend is a Django REST API. API integration should live in `lib/services/`.

### Screens

| File | Role visibility |
|------|----------------|
| `login_screen.dart` | All (entry point, includes role selector for dev) |
| `register_screen.dart` | All |
| `verify_code_screen.dart` | All |
| `home_screen.dart` | All (drawer + bottom nav vary by role) |
| `project_list_screen.dart` | All |
| `project_detail_screen.dart` | Role-specific voting/evaluation UI |
| `upload_project_screen.dart` | Expositor only |

All screens currently use hardcoded mock data — no live API calls.
