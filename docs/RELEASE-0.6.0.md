# BooBar 0.6.0 — verification

powered by [unshapedstudio](https://unshapedstudio.com/)

- macOS 27.0.1 (26A434), Xcode 27, Apple Silicon.
- 13 tests passed on arm64; the same 13 XCTest cases passed as x86_64 under Rosetta, including the real native visibility assertion and release. The SwiftPM Intel helper initially selected the ARM runner; invoking XCTest under Rosetta resolved the runner mismatch.
- Both languages rendered under both macOS appearances, permission granted/missing: eight native captures inspected. Fixed dark theme; enlarged 25pt Command-Shift badge; monochrome vector flag; immediate language selection; removed count and hover paragraph.
- Reviewed every runtime source, Objective-C bridge/header, tests, build/signing and packaging scripts. Scoped load: one desktop user, dozens of running apps. Existing atomic zone writes, revision guards, native assertion rollback and timeout remain.
- Removed the unused published count and UI observation of the internal mode. Cached immutable mascot paths and running-process signing metadata; metadata invalidates on application launch/termination, including the delayed refresh. Coalesced timer wakeups and removed a redundant Task per tick. Added a deadline check inside icon enumeration.
- Recompressed all ten PNG icon variants without loss: 1,188,725 → 871,335 bytes. Decompressed pixel/filter bytes and all non-image PNG chunks match exactly; approved appearance unchanged.
- Release uses size optimization, dead-code stripping and stripped local symbols. Universal executable: 662,272 bytes; arm64 slice: 318,208 bytes (previous arm64 executable: 693,360 bytes). App content: 1,537,098 bytes, including icon and both architectures. DMG: 1,642,493 bytes. No third-party runtime dependencies.
- Installed release signature verified. Installed, built and DMG-contained executables matched SHA-256: `f8b1cafc3b0ea26c360fd463199d1bcd4a772dd0a1f3e5aa2d18d02ebdb69fe8`.
- DMG checksum verified; mounted read-only; Applications symlink resolves to `/Applications`; signature and both architectures verified inside the image.
- Existing zone data compared semantically before/after installation: identical. Installed startup confirms Accessibility and native API available; launch-at-login choice unchanged.
- Idle process snapshot: 0.0% CPU, RSS 78,400 KiB. This is a snapshot, not a long-duration energy benchmark; no measured frame-rate claim.

Not checked: physical Intel hardware, other macOS versions, a real logout/login, VoiceOver/keyboard interaction or live frame pacing. The Intel target is deprecated by the macOS 27 SDK but compiles and passes under Rosetta. macOS 27 remains the minimum supported version; older systems are not advertised as supported.

The visibility API is private. The build is locally signed, not Apple-notarized; Gatekeeper may require user approval on another Mac. No Apple Developer ID credential was available for notarization. Signing keys, backup versions, build caches and personal verification records are excluded from Git.

Code review verdict: ship within the verified scope above. GitHub publication is deferred at the user's request; local sources and distribution are ready.
