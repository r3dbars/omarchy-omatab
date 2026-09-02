# Working on this plugin

Omarchy shell plugin: `manifest.json` at the root, `BarWidget.qml` is the
entry point and loads `Panel.qml`. Pure logic lives in `Model.js`, which the
QML engine loads as a plain script: `var` and `function` only, no `const`,
`let`, arrows, or template literals (a test enforces this).

Before committing:

```bash
node --test tests/
omarchy plugin validate .
git diff --check
```

The shell hot-reloads saved files under `~/.config/omarchy/plugins/`, but a
changed glyph or component may need `omarchy-restart-shell` to show.

Releasing: bump `version` in `manifest.json` (semver), commit, tag
`v<version>`, push the tag. Never move a published tag.

The plugin never runs setup on its own. `install.sh` only runs when a person
presses **Install Oma Tab** or **Update Oma Tab**, in a terminal they can
watch, and it is the only place sudo is used.
