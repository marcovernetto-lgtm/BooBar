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

Full installed-app GitHub download/replacement/relaunch verification will be recorded after the release assets are available. Physical Intel hardware, real logout/login and full keyboard/VoiceOver interaction remain outside the verified scope. The update installer is constrained to writable Applications directories and requests no administrator privileges.
