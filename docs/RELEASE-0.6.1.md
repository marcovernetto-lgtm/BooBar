# BooBar 0.6.1 — verification

powered by [unshapedstudio](https://unshapedstudio.com/)

Replaced the country flag with a monochrome native SF Symbols globe. The icon is identical in Italian and English; the custom flag source is removed. All 0.6 features remain: immediate language switching, enlarged Command-Shift instructions, simplified settings, optional login and three menu bar zones. See [0.6 review](RELEASE-0.6.0.md) for the code and optimization scope.

- 13 tests passed on arm64; 13 passed as x86_64 under Rosetta, including native visibility assertion and release.
- Native bilingual permission-state renders refreshed; globe and Italian layout inspected.
- Universal DMG checksum verified, mounted read-only, Applications link and contained signed binary verified.
- Built/installed/DMG binary SHA-256: `2d407c50880de5e112a54858e9b55e167940eb9c2a9ac9587e312dcb8455aee3`.
- Installed signature verified, existing zones unchanged. App content: 1,519,659 bytes. DMG: 1,622,656 bytes.
- Git prepared locally only; publishing deferred by the user. Signing keys and local backups excluded.

Not checked on physical Intel hardware or older macOS; minimum macOS 27. Build locally signed, not Apple-notarized. A downloaded copy may require approval in Privacy & Security. No claim of measured live frame pacing or full keyboard/VoiceOver verification.
