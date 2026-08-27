# Omarchy Monitor Bar

Omarchy Monitor Bar assigns a separate bar layout to each connected monitor. It keeps the stock Omarchy bar on the primary monitor and supports smaller or hidden bars on other outputs.

## Features

- Full, Minimal, or Hidden mode per monitor
- One primary monitor locked to Full mode
- A configurable glyph and workspace list for each Minimal bar
- Monitor-scoped workspace buttons and labels
- Stock bar position, transparency, widgets, panels, and trusted local commands on Full bars
- A settings panel with validation, conflict handling, and stock-source checks

## Requirements

- Omarchy package `4.0.1-1`
- The stock files installed under `/usr/share/omarchy/shell/plugins/bar`
- Python 3 for the settings panel's stock-source **Check** and **Sync** actions

The gear and configuration UI otherwise run without Node.js. Node.js is required only for development checks.

The generated `Bar.qml` and `BarModel.js` are pinned to the exact stock files from Omarchy `4.0.1-1`. Other Omarchy versions are unsupported until their stock sources are reviewed and the pinned hashes are updated.

## Install

```sh
omarchy plugin add https://github.com/PatrickFanella/omarchy-monitor-bar.git --enable --yes
```

No `shell.settings` patch is required.

## Open settings

Select the gear button on the primary bar, or run:

```sh
omarchy-shell shell summon patrickfanella.monitor-bar '{}'
```

## Configure monitor bars

1. Select a monitor.
2. Choose **Full**, **Minimal**, or **Hidden**.
3. To move the Full bar, select **Make primary**. The primary monitor is always Full.
4. For a Minimal bar, enter a glyph and add workspace IDs and labels. Workspace IDs must be unique positive integers.
5. Select **Save**.

Full uses the configured stock bar layout. Minimal shows only the monitor glyph and configured workspaces. Hidden removes the visible bar and its reserved screen space from that monitor.

## Keyboard and accessibility

The settings window supports Tab and Shift+Tab across Close, Save, position, transparency, monitor selection, Make primary, mode, glyph and workspace fields, Add and Remove, Check, Sync, Restart shell, Reload, and Rebase draft. Enter or Space activates buttons, toggles, and grouped choices. Dropdowns use Enter or Space to open, arrow keys to move, Enter to select, and Escape to close. Focused fields in the settings scroller are brought into view.

The unsaved-changes dialog traps focus across Cancel, Discard, and Save. The restart dialog owns focus and uses Left, Right, Tab, or Shift+Tab to choose an action. Enter or Space activates it. Escape cancels either dialog. Closing a dialog returns focus to the control that opened it when that control still exists. Adding a workspace focuses its new ID field. Removing one focuses the next Remove button, the previous row when needed, or Add when no rows remain.

The bar's layer-shell windows explicitly use `WlrKeyboardFocus.None`. Giving a persistent bar keyboard focus would steal keys from the active application, so the gear and workspace buttons cannot be reached by Tab while they remain in the bar. Their roles, names, descriptions, and selected state are exposed for accessibility APIs, and the controls retain pointer operation. Open settings with the summon command above. Use the configured Hyprland workspace shortcuts as the keyboard path for switching workspaces.

## Update or remove

Update the installed Git checkout:

```sh
omarchy plugin update patrickfanella.monitor-bar --yes
```

Remove the plugin:

```sh
omarchy plugin remove patrickfanella.monitor-bar --yes
```

## Configuration and recovery

The plugin stores its monitor configuration under the `patrickfanella.monitor-bar` key in `~/.config/omarchy/shell.json`. It also sets `bar.id`, `bar.position`, and `bar.transparent` through the Omarchy shell API. It does not edit `shell.settings`.

If the monitor configuration is absent, the first connected monitor becomes the primary Full monitor. Unknown monitors default to Hidden. The settings panel keeps disconnected configured monitors so you can edit their saved settings while they are offline.

If settings changed outside the open panel, choose **Reload** to discard the draft or **Rebase draft** to keep it against the new file state. If the generated stock copy is stale, open settings and use **Check** or **Sync**. Sync refuses an unrecognized stock hash instead of rewriting files from an unsupported Omarchy version.

The bar inherits trusted local command behavior from the stock Omarchy bar. Enabled stock widgets can run the same local commands they run in the built-in bar. The monitor workspace widget dispatches workspace focus through `hyprctl`. Install only from a source you trust.

## Compatibility and stock sync policy

Release `1.0.0` supports only Omarchy package `4.0.1-1`. `tools/sync_stock_bar.py` verifies the pinned SHA-256 hashes before generating `Bar.qml` and `BarModel.js`. The immutable source snapshots in `vendor/omarchy-4.0.1-1/bar` make this check reproducible in CI; the settings panel and the default CLI invocation check the installed sources. A maintainer must review upstream changes, update the snapshots, transforms, tests, and both hashes before claiming support for another package version.

Do not edit generated files. Change `tools/sync_stock_bar.py`, then run:

```sh
python3 tools/sync_stock_bar.py
```

To check generated files against the pinned snapshot instead of installed sources, run:

```sh
python3 tools/sync_stock_bar.py --upstream-dir vendor/omarchy-4.0.1-1/bar --check
```

## Develop and validate

Run the complete release check on an Omarchy system:

```sh
tools/validate.sh
```

The script runs the Node.js tests, Python tests and compile checks, generated-file check, `qmllint`, manifest validation, JSON parsing, and `git diff --check`.

## Manual release test matrix

Run these checks before each release:

| Case | Check |
| --- | --- |
| Fresh install | Add with `--enable --yes`; confirm the first connected monitor gets a Full bar. |
| Settings entry | Open from the gear and the summon command; confirm both target the same panel. |
| Full mode | Confirm stock widgets, panel routing, position, transparency, and drag behavior on the primary monitor. |
| Minimal mode | Set a glyph and workspace labels; confirm only configured workspaces appear on the selected monitor. |
| Hidden mode | Confirm no bar or reserved bar space remains on that monitor. |
| Primary change | Make another connected monitor primary; confirm it becomes Full and receives the gear button. |
| Monitor lifecycle | Disconnect and reconnect a configured monitor; confirm its saved mode and workspace list return. |
| Config conflict | Edit `shell.json` while the panel has an unsaved draft; confirm Reload and Rebase draft block accidental overwrite. |
| Stock sync | Run Check on `4.0.1-1`; confirm it reports Current. Test a changed stock file and confirm the hash guard rejects Sync. |
| Update and remove | Update by plugin ID, then remove with `--yes`; confirm Omarchy reports each operation without manual config patches. |

## License and attribution

Omarchy Monitor Bar is licensed under the MIT License. See [LICENSE](LICENSE).

Generated `Bar.qml` and `BarModel.js`, `Workspaces.qml`, and the pinned source snapshots derive from [Omarchy](https://github.com/basecamp/omarchy), Copyright David Heinemeier Hansson, under the MIT License. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
