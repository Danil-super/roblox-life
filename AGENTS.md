# Roblox Life — правила разработки

## Границы прототипа

- Luau + Rojo. Исходники на диске — источник истины. MCP Studio необязателен.
- По прямому указанию пользователя работать только в одном окне Studio с одной
  сценой проекта. Не запускать дополнительные экземпляры, Server & Clients,
  ExecuteMultiplayerTestAsync или AddPlayers. Для проверки — только одиночный
  Play в уже открытой Studio; изоляцию нескольких профилей проверять локальными
  тестами без дополнительных процессов Studio. Многоклиентская приёмка остаётся
  отложенной до отдельного изменения этого указания пользователем.
  Для открытия использовать `bash scripts/dev.sh studio`: команда проверяет
  существующий процесс и незавершённый запуск, повтор не открывает новую сцену.
- Сейчас: подтверждённый профиль, личная/клиентская комнаты, Jobs/Map,
  покраска валиком и однократная выплата, магазин/склад и редактор Grid/Free,
  HUD долларов и Home. Шесть контрактов покраски с XP-порогами,
  общей палитрой и серверным открытием широкого валика; docs/CONTRACTS.md.
  Четвёртый paint-duo-v1: 210 XP, mint → rose, две сетки/одна выплата;
  SurfaceReady не даёт оплату, nextSurface меняет workId/wallId и сбрасывает сетку.
  Jobs.submit проверяет все стены и число из шаблона. Маски runtime, смерть/новая
  сессия начинают с Inspect; завершённая квитанция восстанавливает оба цвета.
  Схема профиля прежняя; docs/PAINT_SCOPE.md.
  После Duo доступны sunroom (330 XP, белый→mint, $600/+140 XP) и atelier
  (470 XP, rose→белый, $650/+160 XP). ClientDecorModels: planter/easel/books,
  16/27 дополнительных Parts на комнату, без collision/query/touch/shadow;
  apply того же стиля сохраняет модели. docs/EXTENDED_CONTRACTS.md.
  Три жителя/пять вариантов рабочей комнаты и диалог по фазе: docs/CLIENTS.md.
  Talk требует текущие job/work, профиль/персонажа, владельца, LOS/дистанцию;
  встреча/сдача ведут к прежним inspect/submit, разговор не платит.
  ClientPanel закрывает прочие режимы и входит в ModalControls.
  PaintAim ограничивает помощь краям 0,35 studs; локальный след не наполняет
  подтверждённую полоску. Painting.reviewError отделяет площадь от времени;
  ни наведение, ни достижение порога сами не принимают/не оплачивают работу.
  PaintSurface — косметическое поле 36×24 из серверной маски, без нового count.
  PaintSurfaceController: 864 пикселя/16 временных следов, один tween на пиксель,
  dedup маски и cleanup. Предсказание не подтверждает покрытие; контуры 12×8
  появляются при Review/Coverage. FixedSize/clip, повторный вход из mask;
  Destroy HUD освобождает renderer/render binding/ввод. docs/PAINTING.md.
  Home переключает LightPaintEffects на текущий сеанс: 96 пикселей/четыре
  следа, без tween; полный режим прежний. GuiService.ReducedMotionEnabled
  только читается и отключает tween также в полном режиме. Замена renderer
  восстанавливает mask без сброса ввода/очереди/заказа, подписки снимаются
  при Destroy HUD. docs/PAINT_EFFECTS.md.
  PaintRoller: локальная модель из 11 Parts/13 объектов с Sound, под камерой,
  без collision/query/touch/shadow. PaintRollerMotion крутит шубку от движения,
  без таймера; hover не пишет очередь/маску/sequence, Touch только при held.
  LightPaintEffects/ReducedMotion отключают spin/tilt, сохраняя наведение.
  Единственный PaintingView и прежний sampling 0,03 с; renderer без своих
  подписок/tween/remotes. hide сбрасывает жест, stop/Destroy удаляют модель/
  звук и запрещают late update. Это локальный инструмент, не новая скелетная
  анимация. Сервер/схема/оплата прежние; docs/PAINT_TOOL.md.
  NeighborhoodScenery создаёт улицу при Play и входные накладки при cloneRoom;
  StreetLayout проверяет проходы для 16 слотов. StreetDetails — до 300 деталей,
  start идемпотентен, SurfaceGui переводит WorldSignsController по событиям.
  Публичные скамейки используют native Seat; доступ в чужие комнаты не меняется.
  Оформление воспроизводится из кода, Edit-предпросмотры после QA удаляются;
  docs/STREET.md.
  WalkingRoute ведёт через Walk-точки PathfindingService: один async-расчёт,
  поколение цели/cleanup, минимум 0,75 с, отказ с паузой 2 с, обновление 3 с.
  Radius 1 проверен в дверях P0; без автопилота/прыжков. Чужие интерьеры имеют
  бесконечную стоимость NavigationVolume, серверный guard остаётся независимым.
  Path.Blocked не покрывает все обновления; старый callback проверяет identity
  Path, чтобы не снять замену. Map — пул 128 линий, мировая метка одна;
  отсутствие пути скрывает направление. docs/NAVIGATION.md.
  NavigationGoal выбирает Job либо Shop для одного JobNavigation/WalkingRoute/
  Map. HomeController.travel/stopRoute связаны явными callbacks через Main;
  выбор магазина не отменяет job/work и не покупает предмет. NearShop приходит
  из HomeState, право покупки заново проверяет HomeService. Покупка/обустройство
  снимают Shop, Jobs/справка/разговор с жителем возвращают текущую работу; выбор только на сеанс.
  Отдельные ShopRoute/ShopMarker удалены. docs/SHOP_NAVIGATION.md.
  PaintingMastery проецирует подтверждённые XP/offers: ближайший порог,
  постоянная шкала Jobs, открытия по XP квитанции. Несогласованные данные
  не дают рекомендацию. Result Continue сохраняет BUY/PLACE, после DONE
  открывает подробности доступного заказа без accept/выплаты; visible/
  Completed/available/Ready обязательны. docs/PAINTING_MASTERY.md.
  JobAbandonFlow/Controller: cancel сначала спрашивает; Keep сохраняет маску.
  После отправки job/work удерживаются при unknown/busy и закрытии окна;
  Retry через 8 с повторяет только этот контекст. Новые команды заказа
  заблокированы, sync остаётся. Offer подтверждает отказ; новый work/job/
  Completed прекращает старый intent. AbandonPanel входит в ModalControls.
  Серверный cancel/схема прежние. docs/JOB_ABANDON.md.
  JobAcceptFlow/JobOffers удерживают requestId/offerId/предыдущий jobId после
  отправки, закрытия и unknown. Через 8 с только явный Retry с теми же ID.
  Определённый отказ требует коррелированного acceptAck; старый ack не снимает
  новую попытку. Сервер сверяет baseline до/внутри mutation; новый jobId выдаёт
  сервер. Другие команды заказа блокируются, sync работает также при закрытом
  телефоне. Схема профиля прежняя; docs/JOB_ACCEPTANCE.md.
  JobWorkPlan проецирует пять этапов подтверждённого активного заказа.
  Процент только при Painting; 96 клеток не завершают проверку/сдачу.
  SurfaceReady отмечает текущую стену, но не финальную сдачу; следующая
  стена снова требует материала/покраски. Renderer — 28 объектов без новых
  remotes/кадровых циклов; Canvas 666, revealActions фокусирует прежнее
  действие при открытии/resize/phase/workId, обычный sync не сбрасывает
  прокрутку. Профиль/награды прежние; docs/JOB_WORK_PLAN.md.
  BuildGuidesController отображает Grid/границы/пять занятых зон и вращаемые
  габариты мебели. Каноническая геометрия остаётся Furniture.layout на сервере,
  копия — optional HomeState.layout/FurnitureLayout; серверный validate прежний.
  67 локальных Parts + две BillboardGui/подписи = 72 объекта с папкой,
  без collide/query/touch/shadow и новых render bindings. В Free сетка скрыта;
  цвет рамки только из HomePreview, pending — ожидание. Stop/Died убирают
  папку/ghost, Destroy HUD снимает FurnitureView и запрещает старый enter.
  Профиль/деньги/права прежние; docs/HOME_GUIDES.md.
  BuildController: RotateLeft/Rotate и Q/R вызывают общий поворот ±90° Grid /
  ±15° Free. G/Mode и Enter/Confirm используют те же команды; заголовок —
  предмет/угол. Пять кнопок с короткими Touch-подписями, цели ≥44 px при 320.
  Processed/focus блокируют новые клавиши, pending сохраняет прежний intent
  и Retry. Сервер/схема/правила размещения прежние; docs/HOME_CONTROLS.md.
  Inventory: All/Stored/Placed — проекция подтверждённых экземпляров HomeState,
  дубликаты товара учитываются отдельно. Pending store/focus предмета раскрывают
  All; purchase/store/Build/не-Ready блокируют смену вкладки. Обычный sync
  сохраняет карточки/scroll, явная смена сбрасывает scroll. Протокол и профиль
  прежние; docs/FURNITURE_INVENTORY.md.
  HomeObjective: дома после DONE и без активной работы/маршрута/pending/error
  HUD показывает Base5 → Creative3 → Ready из согласованных items/plan.
  Только HUD NextAction открывает Room; Jobs/Map/Guide используют прежний
  activate. Main связывает callback, HomeObjectiveState/OnboardingStep/Building
  обновляют проекцию. Новые подписки и Home sync отключаются при Destroy HUD.
  Существующий секундный Home sync работает после DONE с закрытым меню для
  подтверждённого nearHome, без записи профиля/новых remotes/циклов. Компактный
  HUD 100 px сохраняет цель/кнопку ≥44; ошибки и обучение прежние.
  Схема/экономика прежние; docs/HOME_HUD.md.
  Paint finish: schemaVersion=3, decode мигрирует 1/2 без выдуманных масок.
  Jobs.submit сохраняет Painting.finish вместе с оплатой; Completed replay
  не меняет маску. JobResult выдаёт копию только с подтверждённой квитанцией.
  PaintFinish оценивает худшую стену: accepted / excellent (Config 95%) /
  perfect (100%); оплата/XP прежние. Live-цель не принимает и не платит.
  PaintResultScene: статичные ViewportFrame/WorldModel, маска ≤12×8 без
  скрытия дыр, 8/14 Parts при полном single/duo, максимум 110 Parts/118
  объектов renderer. Hide удаляет модели, Destroy запрещает старый render;
  две камеры переиспользуются, глобальная камера не меняется. docs/PAINT_FINISH.md,
  docs/PAINT_RESULTS.md. Старый schema-2 writer не читает schema 3; cloud gate открыт.
  Прежняя раковина сохранена отдельно: `prototype.project.json`, `src/legacy`.
- Пользователь поручил начать P0 по `Roblox_Neighborhood_Fixer_GDD_TZ_v0.7.md`.
  Последовательность и факты: `tasks/plan.md`, `tasks/todo.md`, `docs/GDD_REVIEW.md`.
- Profile/ProfileStore подключены к runtime. Jobs/Painting вызывают Economy
  при серверной приёмке; HomeService использует Economy для покупок и Furniture
  для размещения. Каталог содержит восемь тестовых предметов. Контракты/награды в EconomyConfig,
  радиусы/материалы в PaintConfig. Клиент не назначает XP, доступ и радиус.
  План комнаты вычисляется из подтверждённых экземпляров/установки: покупка
  и дубликаты не подменяют отсутствующую мебель, убирание на склад снимает текущий пункт без штрафа.
  Seat выключен у фабричных моделей/витрины/ghost; сервер включает его у
  установленного кресла. После seated ReturnHome сервер кратко удерживает
  владение физикой и восстанавливает auto; docs/HOME_PLAN.md.
  HomeBudget считает недостающие покупки/дефицит каждой цели из plan/catalog/
  dollars; склад не требует повторной покупки. Earn открывает Jobs только
  когда нечего ставить/покупать; проверяет актуальный бюджет и visible.
  Pending purchase/store/build и не-Ready блокируют переходы плана, ID
  операций сохраняются. Проекция не резервирует деньги. docs/HOME_BUDGET.md.
  HomePlan.isComplete сверяет все установленные требования/уникальные предметы
  и счётчики. Готовый план показывает 5/5 и Jobs; переход не принимает заказ.
  Store снимает текущую готовность. HomePlan.displayGoals добавляет creativeCorner
  только после базового 5/5: cozy-sofa-v1 ($480), floor-easel-v1 ($360),
  floor-planter-v1 ($240). Optional3 не меняет базовую готовность/обучение;
  счёт из подтверждённых items/placements, storage снимает только optional.
  HomePlanner использует те же goals для cache/render/Earn, pending guards прежние.
  Фабрика повторно использует ClientDecorModels для двух товаров; sofa — 14 Parts,
  один Seat, Disabled=true в фабрике, сервер включает только установленный.
  Восемь витринных моделей, сиденья выключены. docs/CREATIVE_HOME.md.
  Language.ZIndex=20: кнопка выше phone/RoomPlan (Sibling, panel=10), в том
  числе 666×316. Covered/Clipped не обходить — исправить слой/прокрутить.
  RoomProgression проверяет $0 → четыре
  контракта/пять стен → пять предметов/$330/330 XP с memory reload, без выдачи
  баланса. Это не cloud gate. docs/NATURAL_PROGRESSION.md.
  HomeLights включает E/Touch только у подтверждённо установленного торшера;
  сервер проверяет владельца/модель/профиль/персонажа/комнату/distance/LOS.
  Выключатель — косметика runtime-модели: сохраняется при move/reconcile/respawn,
  сбрасывается после store/recreate/нового сервера. Профиль/деньги/XP не меняет.
  ModalOpen скрывает native prompt при меню/рабочих режимах; docs/HOME_INTERACTIONS.md.
  Studio использует явно обозначенный MemoryPreview;
  в production только DataStore. Облачную приёмку не объявлять завершённой.
- PurchaseFlow удерживает requestId/catalogId до доказанной покупки или
  коррелированного определённого отказа. Busy и неопределённый исход не разрешают
  новый платёж; Retry повторяет тот же ID. HomeState.ack относится и к отказам,
  успех подтверждается принадлежащим предметом с purchaseOperationId.
- PlacementFlow удерживает requestId/itemId/editorId/revision/pose до подтверждения
  своей позиции или определённого отказа с HomeState.placementAck. Sync/busy/
  Unavailable не снимают ожидание; через 8 с Retry повторяет тот же intent.
  После отправки обычная отмена/вращение/смена режима/ввод на пол заблокированы.
  Сервер требует requestId и подтверждает уже установленную допустимую позицию
  без новой записи профиля/reconcile; старый запрос не откатывает более новую
  housing revision. ID коррелирует ответ, модель уникальна по itemInstanceId;
  схема профиля и облачный gate прежние. docs/FURNITURE.md.
- StoreFlow удерживает requestId/itemId/editorId/revision до подтверждённого
  принадлежащего предмета на складе или определённого отказа с storeAck.
  Sync/Unavailable не снимают ожидание; Retry через 8 с повторяет тот же intent.
  Пока ждём, другие покупки/изменения мебели отключены, закрытие меню сохраняет ID.
  Новый editorId завершает старое ожидание; серверный guard проверяет персонажа.
  Повтор уже хранящегося предмета не пишет профиль/reconcile; старый store не
  снимает более новую установку. Владение/доллары и схема профиля прежние.
- Подсказки HUD можно скрыть через Home на текущий сеанс; это не завершает
  обучение. Цель/действие и ошибки сохраняют приоритет; настройка не пишется в профиль.
- FirstSteps вычисляет семь групп из подтверждённых фактов; исторический DONE
  не сбрасывается хранением/новым заказом. GuidePanel — повторная справка,
  не источник прогресса. Авто-показ только при живом Active → Done, после рабочих
  режимов, без повторения на входе и при ShowHints=false. Телефон M и кнопка
  используют общие guards профиля/ввода/Paint/Build; docs/ONBOARDING.md.
- Profile_Load_Error имеет серверный Retry/Exit. Uncertain повторяет тот же
  intent; Locked не снимает чужой lease; Lost/Corrupt/конфигурация не пересоздают
  профиль. Busy и cooldown 10 с проверяются на сервере, не по клиентскому атрибуту.
- Если официальный start_stop_play завис, использовать `python3 scripts/studio_test.py
  start|stop|status`: официальный MCP + одиночный StudioTestService с непустым args.
  Не добавлять клиентов для обхода зависания. Mode Play не доказывает приёмку игры.
- execute_luau может восстановить исходный CameraType после завершения команды
  (Output: ExecuteLuauActions / Resetting ... back to ...), даже если Custom
  установился игровой очисткой HUD. Отделять это от возврата игрового renderer;
  поздние события проверять с наблюдением внутри команды и через GUI-ввод.
- P0: покраска → доллары → покупка → установка → сохранение. Четыре профессии,
  аренда, подарки, транспорт и монетизация остаются вне текущего этапа.

## Код и архитектура

- Каждый `.luau` начинается с `--!strict`. `.luaurc` задаёт strict по умолчанию.
- Типизировать параметры, возвращаемые значения и состояние. Не маскировать ошибки
  через `any`, `--!nocheck`, отключение линтов или снятие проверок.
- `src/server` — авторитетное состояние и игровые операции, `src/client` — ввод и UI,
  `src/shared` — общие типы, константы и чистые функции без секретов.
- `src/assets` — общая фабрика моделей Roblox, используемая сервером и UI;
  `src/shared` остаётся без Roblox globals для standalone strict-анализа.
- Разделять чистые игровые правила и адаптеры Roblox. Не создавать универсальные
  фреймворки до появления нескольких реальных потребителей.
- Новые зависимости добавлять только с обоснованием; фиксировать версии в
  `rokit.toml`, согласовывать с `scripts/toolchain.json` и контрольными суммами.

## Серверная граница

- Монеты, цены, награды, владение и доступ проверяет и меняет только сервер.
- Клиентское число, атрибут, `leaderstats` или сигнал prompt не является доказательством.
  `leaderstats.Dollars` — отображение подтверждённого профиля, не источник истины.
  Coins относится только к изолированному старому прототипу.
- Проверять игрока, живого персонажа, дистанцию, состояние объекта и частоту запросов.
  Проверять конечность недоверенных чисел и ограничивать допустимые значения.
- Длительность действия измерять на сервере. После ожидания повторно проверить
  персонажа и условия; не выдавать награду вышедшему игроку или новому персонажу.
- Не добавлять yielding между решением выдать награду и обновлением баланса.
- Не хранить приватные данные и серверные секреты в `ReplicatedStorage`.

## Проверки и работа с Git

- Менять небольшими проверяемыми шагами. Для поведения игровых правил добавлять
  тесты на успех, отказ, границы, повторный вызов и независимость игроков.
- После изменений запускать `bash scripts/dev.sh check`: формат, Selene,
  standalone Luau-тесты, strict-анализ и сборка Rojo.
- Для Roblox API отдельно выполнять сценарии из `tests/README.md` в Studio.
  Сборка, типизация и unit-тесты не доказывают работоспособность в Studio.
- Для GUI-кликов официального MCP использовать `scripts/studio_ui.py` /
  `studio_ui.click`: проверять видимость родителей, clip/перекрытие и результат
  перехода. Путь к скрытой кнопке может нажать другую видимую кнопку под её
  координатами. Не обходить отказ preflight слепым вводом. Координаты стены/
  пола допускаются при подтверждённом Paint/Build. Повторяемый учебный цикл:
  `scripts/studio_local_qa.py`, только свежий MemoryPreview; docs/LOCAL_QA.md.
  MCP может запретить прямой FireServer/require из-за capability Network.
  Такой отказ не доказывает отказ игры. Replay/unknown отдельно проверять
  адаптерами; статические GUI-проекции не объявлять проверкой callbacks/сети.
- Не заявлять Play/Studio/MCP успешными без реального запуска и наблюдений.
- Не коммитить `.tools`, build, `.env`, токены, дампы, runtime-данные и логи.
  Не публиковать игру и не отправлять изменения в remote без поручения.

## Контекст проекта и документация

- Перед анализом исходников использовать Graphify MCP с абсолютным `project_path`
  именно текущего проекта/worktree. Начать с `query_graph`, затем по необходимости
  `get_node`, `get_neighbors`, `shortest_path`.
- Граф: `graphify-out/graph.json`. При отсутствии/изменении исходников запускать
  из корня `env GRAPHIFY_BACKEND=none graphify extract . --code-only --exclude backups --exclude data --exclude uploads --exclude logs --exclude .tools --exclude build --exclude .codegraph`.
  После изменений: `env GRAPHIFY_BACKEND=none graphify extract . --code-only`.
  Сохранять исключения. Не индексировать документы, секреты и runtime-хранилища.
- Если MCP недоступен: `graphify query "вопрос" --budget 1500` из корня и сообщить
  об ограничении. Частичный AST Luau и `INFERRED` связи проверять по исходникам.
  Ошибка индексации не считается успешным обновлением.
- Дополнительно обновлять Code Graph: `codegraph sync "$PWD"` (первый запуск:
  `codegraph init --yes "$PWD"`), запросы CLI выполнять с `--path "$PWD"`.
  MCP Code Graph использовать только после проверки, что его root совпадает с проектом.
  Не использовать индекс соседнего проекта.
- Для внешних библиотек, SDK, CLI и API сначала получать актуальные документы
  Context7: `resolve-library-id`, затем `query-docs`. Если данных нет — официальный
  источник, с явным указанием ограничения. Не проектировать API по памяти.
- Поддерживать README и `docs/ENVIRONMENT.md` в соответствии с фактическими проверками.
