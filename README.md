# Roblox Life — локальный прототип

Ubuntu + VS Code/Codex + Luau + Rojo. Минимальная сцена: квартира, стандартный
игровой персонаж, раковина и монеты за мытьё посуды. Сохранений, магазина и
покупок пока нет; монеты живут до выхода игрока из сервера.

Фактические результаты настройки и оставшиеся ограничения: [docs/ENVIRONMENT.md](docs/ENVIRONMENT.md).

Репозиторий: [Danil-super/roblox-life](https://github.com/Danil-super/roblox-life).
Локальный `origin` настроен на `https://github.com/Danil-super/roblox-life.git`;
GitHub CLI авторизован, Git использует его credential helper. Перед push запускать `bash scripts/dev.sh check`,
проверять `git status` и состав коммита; `.tools`, сборки и приватные настройки
в репозиторий не включать.

GitHub Actions (`.github/workflows/check.yml`) запускает те же проверки при
push и pull request на Ubuntu 24.04. Инструменты скачиваются с проверкой SHA-256,
workflow имеет только право чтения исходников. Результаты: вкладка
[Actions](https://github.com/Danil-super/roblox-life/actions).

## Быстрый старт

Открыть терминал **в корне этого проекта**:

```bash
python3 scripts/bootstrap.py
export PATH="$PWD/.tools/bin:$HOME/.rokit/bin:$PATH"
bash scripts/dev.sh prepare
bash scripts/dev.sh check
code roblox-life.local.code-workspace
```

Bootstrap рассчитан на Ubuntu x86_64. Он оставляет уже доступные инструменты,
загружает недостающие из официальных GitHub Releases в `.tools/bin` и проверяет
SHA-256 по `scripts/toolchain.json`. Системные каталоги и shell-профиль не меняются.
Повторный запуск не переустанавливает инструменты. Если найденная системная версия
отличается от `rokit.toml`, проверить совместимость или использовать закреплённый
Rokit toolchain отдельно.

Для новой машины достаточно `git`, `python3`, `curl`, VS Code и Flatpak:

```bash
sudo apt update
sudo apt install git python3 curl unzip flatpak
```

На уже настроенной машине не нужно повторно ставить эти пакеты. Rust, Node.js,
Docker и Wally для прототипа не требуются.

Основной менеджер версий инструментов — [Rokit](https://github.com/rojo-rbx/rokit):
`rokit.toml` фиксирует Rojo, Selene, StyLua, luau-lsp и Luau CLI. Если Rokit
уже установлен обычным способом, вместо bootstrap можно выполнить `rokit install`
и подтвердить доверие перечисленным официальным репозиториям. В этой настройке
локальные бинарники используются как резервный путь при лимите GitHub API.
На текущей машине Rokit уже установлен в `~/.rokit/bin`, `rokit install`
проверен. Новый терминал получает этот каталог через настройки shell.
Для постоянной установки самого менеджера на новой машине после bootstrap:

```bash
.tools/bin/rokit self-install
# Далее следовать выводу Rokit и открыть новый терминал.
rokit install
```

## VS Code и Codex

Установить рекомендованные расширения через Extensions → `@recommended`:

- `JohnnyMorganz.luau-lsp` — типы и навигация Roblox.
- `JohnnyMorganz.stylua` — форматирование при сохранении.
- `Kampfkarren.selene-vscode` — статический анализ.
- `evaera.vscode-rojo` — необязательный интерфейс Rojo.
- `openai.chatgpt` — Codex (используется существующая установка и авторизация).

Bootstrap также создаёт игнорируемый Git файл `roblox-life.local.code-workspace`
с абсолютными путями к установленным бинарникам. Открывать его, чтобы расширения
использовали именно подготовленные инструменты. После переноса папки выполнить
`python3 scripts/configure_editor.py` снова. Настройки других проектов не меняются.

`.vscode/tasks.json`: **Check all**, **Rojo: build**, **Rojo: serve**,
**Rojo: sourcemap**, **Format Luau**. Задачи сами добавляют `.tools/bin` в PATH.
Настроены strict-типы и формат Luau; Lua Language Server для обычного Lua
не нужен. Sourcemap генерируется задачей/проверками. После изменения структуры
src запустить задачу sourcemap либо watch в отдельном терминале:

```bash
export PATH="$PWD/.tools/bin:$HOME/.rokit/bin:$PATH"
rojo sourcemap default.project.json --include-non-scripts --watch --output sourcemap.json
```

Для Codex достаточно открыть папку и дать задачу: правила находятся в `AGENTS.md`.
Не передавать Codex пароль Roblox или cookie `.ROBLOSECURITY`. Вход в Studio
выполняется пользователем в штатном интерфейсе.

## Roblox Studio через Vinegar Flatpak

[Vinegar официально распространяется через Flathub](https://vinegarhq.org/Vinegar/Installation.html).
Проверить наличие и при необходимости установить:

```bash
flatpak info org.vinegarhq.Vinegar
# Только если приложения нет:
flatpak install flathub org.vinegarhq.Vinegar
flatpak run org.vinegarhq.Vinegar
```

Если отсутствует remote Flathub:

```bash
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
```

Первый запуск загружает Windows Studio и подготавливает Wine. Войти в Roblox
самостоятельно. Требуются графическая сессия и совместимый драйвер GPU. Не
устанавливать вторую копию Wine на хост специально для Vinegar.

На текущей машине Vinegar, Studio, Kombucha, WebView и DXVK уже установлены.
Если Studio показывает **Launch Failed** при входе, нажать **Login via Browser**
и войти через системный браузер. Приложению уже выдан доступ на чтение проекта.
Масштаб Studio по просьбе пользователя возвращён к **100% (96 DPI)**. Изменить его можно через
Vinegar → **Продвинутые настройки Wine** (Advanced Wine Settings) → Graphics → Screen resolution; затем
перезапустить Studio. 96 DPI соответствует 100%, 192 DPI — 200%.

Сборка: `bash scripts/dev.sh build` создаёт `build/roblox-life.rbxlx`. Открыть
её через **File → Open from File** в Studio. Если Flatpak не видит каталог,
дать чтение только проекту (из корня проекта) и перезапустить Studio:

```bash
flatpak override --user --filesystem="$PWD:ro" org.vinegarhq.Vinegar
```

Такой доступ позволяет читать сборку; для Save As выбрать место через системный
диалог/портал. Если нужен прямой Save в проект, дать `--filesystem="$PWD"` вместо
`:ro`. Исходники и `.rbxlx` меняются с хоста; для сетевого Rojo файловый доступ
к src внутри Flatpak не требуется. Не открывать всему sandbox домашний каталог.

## Подключение Rojo к Studio

У Rojo две части: Linux CLI и Studio-плагин **той же версии 7.7.1**.
[`Rojo.rbxm` из официального релиза](https://github.com/rojo-rbx/rojo/releases/tag/v7.7.1)
подготовлен в `.tools/downloads/Rojo.rbxm`, если загрузка завершилась успешно.
SHA-256: `50a8d83db87deab4d65fd6100eb74396de232355b1ae89c641035d02c49db6f4`.

На текущем компьютере плагин уже установлен в определённый через Wine каталог
`~/.var/app/org.vinegarhq.Vinegar/data/vinegar/appdata/Roblox/Plugins/`.
Шаги копирования ниже нужны при настройке другой машины.

1. В Studio выбрать **Plugins → Plugins Folder**. Это определит фактическую
   папку Plugins **Wine-префикса Vinegar**; не угадывать имя Windows-пользователя.
2. Скопировать туда `Rojo.rbxm` через файловый менеджер или `cp -n` с корректно
   заключённым в кавычки путём. Не заменять существующий плагин другой версии
   без проверки. Перезапустить Studio. Обычный `rojo plugin install` на Linux
   может не найти Wine/Flatpak-папку, поэтому здесь применяется явное копирование.
3. Открыть сборку либо пустой новый place. Запустить на Ubuntu:

   ```bash
   bash scripts/dev.sh serve
   ```

4. В Rojo-плагине подключиться к `127.0.0.1`, порт `34872`; принять только
   ожидаемые изменения этого нового place. Основной поток: файлы → Studio.
5. При запросе Studio разрешить HTTP/localhost-соединение плагину. В **Game
   Settings → Security** может потребоваться **Allow HTTP Requests**. Доступ
   к DataStore/API Services для прототипа не нужен.
6. Вне Play сохранить изменение `.luau` и проверить обновлённый Source в Studio.
   Для нового поведения остановить и снова начать Play.

Rojo слушает только loopback. Проверить `curl http://127.0.0.1:34872/api/rojo`.
Если хост отвечает, а Studio не подключается, проверить наличие `shared=network`
в `flatpak info --show-permissions org.vinegarhq.Vinegar`. При отсутствии добавить
`flatpak override --user --share=network org.vinegarhq.Vinegar` и перезапустить.
При ошибке порта проверить `ss -ltnp | rg 34872`; не открывать порт в интернет.

## Прототип и проверки

Нажать **Play/F5**, подойти к раковине, нажать **E** (на touch — кнопку prompt).
Сервер начинает действие на 2 секунды, проверяет живого персонажа, дистанцию
≤8 studs и линию видимости в начале и конце. За успешное действие — 10 монет.
После завершённой попытки — пауза 3 секунды. HUD показывает монеты и занятость.

Сервер хранит баланс отдельно от `leaderstats`. После ожидания проверяется
тот же персонаж и та же сессия. Клиент не выбирает награду и не завершает таймер.

```text
src/server/  Main.server.luau, ChoreService.luau — адаптеры и состояние сервера
src/client/  Main.client.luau — HUD
src/shared/  ChoreRules.luau — чистые типизированные правила
tests/       unit-тесты и ручные сценарии Studio
scripts/     установка инструментов и проверки
```

```bash
bash scripts/dev.sh format   # применить StyLua
bash scripts/dev.sh lint     # Selene; предупреждения тоже приводят к отказу
bash scripts/dev.sh test     # тесты в standalone Luau
bash scripts/dev.sh types    # Luau LSP + luau-analyze
bash scripts/dev.sh build    # сборка сцены
bash scripts/dev.sh check    # все обязательные проверки
```

`prepare` загружает закреплённые Roblox-типы и генерирует `roblox.yml` Selene
(последний берётся из актуального Roblox API и может изменяться). После подготовки
эти локальные проверки не требуют Studio. Сценарии реальной игры, двух игроков,
смерти, спама и синхронизации: [tests/README.md](tests/README.md).
Успешная сборка не заменяет их выполнения.

Проверка сборки также запускает Python-тест координат сцены. Для деталей в
Rojo-проекте используется сериализуемый `CFrame`: один `Position` в `.rbxlx`
не сохранял их расположение при загрузке в Studio.

Официальный Studio MCP, возможности Codex и ограничения Linux описаны отдельно:
[docs/ROBLOX_MCP.md](docs/ROBLOX_MCP.md). MCP необязателен; мосты автоматически
не устанавливаются. На этой машине официальный MCP уже зарегистрирован в Codex
через локальный launcher; для загрузки инструментов нужен новый сеанс Codex.
