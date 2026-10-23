# BooBar

**EN** — Hide the menu bar icons you rarely use. Three zones: always visible, reveal on hover, always hidden. Hold **⌘⇧** and drag icons to organize them.

**IT** — Nascondi le icone che usi meno nella barra menu. Tre zone: sempre visibili, al passaggio, sempre nascoste. Tieni **⌘⇧** e trascina le icone per organizzarle.

powered by [unshapedstudio](https://unshapedstudio.com/)

![BooBar](docs/settings-en.png)

## Install / Installa

Open the DMG and drag **BooBar → Applications**. / Apri il DMG e trascina **BooBar → Applicazioni**.

**macOS 27**, Apple Silicon + Intel (Universal). Accessibility permission required; BooBar opens the exact settings pane. English/Italian, optional launch at login. No network requests or third-party runtime dependencies.

**macOS 27**, Apple Silicon + Intel (Universal). Serve Accessibilità: BooBar apre la pagina corretta. Italiano/inglese, avvio al login facoltativo. Nessuna connessione in rete o dipendenza esterna nell’app.

Locally signed, **not notarized by Apple**: macOS may block the downloaded app; use System Settings → Privacy & Security → Open Anyway if you trust this build. / Firma locale, **senza notarizzazione Apple**: se macOS blocca l’app scaricata, usa Impostazioni di Sistema → Privacy e sicurezza → Apri comunque, se ritieni attendibile questa build.

## Notes / Note

Two separators define the zones: **always hidden · | · on hover · : · always visible**. Hover over `:` to reveal temporary icons; right-click it for settings. Icons belonging to the same app are grouped; always-visible wins. Reset and quit restore all icons.

Due separatori definiscono le zone: **sempre nascoste · | · al passaggio · : · sempre visibili**. Passa su `:` per mostrare le temporanee; clic destro per le impostazioni. Le icone della stessa app sono gestite insieme; prevale “sempre visibili”. Reset e uscita ripristinano le icone.

Uses a private macOS visibility API, which may change after an OS update. Tested on macOS 27.0.1 with Apple Silicon. Intel is cross-compiled; see [verification](docs/RELEASE-0.6.1.md) for the actual test scope.

Usa un’API privata di macOS, che può cambiare con gli aggiornamenti. Provata su macOS 27.0.1 con Apple Silicon. Intel compilata separatamente; ambito delle prove in [verifica](docs/RELEASE-0.6.1.md).

## Build

Xcode 27, no package dependencies:

```sh
zsh build-app.sh              # Universal: arm64 + x86_64
zsh build-app.sh arm64        # Apple Silicon only
zsh build-app.sh x86_64       # Intel only
zsh package-dmg.sh            # dist/BooBar-0.6.1-universal.dmg
swift test --scratch-path .build/tests
```

Builds use a persistent local signing identity in `.signing/` (never commit or share it). Set `BOOBAR_SIGN_IDENTITY` to use your own Developer ID instead; notarization is a separate release step. The legacy bundle identifier `it.marcovernetto.Hidebar` preserves existing permissions and zones.
