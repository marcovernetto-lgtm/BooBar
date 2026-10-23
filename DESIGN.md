---
name: BooBar
description: Native macOS settings with SecureCopy's petrol and mint appearance and an articulated BooB mascot.
colors:
  primary: "#287c83"
  accent: "#a4dcd5"
  background: "#0e171b"
  panel: "#253136"
  text: "#edf3f3"
  muted: "#a4b5b8"
  border: "rgba(223,240,235,0.14)"
  warning: "#eab47b"
typography:
  display:
    fontFamily: AvenirNext-DemiBold
    fontSize: 28px
    letterSpacing: -0.6px
  title:
    fontFamily: AvenirNext-DemiBold
    fontSize: 16px
  body:
    fontFamily: AvenirNext-Regular
    fontSize: 13px
  label:
    fontFamily: AvenirNext-DemiBold
    fontSize: 12px
  caption:
    fontFamily: AvenirNext-Regular
    fontSize: 11px
rounded:
  shortcut: 8px
  control: 10px
  panel: 18px
spacing:
  compact: 8px
  controls: 12px
  header: 16px
  panel: 21px
  sections: 25px
  horizontal-inset: 32px
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.text}"
    typography: "{typography.label}"
    rounded: "{rounded.control}"
    padding: 0px 14px
  button-secondary:
    backgroundColor: "rgba(164,220,213,0.055)"
    textColor: "{colors.text}"
    typography: "{typography.label}"
    rounded: "{rounded.control}"
    padding: 0px 14px
  button-secondary-hover:
    backgroundColor: "rgba(164,220,213,0.13)"
  settings-panel:
    backgroundColor: "rgba(37,49,54,0.78)"
    rounded: "{rounded.panel}"
    padding: 21px
  zone-ribbon:
    backgroundColor: "rgba(37,49,54,0.55)"
    rounded: "{rounded.panel}"
    padding: 21px 18px
---

# Design System: BooBar

## Overview

**Creative North Star: "SecureCopy's native companion"**

The user-pinned SecureCopy screenshots and [appearance.css](../SecureCopy_/SecureCopy/appearance.css) establish the visual authority: deep petrol, slate panels, mint accents and Avenir Next. This document records the implemented SwiftUI/AppKit interpretation; the source-linked tokens above are authoritative for BooBar.

The native settings surface supports operating a small menu-bar utility. BooB supplies the playful identity through independently articulated vector parts, while controls remain quiet and readable.

**Key Characteristics:**

- Petrol and mint palette with tonal depth.
- Compact native controls and a fixed dark appearance.
- Articulated B-o-o-B identity without a background tile.

## Colors

### Primary

Petrol teal (`primary`) fills the permission action and tints the native login switch. Pale mint (`accent`) marks symbols, permission success, boundary markers and inline actions.

### Neutral

Deep petrol (`background`), slate (`panel`), near-white (`text`) and muted blue-gray (`muted`) establish the reading hierarchy. Translucent pale borders separate panels and rows. Warm amber (`warning`) identifies notices.

Source: [BooPalette.swift](Sources/BooBar/BooPalette.swift); warning and panel opacity assignments: [SettingsView.swift](Sources/BooBar/SettingsView.swift). The border alpha is BooBar's implemented value, rather than SecureCopy's different CSS alpha.

**The Fixed Dark Rule.** Keep the settings palette dark independently of the host appearance; `SettingsView` explicitly sets the dark color scheme.

## Typography

**Display Font:** AvenirNext-DemiBold.
**Body Font:** AvenirNext-Regular.
**Label/Mono Font:** Native system monospaced for the keyboard badge and separator characters; SF Symbols for functional icons.

### Hierarchy

The frontmatter records the reused display, section-title, body, action-label and caption styles. The subtitle uses regular Avenir Next (14pt); row titles use DemiBold (13pt); helper and inline-action text also use regular (12pt). The Command-Shift badge uses 22pt system monospace, with 16pt instruction text. SwiftUI supplies line metrics; there is no custom line-height or font fallback declaration.

Sources: `BooPalette.font` and [SettingsView.swift](Sources/BooBar/SettingsView.swift). Portable frontmatter uses pixel labels for the observed numeric values; native SwiftUI geometry and type are measured in points.

## Layout

The current Operate surface is a fixed-width panel (620pt), with a scrollable height capped at 790pt and the available screen height. Horizontal inset is the frontmatter token; top/bottom insets are 30/20pt. The header places title and subtitle beside a mascot frame (230 × 111pt). The three-zone ribbon, settings rows and footer form a single vertical composition without a sidebar. Pending permissions and service notices expand the height. No responsive breakpoint is implemented.

Source: [SettingsView.swift](Sources/BooBar/SettingsView.swift). This describes the current surface, rather than requiring all future windows to share its composition.

## Elevation & Depth

Depth comes from translucent slate surfaces, fine borders (1pt) and a stationary top-right petrol radial wash (primary at 23% opacity, radius 520pt). The implementation declares no shadows or backdrop blur. SecureCopy's glass and web animation are reference material, not additional BooBar tokens.

## Shapes

Panels use the broad rounded token; controls and setting-icon tiles use the control token; the keyboard badge uses the shortcut token. Icons sit in square tiles (30pt), mint at 8% opacity; the language row uses a monochrome native vector globe, identical in both languages; no country flags. Preserve the mascot's open silhouette and two central eyes; no white rectangular tile surrounds it.

## Components

### Buttons

`BooButtonStyle` uses DemiBold labels, horizontal padding from the component tokens, minimum height (36pt), a fine border and rounded shape. Secondary hover changes mint fill opacity; primary hover retains the primary fill. Pressed opacity is 0.7, disabled opacity 0.4, and hover easing is ease-out (0.15s). Inline restart/login-settings actions use native plain buttons.

The style does not define a custom focus ring. Preserve native Button keyboard/Accessibility semantics and verify visible keyboard focus in the installed app; rendered captures do not establish this behavior. Quit declares Command-Q and both footer actions have help text.

### Cards / Containers

The zone ribbon and settings panel use their frontmatter variants, the shared border and tonal depth. Five settings rows (permission, login, language, global shortcut, automatic updates) are separated by a fine divider. The language picker changes all UI strings immediately and persists the choice. The footer has no organization count and includes a quiet linked studio credit. Permission success has a textual label and symbol; pending permission exposes an explicit action and restart helper. Login approval and service errors remain visible as text.

### Native Switch

Launch at login uses `Toggle` with native switch style, the primary tint and a retained Accessibility label despite its hidden visual label. Do not substitute a drawn imitation. Keyboard traversal and Accessibility behavior require installed-app interaction verification.

### BooB

[AnimatedMascot.swift](Sources/BooBar/AnimatedMascot.swift) owns `MascotPose`, `BooVector` and `MascotFrame`. A shared ordered layer model supplies native Canvas paths and layered SVG export: two B silhouettes, independent eyes/pupils/glints, smile, and separate hands/outlines/finger details. Cream and ink match the text/background identity. The original bitmap is retained locally as brand reference, excluded from the release repository; the runtime mascot loads no image resources.

The timeline repeats over 6.4 seconds with separate hand, gaze, blink and breathing channels. Hands cover and reveal at different times; eyes look and blink independently. Smoothstep interpolates pose keys. Scheduling requests a minimum interval of 1/30 second while active; this is not proof of measured frame pacing. Reduce Motion renders the friendly resting pose, inactive settings pause the timeline and use that pose, and reactivation resets the start time. The mascot is one named Accessibility element with ignored child detail.

## Do's and Don'ts

### Do:

- **Do** derive appearance from the actual SwiftUI tokens and the pinned SecureCopy reference.
- **Do** preserve native switch, button, keyboard and Accessibility semantics.
- **Do** retain the independently articulated vector identity and motion accommodations.
- **Do** preserve signing and persistent legacy identifiers for compatibility when changing visual branding.

### Don't:

- **Don't** introduce a different identity, white mascot tile or blank animation frame.
- **Don't** describe web detector output or HTML approximations as native UI evidence.
- **Don't** equate native render review with installed-app interaction or measured live frame pacing.

Evidence: current NSHostingView renders in `.build/previews/settings-{it,en}-{dark,light}-{active,pending}.png` and `mascot-*.png`. Both translations and permission states were inspected. Prior independent finish review approved the 0.5 captured settings and articulated mascot; the 0.6 refinement was reviewed in-thread. These captures do not prove installed-app interaction or live frame pacing.

Version 0.7 adds native shortcut recording and opt-out automatic updates. Preserve Escape cancellation, Delete clearing, collision feedback, busy/error status and scrolling on smaller displays. Public README remains download-focused.
