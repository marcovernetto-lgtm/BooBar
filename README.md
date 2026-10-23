# BooBar

powered by [unshapedstudio](https://unshapedstudio.com/)

[English](#english) · [Italiano](#italiano)

![BooBar](docs/settings-en.png)

## English

Hide the menu bar icons you rarely use. Three zones: **always visible, reveal on hover, always hidden**. Hold **⌘⇧** and drag icons to organize them.

### Install

[Download BooBar](https://github.com/marcovernetto-lgtm/BooBar/releases/latest). Open the DMG and drag **BooBar → Applications**.

**macOS 27**, Apple Silicon + Intel (Universal). Accessibility permission required; BooBar opens the exact settings pane. English/Italian, optional launch at login. No network requests or third-party runtime dependencies.

Locally signed, **not notarized by Apple**. If macOS blocks the downloaded app, use System Settings → Privacy & Security → Open Anyway if you trust this build.

### How it works

**Always hidden · | · On hover · : · Always visible**

Hover over `:` to reveal temporary icons; right-click it for settings. Icons belonging to the same app are grouped; always-visible wins. Reset and quit restore all icons.

Uses a private macOS visibility API, which may change after an OS update. Tested on macOS 27.0.1 with Apple Silicon; Intel tests passed under Rosetta, without physical Intel hardware verification. See [verification](docs/RELEASE-0.6.1.md).

### Build

Xcode 27, no package dependencies:

```sh
zsh build-app.sh              # Universal: arm64 + x86_64
zsh build-app.sh arm64        # Apple Silicon only
zsh build-app.sh x86_64       # Intel only
zsh package-dmg.sh            # dist/BooBar-0.6.1-universal.dmg
swift test --scratch-path .build/tests
```

Builds use a persistent local signing identity in `.signing/` (never commit or share it). Set `BOOBAR_SIGN_IDENTITY` to use your own Developer ID; notarization is a separate release step. The legacy bundle identifier `it.marcovernetto.Hidebar` preserves existing permissions and zones.

---

## Italiano

Nascondi le icone che usi meno nella barra menu. Tre zone: **sempre visibili, al passaggio, sempre nascoste**. Tieni **⌘⇧** e trascina le icone per organizzarle.

### Installazione

[Scarica BooBar](https://github.com/marcovernetto-lgtm/BooBar/releases/latest). Apri il DMG e trascina **BooBar → Applicazioni**.

**macOS 27**, Apple Silicon + Intel (Universal). Serve Accessibilità: BooBar apre la pagina corretta. Italiano/inglese, avvio al login facoltativo. Nessuna connessione in rete o dipendenza esterna nell’app.

Firma locale, **senza notarizzazione Apple**. Se macOS blocca l’app scaricata, usa Impostazioni di Sistema → Privacy e sicurezza → Apri comunque, se ritieni attendibile questa build.

### Come funziona

**Sempre nascoste · | · Al passaggio · : · Sempre visibili**

Passa su `:` per mostrare le temporanee; clic destro per le impostazioni. Le icone della stessa app sono gestite insieme; prevale “sempre visibili”. Reset e uscita ripristinano le icone.

Usa un’API privata di macOS, che può cambiare con gli aggiornamenti. Provata su macOS 27.0.1 con Apple Silicon; test Intel superati tramite Rosetta, senza verifica su hardware Intel fisico. Vedi la [verifica](docs/RELEASE-0.6.1.md).

### Compilazione

Xcode 27, nessuna dipendenza esterna:

```sh
zsh build-app.sh              # Universal: arm64 + x86_64
zsh build-app.sh arm64        # Solo Apple Silicon
zsh build-app.sh x86_64       # Solo Intel
zsh package-dmg.sh            # dist/BooBar-0.6.1-universal.dmg
swift test --scratch-path .build/tests
```

La compilazione usa una firma locale persistente in `.signing/`: non caricarla su Git e non condividerla. Imposta `BOOBAR_SIGN_IDENTITY` per usare il tuo Developer ID; la notarizzazione richiede un passaggio separato. L’identificatore storico `it.marcovernetto.Hidebar` conserva permessi e zone esistenti.
