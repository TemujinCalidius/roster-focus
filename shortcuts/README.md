# Prebuilt Focus Shortcuts

RosterFocus toggles a Focus by running a macOS **Shortcut** — you normally build
those by hand (see [../SETUP.md](../SETUP.md) step 2). These prebuilt, signed
shortcuts save you that step for the **Work** Focus:

| File | What it does | Use as |
|------|--------------|--------|
| `Work Focus On.shortcut` | Turns the **Work** Focus on | `on_shortcut` |
| `Work Focus Off.shortcut` | Turns the **Work** Focus off | `off_shortcut` |

## Install

Double-click each `.shortcut` (or `open "Work Focus On.shortcut"`), then click
**Add Shortcut** in the dialog. They'll appear in Shortcuts.app with exactly the
names RosterFocus's example config expects. Test each:

```bash
shortcuts run "Work Focus On"
shortcuts run "Work Focus Off"
```

## ⚠️ The Focus identifier caveat

These shortcuts target the **built-in Work Focus** (`com.apple.focus.work`). That
works for most people, but:

- If your "Work" Focus is a **custom** Focus you created, its identifier is a
  per-user UUID, not `com.apple.focus.work`. The import may not bind to it.
- After importing, **open the shortcut in Shortcuts.app and confirm the Set Focus
  action shows your Work Focus.** If it's blank or wrong, just re-pick your Focus
  in the action — that's the most reliable fix.

If you use a different Focus (Do Not Disturb, Sleep, a custom one), it's usually
easiest to build that pair by hand (SETUP.md step 2), or edit and re-sign — see
below.

## Rebuilding / making your own

The editable sources live in `src/*.unsigned.shortcut` (plain XML plists). To
target a different Focus, change the `Identifier` / `DisplayString` under
`FocusModes`, then re-sign:

```bash
./build.sh
```

> Signing gotcha: the **input** file must end in `.shortcut` (not `.plist`), or
> `shortcuts sign` treats it as the old format. That's why the sources are named
> `*.unsigned.shortcut`.

Common built-in Focus identifiers: `com.apple.focus.work`,
`com.apple.donotdisturb.mode.default` (Do Not Disturb), `com.apple.focus.personal`,
`com.apple.sleep.sleep-mode` (Sleep). Custom Focuses use a per-device UUID, so
pick those in the Shortcuts editor rather than hard-coding an identifier.
