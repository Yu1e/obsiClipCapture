<p align="center"><img src="obsiclipcapture.svg" width="96" alt="Obsiclipcapture"></p>

# Obsiclipcapture

> ⚠️ **Written entirely by Claude** (Anthropic's AI assistant). No human has reviewed the code line by line. Use at your own risk.
> ⚠️ **Написано полностью Клодом** (ИИ-ассистент Anthropic). Построчной проверки кода человеком не было. Используйте на свой риск.

<details open>
<summary><b>🇬🇧 English</b></summary>

A Windows tray utility that writes into an Obsidian vault. Obsidian does not need to be running.

1. **Quick note** (default: right `Alt`). Opens a small input window. Creates a daily note and appends the typed text to it, stamped with the time. Text and images can be dragged straight into the window.
2. **Clip** (default: `Ctrl+Alt+F8`). Selected text in any program goes into a new Obsidian note. Copying by hand is unnecessary, the selection is enough. Texts from one browser page gather in one note. When the address changes deeper than the page's folder, the utility asks where the clip goes. The source address lands in the YAML `source` field. Properties and tags can be added to every new note through the settings.

## Requirements

- Windows 10 or 11. PowerShell 5.1 and .NET Framework ship with Windows.
- The [Advanced URI](https://github.com/Vinzent03/obsidian-advanced-uri) plugin in Obsidian, if a Templater command should fire after each clip.
- The Dataview plugin with JavaScript queries enabled, if you want the daily-note navigation arrows.

## First run

1. Put `Obsiclipcapture.ps1`, `start.vbs`, `nav-header.md` and `obsiclipcapture.ico` (the tray icon, optional) in one folder. Keep the script saved as UTF-8 **with BOM**, otherwise Cyrillic in the tray menu turns into garbage.
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
- **The tray icon is still the round "info" one.** Put the fresh `Obsiclipcapture.ps1` and `obsiclipcapture.ico` into the same folder and restart. The log line starting with `Значок:` says what happened to the icon.
- **A second launch shows nothing.** The utility is already running: only one copy lives at a time. The log notes the ignored launch.

</details>

<details>
<summary><b>🇷🇺 Русский</b></summary>

Утилита для Windows, живёт в трее. Пишет в хранилище Obsidian, сам Obsidian при этом запускать не нужно.

1. **Быстрая заметка** (по умолчанию правый `Alt`). Вызывает всплывающее окно для ввода текста. Создаёт ежедневную заметку и складывает введённый текст в неё, с пометкой времени. Текст и изображения можно перетаскивать прямо в окно.
2. **Клип** (по умолчанию `Ctrl+Alt+F8`). Выделенный текст в любой программе отправляется в новую заметку Obsidian. Копировать текст самому не требуется, хватает выделения. Тексты с одной страницы браузера собираются в одну заметку. Если адрес сменился глубже, чем папка страницы, утилита спрашивает, куда писать. Адрес источника заносится в YAML, в поле `source`. Можно настроить добавление свойств и тегов при создании заметки.

## Что нужно

- Windows 10 или 11. PowerShell 5.1 и .NET Framework идут в комплекте с Windows.
- Плагин [Advanced URI](https://github.com/Vinzent03/obsidian-advanced-uri) в Obsidian, если после каждого клипа должна срабатывать команда Templater.
- Плагин Dataview с включёнными JavaScript-запросами, если нужны стрелки навигации по ежедневкам.

## Первый запуск

1. Положить `Obsiclipcapture.ps1`, `start.vbs`, `nav-header.md` и `obsiclipcapture.ico` (значок в трее, необязателен) в одну папку. Скрипт хранить в UTF-8 **с BOM**, иначе кириллица в меню трея превратится в кракозябры.
2. Запустить `start.vbs`. Иконка появится в трее секунд через три.
3. Само откроется окно **Настройки клиппера**. Указать полный путь к хранилищу, папку для клипов и папку вложений (пути внутри хранилища, например `Накопитель` и `Serv\Attachments`). Сохранить.
4. Правый клик по иконке → **Настройки заметок**. Проверить папку-накопитель и шаблон имени файла, при желании выбрать горячую клавишу. Сохранить.
5. Навести курсор на иконку: подсказка покажет оба текущих сочетания клавиш.

Настройки лежат в `obsiclipcapture.cfg` рядом со скриптом. Чтобы обойтись без окон, можно положить готовый `obsiclipcapture.cfg` в папку до первого запуска.

**Автозапуск:** `Win+R` → `shell:startup` → положить туда ярлык на `start.vbs`.

## Если что-то не работает

Первым делом открыть `obsiclipcapture.log` рядом со скриптом: там каждый запуск, каждая ошибка и результат захвата фокуса окном заметки.

- **Иконки нет.** Запустить `Obsiclipcapture.ps1` из окна PowerShell, текст ошибки будет на экране.
- **Сочетание молчит.** Его занимает другая программа. Сменить сочетание в настройках.
- **В окне заметки нет курсора.** Найти в логе строку `Окно заметки: фокус НЕ получен`, в её конце названа программа, державшая передний план.
- **Заметка уходит не туда.** Относительные папки считаются от пути к хранилищу, поэтому пустой путь к хранилищу даёт неожиданное место.
- **В трее по-прежнему круглая «информация».** Положить свежие `Obsiclipcapture.ps1` и `obsiclipcapture.ico` в одну папку и перезапустить. Строка лога, начинающаяся с `Значок:`, говорит, что случилось со значком.
- **Повторный запуск ничего не показывает.** Утилита уже работает: копия живёт одна. Проигнорированный запуск записывается в лог.

</details>
