# Obsiclipcapture

> ⚠️ **Written entirely by Claude** (Anthropic's AI assistant). No human has reviewed the code line by line. Use at your own risk.

A Windows tray utility that writes into an Obsidian vault. Obsidian does not need to be running.

🇷🇺 [Русская версия](README.ru.md)

1. **Quick note** (default: right `Alt`). Opens a small input window. Creates a daily note and appends the typed text to it, stamped with the time. Text and images can be dragged straight into the window.
2. **Clip** (default: `Ctrl+Alt+F8`). Selected text in any program goes into a new Obsidian note. Copying by hand is unnecessary, the selection is enough. Texts from one browser page gather in one note. When the address changes deeper than the page's folder, the utility asks where the clip goes. The source address lands in the YAML `source` field. Properties and tags can be added to every new note through the settings.

## Requirements

- Windows 10 or 11. PowerShell 5.1 and .NET Framework ship with Windows.
- The [Advanced URI](https://github.com/Vinzent03/obsidian-advanced-uri) plugin in Obsidian, if a Templater command should fire after each clip.
- The Dataview plugin with JavaScript queries enabled, if you want the daily-note navigation arrows.

## First run

1. Put `Obsiclipcapture.ps1`, `start.vbs` and `nav-header.md` in one folder. Keep the script saved as UTF-8 **with BOM**, otherwise Cyrillic in the tray menu turns into garbage.
2. Run `start.vbs`. The tray icon appears after about three seconds.
3. The **Настройки клиппера** window opens by itself. Enter the full path to the vault, the clip folder and the attachments folder (paths inside the vault, for example `Накопитель` and `Serv\Attachments`). Save.
4. Right-click the icon → **Настройки заметок**. Check the capture folder and the filename template, change the hotkey if needed. Save.
5. Hover the icon: the tooltip shows both current hotkeys.

Settings live in `obsiclipcapture.cfg` next to the script. To skip the windows, drop a prepared `obsiclipcapture.cfg` into the folder before the first run.

**Autostart:** `Win+R` → `shell:startup` → put a shortcut to `start.vbs` there.

## If something does not work

Open `obsiclipcapture.log` next to the script first: it holds every launch, every error and the focus result of the note window.

- **No tray icon.** Run `Obsiclipcapture.ps1` from a PowerShell window, the error text will be on screen.
- **A hotkey is silent.** Another program holds that combination. Change it in the settings.
- **The note window has no cursor.** Find the line `Окно заметки: фокус НЕ получен` in the log, it ends with the program that kept the foreground.
- **Notes land in the wrong place.** Relative folders are resolved against the vault path, so an empty vault path sends notes somewhere unexpected.
