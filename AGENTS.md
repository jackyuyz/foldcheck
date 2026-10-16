# FoldCheck development

- We are building a native app for the new iPhone Duo. Treat Duo's inner, cover and partially folded layouts as first-class screens.
- Use **Xcode 27.1 RC**, installed at `/Applications/Xcode-27.1RC.app`, for builds and the iOS 27.1 iPhone Duo simulator. Set `DEVELOPER_DIR=/Applications/Xcode-27.1RC.app/Contents/Developer` per command; the default selected Xcode may be older.
- Generate the project from `project.yml` using XcodeGen. Keep hinge API calls behind `FOLDCHECK_HINGE_API` and runtime availability guards.
- Follow `docs/foldcheck-spec.md`. All inspection data stays local; no backend, login, cloud sync or analytics.
- M7 is being developed directly on `main` at the user's request. Do not create a branch for this work.

## File deletion safety

Never bulk-delete files or recursively delete directories. Never use `rm -rf`, `rm -r`, `git clean -fd`, wildcard deletion, or equivalent operations. Only delete one explicitly named file at a time. If multiple files or directories need removal, stop, explain the paths, and ask the user to confirm or remove them manually. Never automatically remove hidden/system files.
