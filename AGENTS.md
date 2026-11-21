# Project Rules & Guidelines

- **README Documentation**: Always update `README.md` whenever a core feature or functionality is added, updated, or modified. Keep feature descriptions, usage details, and project architecture up to date.
- **Build Verification**: Verify all changes build cleanly using `xcodebuild` before committing.
- **Simulator Policy**: Do not boot or launch the iOS simulator (`simctl boot`). Continue verifying changes build cleanly via `xcodebuild` with a generic destination (e.g. `generic/platform=iOS Simulator`), but do not start or control simulator processes, as Xcode is frequently connected to a physical device.
- **Git Hygiene**: Keep commits atomic, well-described, and synchronized with remote repository.
