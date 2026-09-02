# Oma Tab for Omarchy

The bar widget for [Oma Tab](https://github.com/r3dbars/tilde-linux): private,
local AI autocomplete for everything you type. Type, pause, and a grey
suggestion appears. `Tab` takes a word; `Shift+Tab` takes it all.

The widget is a `⇥` in the bar. Click it for the panel, right-click to pause
or resume suggestions.

The panel:

- Installs Oma Tab itself if it is missing, in a terminal you can watch, and
  shows setup progress in the panel.
- One switch for suggestions, one for reading the screen, one for the
  private local log.
- Shows which keys take a word and take everything.
- A model picker sized to your GPU, with an explicit download step.
- Median latency, suggestions shown, and how many you accepted.
- Try-it demo, update, and restart.

## Install

```bash
omarchy plugin add https://github.com/r3dbars/omarchy-omatab --enable
```

Then click the `⇥` in the bar and press **Install Oma Tab**. That runs
`install.sh`, which clones Oma Tab into `~/.local/src/omatab`, installs the
packages it needs, builds it, wires it into Fcitx, and downloads a model that
fits your GPU. Everything stays on your machine.

## Local development

```bash
omarchy plugin validate .
```

The shell reloads saved plugin files automatically.

## License

MIT
