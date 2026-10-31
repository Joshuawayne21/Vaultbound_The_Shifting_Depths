# Milestone 1 baseline

Godot 4.6.3 is available in the cloud workspace. The initial workspace contained no project or Git history; the repository was initialized in `vaultbound/`.

- Editor resource import: completed, without missing project resources or GDScript parser errors.
- Main scene headless startup for 180 frames: exited successfully, without runtime errors.
- Automated integration: **95 checks passed**, exit code 0. Covers movement, switching during attacks/dodges, camera collision, synthetic multitouch, both portal directions, recovery, and input resets.
- Editor-only environment warnings: local TCP debug listener is disallowed by the runner, and Android SDK build-tools are unavailable. No APK export was attempted.
- Android device testing, GPU visual review, APK signing, and performance measurement: pending. A local virtual display could not start under the cloud socket policy.

No multiplayer functionality is implemented or represented as complete.
