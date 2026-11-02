# Официальный Roblox Studio MCP и Linux

Проверено по официальным источникам 2 ноября 2026 года.

## Текущий официальный вариант

[Roblox Creator Docs](https://create.roblox.com/docs/studio/mcp) описывает MCP,
встроенный в актуальную Studio. В Studio: **Assistant → … → Manage MCP Servers**
(либо Settings → MCP Servers) → **Enable Studio as MCP server**. Поддерживается
транспорт **stdio**, а Quick Connect включает Codex CLI.

Документация даёт команды для Windows (`%LOCALAPPDATA%\Roblox\mcp.bat` через
`cmd.exe`) и macOS (`RobloxStudio.app/Contents/MacOS/StudioMCP`). Официальный
[Roblox Studio agent plugin](https://github.com/Roblox/roblox-studio-agent-plugin)
также указывает Windows и macOS. Готовая официальная конфигурация для Linux/Vinegar
в этих источниках не опубликована.

Старый [Roblox/studio-rust-mcp-server](https://github.com/Roblox/studio-rust-mcp-server)
прямо сообщает, что больше активно не развивается, и рекомендует встроенный сервер.
Его старые инструкции и `--stdio` для `rbx-studio-mcp.exe` не следует путать
с новым `StudioMCP`/`mcp.bat`.

## Что это означает для Vinegar

Vinegar запускает Windows Studio в Wine внутри Flatpak. Linux-процесс Codex
не может напрямую запустить `cmd.exe`/Windows `.bat`. Для эксперимента потребовался
бы проверенный запуск **в том же Wine-префиксе и sandbox**, с корректным рабочим
каталогом, сохранением stdin/stdout и доступом к механизму связи Studio.
Установка Wine на хост не создаёт такую связь автоматически.

На этой машине такой запуск проверен; это локальный результат, а не официальная
гарантия совместимости Linux. Quick Connect из Wine также может искать Windows-клиент и
Windows-конфигурацию Codex вместо установленного на Ubuntu клиента.

## Настройка на этом компьютере

1. Открыть Studio через Vinegar. Внизу окна должен появиться **MCP Ready**.
2. Из корня проекта проверить пути без запуска сервера:

   ```bash
   python3 scripts/studio_mcp.py --check
   ```

3. Регистрация уже выполнена. При переносе проекта обновить абсолютный путь:

   ```bash
   codex mcp add Roblox_Studio -- /usr/bin/python3 "$PWD/scripts/studio_mcp.py"
   codex mcp get Roblox_Studio
   ```

   По [документации Codex MCP](https://learn.chatgpt.com/docs/extend/mcp)
   локальный сервер задаётся командой и аргументами; конфигурация использует TOML
   (`mcp_servers`), а не произвольный `mcpServers` JSON другого клиента.
4. Перезапустить клиент/начать новый сеанс. Проверить MCP initialize, список
   инструментов, затем чтение имени открытого place и только затем пробный Play.

**Статус на этой машине:** Studio и её официальный `StudioMCP.exe` установлены
через Vinegar. Бинарник обнаружен в
`~/.var/app/org.vinegarhq.Vinegar/data/vinegar/versions/version-7062aec9dbe74b14/StudioMCP.exe`.
Пользователь выполнил вход, локальная сцена открыта. В отдельной пробе официальный
бинарник был запущен через Kombucha внутри того же Flatpak sandbox и Wine-префикса.
Подтверждены ответы MCP `initialize` (сервер `RobloxStudio`, версия `1.0.0`)
и `tools/list`. Среди инструментов есть `list_roblox_studios`, `execute_luau`,
`get_studio_state`, `start_stop_play`. Реально выполнены чтение дерева Edit,
запуск/остановка Play, чтение персонажа, HUD и баланса из Client/Server.
После исправления координат сцены эмуляция E дала 10, затем 20 монет;
спам и немедленный повтор не дали лишней награды, отход отменил следующую награду.
Клиентский HUD отобразил 20. Play остановлен, временный атрибут теста удалён.
Launcher выбирает запущенный Flatpak sandbox Vinegar и установленный официальный
`StudioMCP.exe`, затем передаёт ему stdin/stdout через `flatpak enter` и Kombucha.
Он не скачивает программы и не создаёт собственный MCP-сервер. При нескольких
sandbox выбирается самый новый; перед тестом оставлять одну Studio и всегда
проверять `studio_id`, имя и содержимое place. Сторонние мосты не использовались.
Репозиторий собирается, проверяется и
синхронизируется Rojo без MCP. MCP-изменения в управляемых Rojo скриптах нужно
переносить обратно в исходники до следующей синхронизации.
