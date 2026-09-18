# Obsiclipcapture

> ⚠️ **Written entirely by Claude.** Every line of code here, and both README files, were produced by Claude — Anthropic's AI assistant — in a chat conversation. The repository owner set the requirements and tested the result in daily use; no human has reviewed the code line by line. Use at your own risk.

A Windows tray utility that writes into an Obsidian vault without Obsidian running. Two jobs, one process, one tray icon:

| Job | Default hotkey | What happens |
|---|---|---|
| **Clip** | `Ctrl+Alt+F8` | Copies the current selection into a new note, with a `source` property holding the page URL or window title |
| **Quick note** | Right `Alt` | Opens a small input window; text is appended to a running markdown file |

Notes land as plain markdown files on disk. Obsidian picks them up on its next scan, so it does not need to be open — or even installed on the machine doing the capture.

🇷🇺 [Русская версия](README.ru.md)

## Requirements

- Windows 10 or 11
- PowerShell 5.1 and .NET Framework 4.x — both ship with Windows
- Obsidian, optionally. Only the "jump to note" button and the Templater hook need it
- [Advanced URI](https://github.com/Vinzent03/obsidian-advanced-uri) plugin, if you want a Templater command to fire on each clip

## Install

1. Put `Obsiclipcapture.ps1` and `start.vbs` in the same folder.
2. Run `start.vbs` (or `Obsiclipcapture.bat`). The tray icon appears after about three seconds — the delay lets Windows settle when the utility starts with the system.
3. The clipper settings window opens on first run. Fill in the full path to your vault and save.
4. Right-click the tray icon → **Настройки заметок** to set up the quick-note side.

To skip the wizard, drop a prepared `obsiclipcapture.cfg` next to the script before the first run.

### Autostart

`Win+R` → `shell:startup` → Enter, then put a shortcut to `start.vbs` in the folder that opens.

## Quick notes

| Action | Keys |
|---|---|
| Open the window | right `Alt`, left-click on the tray icon, or tray menu → Новая заметка |
| Save and close | `Ctrl+Enter` |
| Close without saving | `Escape` |

Text closed with `Escape` is kept as a draft and comes back on the next call, until the utility restarts. The window remembers its size and position the moment you close it.

A day's file ends up looking like this:

```markdown
---
tags: ежедневка
создано: 2026 09 18
---

🕐 First thought

🕝 Second thought
```

The clock emoji steps in half-hour increments — 🕐 🕜 🕑 🕝 and so on — which keeps a sense of when a note was written without stamping an exact time on it.

## Settings

Everything lives in `obsiclipcapture.cfg` next to the script, in `key=value` form. Two windows edit it: **Настройки клиппера** and **Настройки заметок**. Each writes only its own half, so the other half survives untouched.

### Clipper

| Field | Meaning |
|---|---|
| Vault path | Full path to the Obsidian vault |
| Notes folder | Where clips are created, relative to the vault |
| Attachments folder | Where clipped images are saved, relative to the vault |
| Date property, date format | The property name and .NET date format written into each clip |
| Note properties | Extra frontmatter keys added to every clip |
| Templater command | A command id fired through Advanced URI after the clip is written |
| Hotkey | `Ctrl` / `Alt` / `Shift` plus an F-key |

### Quick notes

| Field | Meaning |
|---|---|
| Capture folder | Relative to the vault, or an absolute path with a drive letter — including somewhere outside the vault |
| Filename template | `{date:FORMAT}` with any .NET date format. Subfolders are allowed: `{date:yyyy}\Week {date:ww}.md` |
| Entry template | `{clock}` for the clock emoji, `{text}` for the note body |
| Entry separator | `\n\n` for a blank line between entries, `\n` for consecutive lines |
| Note properties | Frontmatter written when the file is created. Values accept `{date:FORMAT}` |
| Single modifier | Right `Alt` and friends, caught by keyboard polling |
| Modifier + F-key | Used when the single modifier is set to «не использовать» |
| Theme | Light or dark |
| Flash count | How many times the title bar flashes on appearance. `0` for none |
| Font, size | The input field |

## How it works

One PowerShell script compiles a set of C# classes through `Add-Type` and runs a hidden carrier form that owns both hotkeys and the tray icon.

The clipper hotkey goes through `RegisterHotKey`. The quick-note hotkey takes one of two paths: `RegisterHotKey` for a modifier-plus-key combination, or a 40 ms `GetAsyncKeyState` poll when a bare modifier like right `Alt` is chosen — Windows refuses to register a lone modifier as a hotkey, so polling is the way in.

Clipping reads the selection by injecting `Ctrl+C` with `keybd_event`, after waiting for the physical modifiers of the hotkey to come back up. Holding them would turn the injected keystroke into `Ctrl+Alt+C` and leave the clipboard empty. The previous clipboard contents are restored afterwards.

## Troubleshooting

Start with `obsiclipcapture.log` next to the script. Every launch and every compilation error goes there.

**No tray icon.** Run `Obsiclipcapture.ps1` straight from a PowerShell window; the error text will be on screen.

**A console window appears or lingers.** The launcher is the thing to change, and launching through `start.vbs` rather than calling `powershell.exe` from a batch file is what keeps the console from being created at all.

**One hotkey is silent.** Hover the tray icon — the tooltip shows both current combinations. A balloon at startup about failed registration means another program holds that combination.

**Garbled Cyrillic in the tray menu.** `Obsiclipcapture.ps1` was re-saved without a BOM. PowerShell 5.1 then reads it as ANSI. Save it as UTF-8 with BOM.

**Notes go to the wrong place.** A relative capture folder is resolved against the vault path, so an empty vault path sends notes somewhere unexpected.

## Repository files

| File | Role |
|---|---|
| `Obsiclipcapture.ps1` | The utility. Save as UTF-8 **with BOM** |
| `start.vbs` | Launcher — starts PowerShell with no console window |
| `Obsiclipcapture.bat` | Optional batch wrapper around `start.vbs` |
| `obsiclipcapture.cfg` | Settings. Created on first run |
| `obsiclipcapture.log` | Launch and error log |

`obsiclipcapture.cfg` and `obsiclipcapture.log` hold local paths — worth keeping out of commits.
