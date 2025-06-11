# AeroBar

A configurable status bar for AeroSpace window manager.

## Local Development

**Requirements:**

- macOS 12.0+
- [AeroSpace](https://github.com/nikitabobko/AeroSpace) window manager
- Swift 5.9+

**Setup:**

```bash
git clone https://github.com/natrimmer/aerobar.git
cd aerobar
```

**Build and run:**

```bash
swift build -c release
./.build/release/AeroBar
```

**AeroSpace integration:**
Add to `~/.aerospace.toml`:

```toml
after-startup-command = ['exec-and-forget /path/to/aerobar/.build/release/AeroBar',]
exec-on-workspace-change = ['/path/to/aerobar/.build/release/AeroBar', '--callback']
```

## Features

- Real-time workspace switching
- Configurable positions (top/bottom/left/right)
- Custom colors (hex/RGB/named)
- CSS-style padding
- Window titles and app indicators
- Menu bar integration with workspace display

## Roadmap

- [ ] Devenv setup
- [ ] Homebrew release
- [ ] Configuration documentation

## Issues & Support

Found a bug or have a feature request? [Open an issue](https://github.com/natrimmer/aerobar/issues) on GitHub.

## License

GPL-3.0 License. See [LICENSE](LICENSE) for details.
