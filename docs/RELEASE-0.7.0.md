# BooBar 0.7.0 — verification

powered by [unshapedstudio](https://unshapedstudio.com/)

- 20 tests passed on arm64 and 20 on x86_64 under Rosetta.
- Tests cover hover grace, pointer/button/menu protection, keyboard pinning, silent login/background policy, persisted shortcut format and native registration collision handling.
- Updater tests reject downgrades, prereleases, untrusted download URLs, different signing identities and incorrect versions. Installer replacement and failure rollback tested on isolated directories with spaces; test launcher substituted to avoid opening fake apps.
- Automatic updates query the public GitHub latest-release API at startup after 30 seconds and every 6 hours. Updates require matching SHA-256, the installed app's designated code-signing requirement, bundle/version identity, supported OS and current architecture. No Apple Developer account or notarization is added.
- Install stages a verified copy, waits for the existing app to exit, replaces it, and reopens in background. The previous signed app remains in the private update workspace for recovery. Switching off updates prevents automatic installation; manual check is explicit.
- Configured interaction polling changes from 0.15s continuously to 0.5s away from the bar and 0.1s near it/while expanded. Accessibility refresh is 5s in background and 1s with settings visible. This reduces configured idle ticks by 70%; it is not a measured energy saving.
- Native bilingual settings renders inspected. Neutral globe, left-aligned reset and right-aligned quit preserved. Added rows remain usable via scrolling on smaller screens.
- Universal DMG verified; binary SHA-256: `98c34911097a49aabd1ccdd396b187c3530e13f9b5cb3fbf1bca2457c86cb147`. DMG bytes: 2,026,778.

Full installed-app update verified against the published GitHub release: a private, locally signed 0.6.99 probe downloaded 0.7.0, passed digest and designated-requirement checks, replaced itself and restarted in background with Accessibility/native API active and settings closed. Installed executable matches the built release exactly; zones, language and shortcut preferences are unchanged. Logs: check/download 19:08:31, verification/install 19:08:36, restart 19:08:37 (host log timestamps). The 0.6.99 probe was never published. Physical Intel hardware, real logout/login and full keyboard/VoiceOver interaction remain outside the verified scope. The update installer is constrained to writable Applications directories and requests no administrator privileges.
