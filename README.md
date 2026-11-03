# Neighborhood Fixer — разработка игры

Ubuntu + VS Code/Codex + Luau + Rojo. Текущая игра: бесплатная личная комната,
стандартный персонаж, небольшой район, HUD долларов и панель «Дом» с возвратом
домой. Интерфейс EN/RU. Комната создаётся сервером после подтверждения профиля.
Есть заказы на покраску: маршрут к клиенту, осмотр, защита пола, выбор цвета,
валик и серверная приёмка за $250. Экран итогов показывает подтверждённые деньги,
XP и приёмку, затем ведёт в магазин: [JOB_RESULTS.md](docs/JOB_RESULTS.md).
Есть магазин с тремя предметами, склад
и редактор собственной комнаты с Grid/Free, поворотом, переносом и возвратом на склад.

Фактические результаты настройки и оставшиеся ограничения: [docs/ENVIRONMENT.md](docs/ENVIRONMENT.md).

Начата реализация «Мастер на районе / Neighborhood Fixer» по
[ТЗ v0.7](Roblox_Neighborhood_Fixer_GDD_TZ_v0.7.md). Подробный разбор:
[docs/GDD_REVIEW.md](docs/GDD_REVIEW.md); порядок и статус:
[tasks/plan.md](tasks/plan.md), [tasks/todo.md](tasks/todo.md).
Профиль и координатор хранилища подключены к сцене. В Studio по умолчанию
включён **явный локальный preview**: данные живут до остановки сервера, что
написано в панели «Дом». В опубликованной игре используется DataStore без
перехода в память при ошибке. Настоящее облачное сохранение ещё не проверено.
Контракт и режимы: [docs/PROFILE_STORAGE.md](docs/PROFILE_STORAGE.md).
Для отдельной облачной приёмки подготовлена [QA-сборка](docs/CLOUD_QA.md):
она требует явных Universe/Place ID, использует изолированное хранилище и
не переключает обычный проект из MemoryPreview.

`bash scripts/dev.sh build` создаёт две независимые сцены:

| Файл | Назначение |
| --- | --- |
| `build/roblox-life.rbxlx` | Текущий Neighborhood Fixer: профиль, комнаты, Jobs/Map, покраска, магазин и мебель |
| `build/sink-prototype.rbxlx` | Контрольный прототип раковины из `prototype.project.json` |

В основной сцене есть только `leaderstats.Dollars`; старые Coins не запускаются.

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

Если поверх Studio появляется чёрный квадрат, это может быть служебное окно
Wine, а не объект сцены. На этой машине подтверждён
[известный сбой Vinegar](https://github.com/vinegarhq/vinegar/issues/973).
Первоначальный обход **Virtual Desktops** убрал квадрат, но в установленной
сборке Wine внутреннее окно осталось около 800×600. Для динамического размера
используется обычное окно Studio; **Virtual Desktops выключен**. Настройка в
`~/.var/app/org.vinegarhq.Vinegar/config/vinegar/config.toml`:

```toml
[studio]
virtual_desktop = ""
```

Локальный контроллер скрывает только известное пустое окно `RobloxStudio`
100×100. При запуске и изменении монитора/рабочей области он подгоняет Studio
под доступное место, учитывая рамку и панели. Ручное изменение размера между
такими событиями сохраняется. DPI остаётся 96 (100%).

```bash
# На этой машине служба уже включена. Для повторной настройки:
python3 scripts/desktop_window.py --install-service
systemctl --user status roblox-life-desktop.service
# Разовая подгонка или проверка размера:
python3 scripts/desktop_window.py --once
python3 scripts/desktop_window.py --once --size 1280x800
# Отключить автоподгонку и скрытие служебного окна:
systemctl --user disable --now roblox-life-desktop.service
```

Контроллер рассчитан на GNOME/XWayland, Python 3, libX11 и libXrandr. Он не
меняет разрешение монитора, файлы сцены или масштаб системы. При переносе
репозитория нужно повторно установить службу из нового каталога. После смены
Virtual Desktops полностью перезапустить Vinegar, предварительно сохранив сцену.

Сборка: `bash scripts/dev.sh build` создаёт `build/roblox-life.rbxlx`. Открыть
её через **File → Open from File** в Studio. Если Flatpak не видит каталог,
дать чтение только проекту (из корня проекта) и перезапустить Studio:

```bash
flatpak override --user --filesystem="$PWD:ro" --filesystem="$PWD/build:rw" org.vinegarhq.Vinegar
```

Корень проекта доступен на чтение, `build` — на запись сцен и lock-файлов.
Для Save As в другой каталог используется системный диалог/портал. Для сетевого
Rojo файловый доступ к src внутри Flatpak не требуется.

## Подключение Rojo к Studio

У Rojo две части: Linux CLI и Studio-плагин **той же версии 7.7.1**.
[`Rojo.rbxm` из официального релиза](https://github.com/rojo-rbx/rojo/releases/tag/v7.7.1)
подготовлен в `.tools/downloads/Rojo.rbxm`, если загрузка завершилась успешно.
SHA-256: `50a8d83db87deab4d65fd6100eb74396de232355b1ae89c641035d02c49db6f4`.

На текущем компьютере активный каталог задан настройкой Studio `PluginsDir`:
`~/.var/app/org.vinegarhq.Vinegar/data/vinegar/prefixes/studio/drive_c/users/danil/AppData/Local/Roblox/Plugins/`.
Плагин там установлен и загружается после перезапуска. Путь `%LOCALAPPDATA%`
в Wine оказался другим: одного копирования туда недостаточно. На другой машине
определить каталог через Studio, как описано ниже.

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

Rojo слушает только loopback. Проверить `curl --silent --output /dev/null --write-out "%{http_code}\n" http://127.0.0.1:34872/api/rojo`
(ожидается 200; тело ответа бинарное).
Если хост отвечает, а Studio не подключается, проверить наличие `shared=network`
в `flatpak info --show-permissions org.vinegarhq.Vinegar`. При отсутствии добавить
`flatpak override --user --share=network org.vinegarhq.Vinegar` и перезапустить.
При ошибке порта проверить `ss -ltnp | rg 34872`; не открывать порт в интернет.

## Игра и проверки

Открыть `build/roblox-life.rbxlx`, нажать **Play/F5**. После подтверждения профиля
персонаж появляется в своей комнате; HUD показывает `$0`. Можно выйти на улицу,
открыть **HOME / ДОМ**, вернуться домой и переключить EN/RU. Сброс персонажа
возвращает его в ту же комнату. Статус локального preview виден в панели Home.

Для первого заказа: **ДОМ → Заказы → Взять заказ** либо жёлтая кнопка задания.
**ДОМ → Карта → К цели** возвращает к маршруту на HUD. На карте видны дом,
игрок и клиент; без заказа цель скрыта. Подробнее: [NAVIGATION.md](docs/NAVIGATION.md).
Иди по крупной стрелке в клиентскую комнату к метке **СТЕНА ДЛЯ ПОКРАСКИ**.
Когда появится **Ты на месте**, жми жёлтую кнопку внизу:
**Осмотреть стену → Постелить плёнку → Выбрать краску → Тёплый белый**.
Зажми левую кнопку мыши и веди валик по стене. Покрой не меньше 80%, нажми
**Проверить результат**, затем **Сдать работу**. Награда — $250 один раз за заказ.
Можно выйти из рабочего режима и продолжить; после смерти нужно начать подготовку
заново. Полный цикл покраска → покупка → установка проверен с событиями Touch
в эмуляторе iPhone 7; проверены поворот и ещё две пропорции экрана. Реальный
телефон и несколько клиентов пока не проверены. Правила адаптивности:
[ui-system.md](docs/ui-system.md).
Подробности: [docs/PAINTING.md](docs/PAINTING.md).

После первой работы жёлтая кнопка предложит **Магазин мебели**. Нажми
**Где магазин**, дойди до прилавка и купи растение за $180. Затем
**ДОМ → Обустроить → Вернуться домой → Установить**. Наведи предмет и кликни
на пол для фиксации позиции, выбери **Сетка / Свободно**, поверни кнопкой или **R** и подтверди зелёную
позицию. Предмет можно перенести или убрать на склад. **Escape / Отмена**
возвращает обычную камеру без изменений. Подробнее: [docs/FURNITURE.md](docs/FURNITURE.md).

Контрольная раковина открывается отдельно из `build/sink-prototype.rbxlx`:
E запускает мойку на 2 секунды, сервер проверяет условия и начисляет 10 Coins,
затем действует пауза 3 секунды. Она не добавляет деньги основному профилю игры.

```text
src/server/Domain/   Profile, ProfileStore, Economy, Jobs, Painting, Furniture, RoomRules — правила
src/server/         ProfileService, JobService, HomeService, Storage, World — адаптеры
src/client/         HUD, Jobs/Map, покраска, каталог/склад и BuildController
src/shared/         Strings, PaintConfig, JobTypes, RouteMath; правила контрольного прототипа
src/legacy/         отдельная раковина, не запускается главным проектом
tests/              unit, lifecycle-регрессии, проверки XML и сценарии Studio
src/assets/         общая фабрика Roblox-моделей мебели
scripts/            установка инструментов и проверки
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

Все исходники, ТЗ, тесты, инструменты проекта и сборки находятся в текущем
корне. Карта файлов и локальные архивы сцен: [PROJECT_FILES.md](docs/PROJECT_FILES.md).
