# Repository Guidelines

## Project Structure & Module Organization
- `Sources/push` holds the SwiftUI macOS client, with `PushViewModel.swift` coordinating UI state and `APNsClient.swift` encapsulating JWT signing and APNs calls.
- Views live beside their helpers (`ContentView.swift`, `HistoryView.swift`, `LogTextView.swift`) to keep UI behavior and presentation close; update or add screens in this directory.
- Use `push.xcodeproj` for Xcode-driven development and `Package.swift` when working purely with Swift Package Manager.

## Build, Test, and Development Commands
- `open push.xcodeproj` launches the GUI project; run the `PushTester` scheme (`⌘R`) for the native macOS experience.
- `xcodebuild -project push.xcodeproj -scheme PushTester -destination 'platform=macOS' build` provides a reproducible CI-friendly build.
- `swift build` and `swift run` compile or run the SPM target; expect harmless bundle identifier warnings when running headless.

## Coding Style & Naming Conventions
- Follow Swift 6 defaults: four-space indentation, trailing commas for multi-line literals, and `MARK:` comments to segment large files when needed.
- Types use PascalCase (`APNsClient`), properties and functions use lowerCamelCase (`sendRequest`), and constants in `UserDefaultsKeys.swift` stay uppercase snake case.
- Favor small, testable structs and extensions; keep networking code inside `APNsClient.swift` and UI side-effects inside view models to preserve separation.

## Testing Guidelines
- Add new XCTest bundles under `Tests/` (e.g., `Tests/APNsClientTests.swift`) and mirror the module name with `@testable import push`.
- Name tests using `test_feature_expectation` and target at least smoke coverage for token signing, request assembly, and payload validation helpers.
- Run suites with `swift test`; in Xcode, create a macOS test target and execute via `⌘U` so CI scripts and GUI usage stay aligned.

## Commit & Pull Request Guidelines
- History favors Conventional Commit prefixes (`feat:`, `fix:`, `chore:`); keep subject lines under 72 characters and prefer English punctuation.
- Group UI tweaks, networking changes, and configuration updates into separate commits to simplify review and rollback.
- PRs should link related issues, list manual test steps or screenshots of key views, and mention APNs environment inputs used for validation.

## Security & Configuration Tips
- Never commit `.p8` keys or device tokens; rely on local paths and scrub them from logs before sharing.
- Reset secrets after demos and redact JWTs when capturing screenshots from `HistoryView.swift` or log panes.
- When scripting builds, set `CLANG_MODULE_CACHE_PATH` and `SWIFTPM_HOME` to workspace-local directories to avoid sandbox permission issues mentioned in `README.md`.
