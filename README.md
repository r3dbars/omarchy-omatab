# Tilde for Omarchy

An Omarchy bar widget and settings panel for
[Tilde Linux](https://github.com/r3dbars/tilde-linux).

The first local build provides:

- Tilde on/off control
- Active model and GPU memory status
- Context size and model warmup status
- Median latency, shown suggestions, and acceptance rate
- Private telemetry location and local-only reminder
- Warm, restart, logs, and refresh actions

## Requirements

Install Tilde Linux first so `~/.local/bin/tilde-control` is available.

## Local development

```bash
omarchy plugin validate .
omarchy plugin add <git-url> --enable
```

The shell reloads saved plugin files automatically.

## License

MIT
