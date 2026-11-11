# Android build contract
- Portrait orientation, offline launch, no permissions beyond those truly required.
- Configure Android export preset and package name (owner to approve final reverse-DNS identifier); use a non-production debug identifier until confirmed.
- Record Godot version, installed export templates, Android SDK/NDK/JDK versions, build system and keystore handling. Do not commit secrets/keystores.
- CI: headless import → static/content validation → unit/integration tests → debug Android export. Attach APK checksum.
- Test real device touch safe areas, 20:9 and 19.5:9 aspect ratios, app background/resume, pause, low-memory lifecycle, sound toggle, reduced flashes, save corruption recovery.
- Benchmark 50 enemies on at least one actual Android device. Report hardware model, OS, build ID, median/p95 frame times, sustained FPS after 5 minutes, max memory, battery/thermal notes.
- Provide build and test commands as executable scripts, and ensure exit codes fail CI on error.
