# Changelog

## Unreleased compatibility fixes

- Keep legacy popup dismissal working by forwarding direct hover-suppression writes through the scoped bar setter.

- Fix custom bar asset resolution and bar-scoped monitor settings, retaining read compatibility with existing monitor layouts. Clarify that processes run without elevated privileges.
- Regenerate from Omarchy 4.0.4-1 so replacement-bar widgets receive the current scoped bar, panel, registry, and own-service APIs.

All notable changes to this project are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `workspaceWidget` swaps the workspace widget for an installed plugin widget, scoped per monitor like the bundled one.
- Minimal outputs accept a `label` shown after the glyph and extra `modules` per region.

### Fixed

- The settings gear opens the panel through an injected callback instead of `bar.shell.summon`, which scoped shell APIs don't expose.

## [1.0.0] - 2026-08-26

### Added

- Per-monitor Full, Minimal, and Hidden bar modes.
- Primary monitor selection with a stock-compatible Full bar.
- Configurable monitor glyphs, workspace IDs, and workspace labels for Minimal bars.
- Monitor-scoped workspace display and dispatch.
- Settings panel with validation, unsaved-change protection, external-change handling, and stock-source sync controls.
- Generated stock `Bar.qml` and `BarModel.js` guarded by pinned SHA-256 hashes.

### Compatibility

- Supports Omarchy package `4.0.1-1` only.

[Unreleased]: https://github.com/PatrickFanella/omarchy-monitor-bar/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/PatrickFanella/omarchy-monitor-bar/releases/tag/v1.0.0
