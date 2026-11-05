--!strict
local en: { [string]: string } = {
	title = "NEIGHBORHOOD FIXER",
	home = "HOME",
	room = "Your first home",
	close = "Close",
	roomInfo = "A free room of your own. Step outside and explore the neighborhood.",
	returnHome = "Return home",
	loading = "Connecting your profile…",
	ready = "Profile connected",
	error = "Your profile could not be confirmed. Progress is protected. Please rejoin in a moment.",
	preview = "Local preview · progress lasts until the server stops",
	persistent = "Cloud profile storage",
	objective = "Make yourself at home",
	hint = "Explore your room and the street. Open HOME to return here.",
	private = "Private · only you can enter",
	balance = "Dollars",
	xp = "Painting experience",
}
local ru: { [string]: string } = {
	title = "МАСТЕР НА РАЙОНЕ",
	home = "ДОМ",
	room = "Твой первый дом",
	close = "Закрыть",
	roomInfo = "Бесплатная личная комната. Выйди на улицу и осмотрись в районе.",
	returnHome = "Вернуться домой",
	loading = "Подключаем твой профиль…",
	ready = "Профиль подключён",
	error = "Не удалось подтвердить профиль. Прогресс защищён. Перезайди немного позже.",
	preview = "Локальный тест · прогресс до закрытия сервера",
	persistent = "Облачное хранение профиля",
	objective = "Осмотрись в новом доме",
	hint = "Исследуй комнату и улицу. Кнопка ДОМ поможет вернуться.",
	private = "Личная комната · вход только для тебя",
	balance = "Доллары",
	xp = "Опыт покраски",
}
en["paintEffectsFull"], ru["paintEffectsFull"] =
	"Painting: smooth effects", "Покраска: плавные эффекты"
en["paintEffectsLight"], ru["paintEffectsLight"] =
	"Painting: light effects", "Покраска: лёгкие эффекты"
en["paintEffectsHint"] = "Fewer effects this session.\nCoverage and rewards stay the same."
ru["paintEffectsHint"] =
	"Меньше эффектов на этот сеанс.\nПокрытие и награда прежние."
en["jobs"] = "Jobs"
en["workPlanTitle"], ru["workPlanTitle"] = "Work plan", "План работ"
en["workPlanStep"], ru["workPlanStep"] = "Step %d/%d", "Шаг %d/%d"
en["workPlanDone"], ru["workPlanDone"] = "Done", "Готово"
en["workPlanCurrent"], ru["workPlanCurrent"] = "Now", "Сейчас"
en["workPlanNext"], ru["workPlanNext"] = "Next", "Далее"
en["workPlanPaint"], ru["workPlanPaint"] =
	"Paint and check the wall", "Покрась и проверь стену"
en["workPlanWallChecked"], ru["workPlanWallChecked"] =
	"Wall checked", "Стена проверена"
en["workPlanPaintHint"] =
	"Paint the wall, then use Inspect result. Coverage alone does not accept the work."
ru["workPlanPaintHint"] =
	"Покрась стену, затем нажми «Проверить результат». Одного покрытия недостаточно для приёмки."
en["workPlanReviewHint"] =
	"Coverage reached. Inspect result; painting time is also checked. Then hand over to the client."
ru["workPlanReviewHint"] =
	"Покрытие набрано. Нажми «Проверить результат»: учитывается и время покраски. Затем сдай работу клиенту."
en["workPlanNextHint"] =
	"This wall passed inspection. Continue to the next wall. Payment follows handover of the whole order."
ru["workPlanNextHint"] =
	"Эта стена проверена. Перейди к следующей. Оплата — после сдачи всего заказа."
en["acceptRetry"], ru["acceptRetry"] = "Retry acceptance", "Повторить принятие"
en["acceptPendingStatus"], ru["acceptPendingStatus"] =
	"Checking this order request…", "Проверяем принятие заказа…"
en["acceptPendingHint"] =
	"Waiting for confirmation. Retry checks the same offer. Closing the phone keeps this request."
ru["acceptPendingHint"] =
	"Ждём подтверждения. Повтор относится к тому же предложению. Закрытие телефона сохраняет запрос."
ru["jobs"] = "Заказы"
en["map"] = "Map"
ru["map"] = "Карта"
en["backHome"] = "← Home"
ru["backHome"] = "← Дом"
en["jobOffer"] = "Paint a client’s room"
ru["jobOffer"] = "Покрась комнату клиента"
en["jobInspect"] = "Inspect the wall"
ru["jobInspect"] = "Осмотри стену"
en["jobPrepare"] = "Protect the floor"
ru["jobPrepare"] = "Защити пол плёнкой"
en["jobColor"] = "Choose a roller and the requested paint"
ru["jobColor"] = "Выбери валик и нужную краску"
en["jobPaint"] = "Paint the wall with your roller"
ru["jobPaint"] = "Покрась стену валиком"
en["jobReady"] = "The wall is ready for handover"
ru["jobReady"] = "Стена готова к приёмке"
en["jobDone"] = "Order completed!"
ru["jobDone"] = "Заказ выполнен!"
en["acceptJob"] = "Accept order"
ru["acceptJob"] = "Взять заказ"
en["anotherJob"] = "Take another order"
ru["anotherJob"] = "Взять следующий заказ"
en["inspectWall"] = "Inspect wall"
ru["inspectWall"] = "Осмотреть стену"
en["protectFloor"] = "Lay protective film"
ru["protectFloor"] = "Постелить плёнку"
en["useRoller"] = "Use roller"
ru["useRoller"] = "Взять валик"
en["submitJob"] = "Hand over the work"
ru["submitJob"] = "Сдать работу"
en["cancelJob"] = "Abandon order · no penalty"
ru["cancelJob"] = "Отказаться · без штрафа"
en["offerHint"] = "Open HOME → Jobs to start your first paid job."
ru["offerHint"] =
	"Открой ДОМ → Заказы, чтобы начать первую работу."
en["jobRouteHint"] = "Follow the arrow to your client. Use Jobs for the next step."
ru["jobRouteHint"] =
	"Иди по стрелке к клиенту. Следующий шаг — в Заказах."
en["doneHint"] = "Reward credited. You can take another order."
ru["doneHint"] =
	"Награда зачислена. Можно взять следующий заказ."
en["paintDrag"] = "Drag the roller over the wall"
en["streetHomes"], ru["streetHomes"] = "Homes", "Квартиры"
en["streetClients"], ru["streetClients"] = "Clients", "Заказчики"
en["streetShop"], ru["streetShop"] = "Furniture", "Мебель"
en["streetMyHome"], ru["streetMyHome"] = "My home", "Мой дом"
en["streetPrivateHome"], ru["streetPrivateHome"] = "Private home", "Частная комната"
en["streetMyClient"], ru["streetMyClient"] = "My client", "Мой заказчик"
en["streetClientDoor"], ru["streetClientDoor"] = "Client", "Заказчик"
en["lightOn"], ru["lightOn"] = "Turn on", "Зажечь"
en["lightOff"], ru["lightOff"] = "Turn off", "Погасить"
ru["paintDrag"] = "Веди валик по стене"
en["paintProgress"] = "%s · %d%% / %d%% goal"
ru["paintProgress"] = "%s · %d%% / цель %d%%"
en["paintCovered"] = "Coverage ready — inspect your work"
ru["paintCovered"] = "Площадь готова — проверь результат"
en["paintWait"] = "Coverage ready — wait a moment, then inspect again"
ru["paintWait"] = "Площадь готова — подожди и проверь снова"
en["jobErrorDrying"] = "The area is covered. Wait a moment, then inspect again."
ru["jobErrorDrying"] =
	"Площадь покрыта. Подожди немного и проверь ещё раз."
en["paintMissing"] = "Fill the highlighted gaps, then inspect again"
ru["paintMissing"] =
	"Закрась выделенные пропуски и проверь снова"
en["inspectResult"] = "Inspect result"
ru["inspectResult"] = "Проверить результат"
en["leaveWork"] = "Leave work view"
ru["leaveWork"] = "Выйти из рабочего режима"
en["rose"] = "Rose"
ru["rose"] = "Розовый"
en["warmWhite"] = "Warm white"
ru["warmWhite"] = "Тёплый белый"
en["mint"] = "Mint"
ru["mint"] = "Мятный"
en["clientApartment"] = "Client"
ru["clientApartment"] = "Клиент"
en["noActiveRoute"] = "No active route"
ru["noActiveRoute"] = "Нет активного маршрута"
en["mapHint"] = "Your plot · yellow dot is you. The arrow points to the client."
ru["mapHint"] =
	"Твой участок · жёлтая точка — ты. Стрелка ведёт к клиенту."
en["jobErrorTooFar"] = "Go inside your client’s room, closer to the wall."
ru["jobErrorTooFar"] =
	"Зайди в комнату клиента и подойди к стене."
en["jobErrorColor"] = "The client requested warm white. You can choose again."
ru["jobErrorColor"] =
	"Клиент просит тёплый белый. Выбери цвет ещё раз."
en["jobErrorCoverage"] = "Fill the highlighted gaps until the coverage target, then inspect again."
ru["jobErrorCoverage"] =
	"Закрась подсвеченные пропуски до цели покрытия и проверь снова."
en["jobErrorRetry"] = "Continue a little slower; rejected strokes do not add coverage."
ru["jobErrorRetry"] =
	"Продолжай чуть медленнее: отклонённые мазки не добавляют покрытия."
en["jobErrorStale"] = "Work session changed. Open Jobs again."
ru["jobErrorStale"] =
	"Рабочая сессия изменилась. Открой Заказы снова."
en["jobErrorUnavailable"] = "Waiting for the profile. Your progress is protected."
ru["jobErrorUnavailable"] =
	"Ждём подтверждение профиля. Прогресс защищён."
en["jobErrorRestart"] = "After respawning, inspect and prepare the wall again."
ru["jobErrorRestart"] =
	"После возрождения осмотри и подготовь стену заново."
en["saving"] = "Confirming progress…"
ru["saving"] = "Подтверждаем прогресс…"
en["arrived"] = "You’re here"
ru["arrived"] = "Ты на месте"
en["routeDistance"] = "%d studs away"
ru["routeDistance"] = "До цели: %d"
en["workWall"] = "WALL TO PAINT"
ru["workWall"] = "СТЕНА ДЛЯ ПОКРАСКИ"
en["useActionBelow"] = "Use the yellow button below"
ru["useActionBelow"] = "Жми жёлтую кнопку внизу"
en["goToClient"] = "Reach your client’s room"
ru["goToClient"] = "Дойди до комнаты клиента"
en["inspectHint"] = "You’re here. Press Inspect wall below to start."
ru["inspectHint"] = "Ты на месте. Нажми «Осмотреть стену» внизу."
en["prepareHint"] = "Press Lay protective film to protect the floor."
ru["prepareHint"] =
	"Нажми «Постелить плёнку», чтобы защитить пол."
en["colorHint"] = "Choose the colour requested by this client."
ru["colorHint"] = "Выбери цвет, который просит этот клиент."
en["choosePaint"] = "Choose paint"
ru["choosePaint"] = "Выбрать краску"
en["paintHint"] = "Take the roller, then hold and drag across the wall."
ru["paintHint"] =
	"Возьми валик, затем зажми кнопку мыши и веди по стене."
en["readyHint"] = "Press Hand over the work below to receive your reward."
ru["readyHint"] =
	"Нажми «Сдать работу» внизу и получи награду."
en["openJobs"] = "Open jobs"
ru["openJobs"] = "Открыть заказы"
en["jobRouteHint"] =
	"Follow gold markers through doors. At the target, press the yellow action button."
ru["jobRouteHint"] =
	"Иди по золотым меткам через двери. У цели нажми жёлтую кнопку задания."
en["openMap"] = "Open route map"
ru["openMap"] = "Открыть карту маршрута"
en["shopTitle"] = "Furniture shop"
ru["shopTitle"] = "Магазин мебели"
en["inventoryTitle"] = "Your furniture"
ru["inventoryTitle"] = "Твоя мебель"
en["inventoryAll"], ru["inventoryAll"] = "%s · All", "%s · Всё"
en["inventoryStored"], ru["inventoryStored"] = "%s · Stored", "%s · На складе"
en["inventoryPlaced"], ru["inventoryPlaced"] = "%s · In room", "%s · В комнате"
en["emptyInventoryStored"] = "Nothing in storage. Check In room."
ru["emptyInventoryStored"] =
	"На складе пусто. Проверь раздел «В комнате»."
en["emptyInventoryPlaced"] = "No furniture placed yet. Choose a stored piece."
ru["emptyInventoryPlaced"] =
	"В комнате пока нет мебели. Выбери предмет со склада."
en["furnitureApp"] = "Furnish room"
ru["furnitureApp"] = "Обустроить"
en["showShopRoute"] = "Show route"
ru["showShopRoute"] = "Где магазин"
en["shopReady"] = "Choose an item. Prices come from the server."
ru["shopReady"] = "Выбери предмет для своей комнаты."
en["shopTravel"] = "Walk to the shop next to your home to buy furniture."
ru["shopTravel"] =
	"Для покупки дойди до магазина рядом с домом."
en["shopTitleLong"] = "Furniture for your first home"
ru["shopTitleLong"] = "Мебель для первого дома"
en["openShop"] = "Open shop"
ru["openShop"] = "Открыть"
en["buyItem"] = "Buy"
ru["buyItem"] = "Купить"
en["retryPurchase"] = "Retry purchase"
ru["retryPurchase"] = "Повторить"
en["purchasePending"] = "Confirming purchase. Please wait."
ru["purchasePending"] = "Подтверждаем покупку. Подожди ответа."
en["purchaseUncertain"] = "No reply yet. Retry checks this same purchase."
ru["purchaseUncertain"] =
	"Нет ответа. «Повторить» проверит ту же покупку."
en["purchaseBusy"] = "Confirming…"
ru["purchaseBusy"] = "Проверяем…"
en["openInventory"] = "Open inventory"
ru["openInventory"] = "Открыть склад"
en["inventoryHint"] = "Choose a piece to place or move."
ru["inventoryHint"] =
	"Выбери предмет для установки или переноса."
en["inventoryGoHome"] = "Return to your room to place furniture."
ru["inventoryGoHome"] = "Вернись в свою комнату для обустройства."
en["emptyInventory"] = "No furniture yet. Complete a painting order and visit the shop."
ru["emptyInventory"] =
	"Пока пусто. Выполни покраску и зайди в магазин."
en["itemStored"] = "in storage"
ru["itemStored"] = "на складе"
en["itemPlaced"] = "in your room"
ru["itemPlaced"] = "в комнате"
en["placeItem"] = "Place"
ru["placeItem"] = "Установить"
en["moveItem"] = "Move"
ru["moveItem"] = "Перенести"
en["storeItem"] = "Store"
ru["storeItem"] = "На склад"
en["buildHint"] = "Click the floor to lock position · R rotates"
en["buildAngle"], ru["buildAngle"] = "%s · %d°", "%s · %d°"
en["buildGridCompact"], ru["buildGridCompact"] = "Grid", "Сетка"
en["buildFreeCompact"], ru["buildFreeCompact"] = "Free", "Своб."
en["buildConfirmCompact"], ru["buildConfirmCompact"] = "Done", "Готово"
en["buildWaitCompact"], ru["buildWaitCompact"] = "Wait", "Ждём"
en["buildRetryCompact"], ru["buildRetryCompact"] = "Retry", "Повтор"
en["touchFloor"] = "Touch the floor to lock the position, then confirm"
ru["touchFloor"] = "Коснись пола для фиксации, затем подтверди"
en["buildPassage"], ru["buildPassage"] = "PASSAGE", "ПРОХОД"
en["buildSpawn"], ru["buildSpawn"] = "SPAWN", "ПОЯВЛЕНИЕ"
ru["buildHint"] = "Кликни на пол для фиксации · R — поворот"
en["gridMode"] = "Grid: 1 stud"
ru["gridMode"] = "Сетка: 1"
en["freeMode"] = "Free: 0.1 stud"
ru["freeMode"] = "Свободно: 0,1"
en["rotateItem"] = "Rotate"
ru["rotateItem"] = "Повернуть"
en["cancelBuild"] = "Cancel"
ru["cancelBuild"] = "Отмена"
en["floor-plant-v1"] = "Floor plant"
ru["floor-plant-v1"] = "Напольное растение"
en["side-table-v1"] = "Side table"
ru["side-table-v1"] = "Приставной столик"
en["floor-lamp-v1"] = "Floor lamp"
ru["floor-lamp-v1"] = "Торшер"
en["firstPurchaseHint"] = "You earned your first reward. Visit the furniture shop next to home."
ru["firstPurchaseHint"] =
	"Первая награда твоя. Загляни в магазин мебели рядом с домом."
en["firstPlacementHint"] = "Your purchase is in storage. Return home and place it."
ru["firstPlacementHint"] =
	"Покупка на складе. Вернись домой и установи её."
en["homeErrorChecking"] = "Checking this position…"
ru["homeErrorChecking"] = "Проверяем позицию…"
en["homeErrorValid"] = "Valid position · confirm to save"
ru["homeErrorValid"] = "Можно установить · подтверди сохранение"
en["homeErrorBounds"] = "Keep the entire item inside your room."
ru["homeErrorBounds"] =
	"Предмет должен целиком помещаться в комнате."
en["homeErrorBlocked"] = "Keep the doorway, spawn and existing furniture clear."
ru["homeErrorBlocked"] =
	"Не перекрывай проход, место появления и мебель."
en["homeErrorCollision"] = "This overlaps another piece of furniture."
ru["homeErrorCollision"] = "Здесь уже стоит другой предмет."
en["homeErrorNotOwned"] = "Choose an item from your own inventory."
ru["homeErrorNotOwned"] = "Выбери предмет из своего инвентаря."
en["homeErrorStaleRevision"] = "Your room changed. Check the position again."
ru["homeErrorStaleRevision"] =
	"Комната изменилась. Проверь позицию снова."
en["homeErrorUnknownProduct"] = "This model version is unavailable. The item remains yours."
ru["homeErrorUnknownProduct"] =
	"Эта версия предмета недоступна. Покупка остаётся твоей."
en["homeErrorRoomVersion"] = "This room layout needs an update."
ru["homeErrorRoomVersion"] = "Эта планировка требует обновления."
en["homeErrorInvalidPose"] = "Choose a position on the floor."
ru["homeErrorInvalidPose"] = "Выбери место на полу."
en["homeErrorGoHome"] = "Return to your own room to edit."
ru["homeErrorGoHome"] = "Для обустройства вернись в свою комнату."
en["homeErrorGoShop"] = "Go inside the furniture shop, closer to the counter."
ru["homeErrorGoShop"] = "Зайди в магазин и подойди к прилавку."
en["homeErrorInsufficientFunds"] = "Not enough dollars. Complete another order."
ru["homeErrorInsufficientFunds"] =
	"Не хватает долларов. Выполни ещё один заказ."
en["homeErrorUnavailable"] = "Waiting for confirmed profile data."
ru["homeErrorUnavailable"] = "Ждём подтверждённые данные профиля."
en["homeErrorInventoryConflict"] = "Your inventory is full or changed."
ru["homeErrorInventoryConflict"] = "Инвентарь заполнен или изменился."
en["homeErrorLimitReached"] = "This action has reached a limit."
ru["homeErrorLimitReached"] = "Достигнут лимит операции."
en["homeErrorRestart"] = "Editor closed after respawning. Your furniture is safe."
ru["homeErrorRestart"] =
	"Редактор закрыт после возрождения. Мебель сохранена."
en["homeErrorBought"] = "Purchased! Return home and open Furnish room."
ru["homeErrorBought"] =
	"Куплено! Вернись домой и открой «Обустроить»."
en["homeErrorSaving"] = "Saving the room…"
ru["homeErrorSaving"] = "Сохраняем комнату…"
en["retryPlacement"] = "Retry placement"
ru["retryPlacement"] = "Повторить"
en["placementDelayed"] = "Confirmation is taking longer. Retry the same position safely."
ru["placementDelayed"] =
	"Ответ задерживается. Повтори установку в том же месте."
en["clickFloor"] = "Click the floor to lock this position, then confirm"
ru["clickFloor"] =
	"Кликни на пол, чтобы зафиксировать место, затем подтверди"
en["resultTitle"] = "Work accepted"
en["contractSunroom"], ru["contractSunroom"] =
	"Sunroom refresh", "Солнечная комната"
en["briefSunroom"] =
	"Nina is making a sunny reading room. Protect the floor, paint the first wall warm white and the second mint, then inspect both. One payment for the whole room."
ru["briefSunroom"] =
	"Нина обустраивает светлую комнату для чтения. Укрой пол, покрась первую стену тёплым белым, вторую — мятным и проверь обе. Одна оплата за всю комнату."
en["contractAtelier"], ru["contractAtelier"] = "Artist's studio", "Студия художника"
en["briefAtelier"] =
	"Lev needs a calm studio for his paintings. Protect the floor, paint the first wall rose and the second warm white. Check both walls before handing in the whole job."
ru["briefAtelier"] =
	"Лев готовит уютную студию для своих картин. Укрой пол, покрась первую стену розовым, вторую — тёплым белым. Проверь обе стены и сдай работу целиком."
ru["resultTitle"] = "Работа принята"
en["resultBefore"] = "Before · sketch"
ru["resultBefore"] = "До · схема"
en["finishaccepted"], ru["finishaccepted"] =
	"Solid finish · %d%%", "Хороший финиш · %d%%"
en["finishexcellent"], ru["finishexcellent"] =
	"Excellent finish · %d%%", "Отличный финиш · %d%%"
en["finishperfect"], ru["finishperfect"] =
	"Perfect finish · %d%%", "Идеальный финиш · %d%%"
en["finishWalls"], ru["finishWalls"] =
	"Walls: %d%% / %d%% · weakest decides", "Стены: %d%% / %d%% · по худшей"
en["finishPaid"], ru["finishPaid"] =
	"Inspection passed. Payment confirmed.",
	"Проверка пройдена. Оплата подтверждена."
en["finishLegacy"] = "This older receipt has no saved wall preview. Its payment is confirmed."
ru["finishLegacy"] =
	"У старой квитанции нет схемы стен. Её оплата подтверждена."
en["paintOptional"], ru["paintOptional"] =
	"Ready · %d%% · Great: %d%%", "Можно сдать · %d%% · Отлично: %d%%"
en["paintExcellent"], ru["paintExcellent"] =
	"Excellent · %d%% · Perfect: %d%%", "Отлично · %d%% · Идеально: %d%%"
en["paintPerfect"], ru["paintPerfect"] =
	"Perfect · %d%% · Review to finish",
	"Идеально · %d%% · Проверь результат"
en["resultAfter"] = "After · accepted"
ru["resultAfter"] = "После · принято"
en["resultXP"] = "+%d painting XP"
ru["resultXP"] = "+%d опыта покраски"
en["resultAccepted"] = "Colour, preparation and coverage passed inspection. Payment confirmed."
ru["resultAccepted"] =
	"Цвет, подготовка и покрытие прошли проверку. Оплата подтверждена."
en["resultNext"] = "Use your earnings to buy furniture and make your room your own."
ru["resultNext"] =
	"Купи мебель на заработанные деньги и обустрой свою комнату."
en["resultContinue"] = "Continue"
ru["resultContinue"] = "Продолжить"
en["followRoute"] = "Follow route"
ru["followRoute"] = "К цели"
en["mapYou"] = "You"
ru["mapYou"] = "Ты"
en["mapNoJob"] = "Choose a job, or show a route from the shop catalogue."
ru["mapNoJob"] =
	"Выбери заказ или включи маршрут в каталоге магазина."
en["mapUnavailable"] = "Profile not confirmed"
ru["mapUnavailable"] = "Профиль не подтверждён"
en["floor-plant-v1Description"] = "A little greenery for a cosy room."
ru["floor-plant-v1Description"] = "Немного зелени для уютной комнаты."
en["floor-lamp-v1Description"] = "A tall lamp for a reading corner."
ru["floor-lamp-v1Description"] =
	"Высокий светильник для уголка чтения."
en["side-table-v1Description"] = "A small table for everyday things."
ru["side-table-v1Description"] = "Небольшой стол для нужных мелочей."
en["productSize"] = "%g × %g studs · floor"
ru["productSize"] = "%g × %g studs · на пол"
en["hideHints"] = "Hide hints"
ru["hideHints"] = "Скрыть подсказки"
en["showHints"] = "Show hints"
ru["showHints"] = "Показать подсказки"
en["homeErrorInvalidRequest"] = "This purchase could not be processed. Choose the item again."
ru["homeErrorInvalidRequest"] =
	"Не удалось обработать покупку. Выбери предмет заново."
en["homeErrorOperationConflict"] =
	"This request belongs to a different purchase. Check your inventory."
ru["homeErrorOperationConflict"] =
	"Запрос относится к другой покупке. Проверь склад."
en["profileErrorTitle"] = "Progress is protected"
ru["profileErrorTitle"] = "Прогресс защищён"
en["profileRecoveringTitle"] = "Restoring your session"
ru["profileRecoveringTitle"] = "Восстанавливаем сессию"
en["profileRecovering"] =
	"Checking the same saved operation. Purchases and work are paused until your data is confirmed."
ru["profileRecovering"] =
	"Проверяем ту же сохранённую операцию. Покупки и работа приостановлены до подтверждения данных."
en["profileRetry"] = "Retry"
ru["profileRetry"] = "Повторить"
en["profileRetrying"] = "Checking…"
ru["profileRetrying"] = "Проверяем…"
en["profileRetryWait"] = "Please wait"
ru["profileRetryWait"] = "Подожди"
en["profileNoRetry"] = "Unavailable"
ru["profileNoRetry"] = "Недоступно"
en["profileExit"] = "Leave game"
ru["profileExit"] = "Выйти"
en["profileReasonUnavailable"] =
	"Your data is temporarily unavailable. Your money and items are protected. Wait and retry."
ru["profileReasonUnavailable"] =
	"Данные временно недоступны. Деньги и вещи защищены. Подожди и повтори загрузку."
en["profileReasonLocked"] = "Your profile is open in another session. Close it, wait, then retry."
ru["profileReasonLocked"] =
	"Профиль открыт в другой сессии. Закрой её, подожди и нажми «Повторить»."
en["profileReasonCorrupt"] =
	"Your profile could not be verified. No replacement data was saved. Leave and try again later."
ru["profileReasonCorrupt"] =
	"Не удалось проверить профиль. Новые данные не записаны. Выйди и зайди позже."
en["profileReasonSessionLost"] =
	"The data session has ended. Operations are paused for safety. Leave and rejoin."
ru["profileReasonSessionLost"] =
	"Сессия данных потеряна. Операции остановлены для безопасности. Выйди и зайди снова."
en["profileReasonRoomVersion"] =
	"This room version is not supported yet. Your items are unchanged. Please return later."
ru["profileReasonRoomVersion"] =
	"Эта версия комнаты пока не поддерживается. Предметы не изменены. Зайди позже."
en["profileReasonCharacterLoad"] = "Your character could not load. Your profile is safe. Try again."
ru["profileReasonCharacterLoad"] =
	"Не удалось загрузить персонажа. Профиль защищён. Попробуй ещё раз."
en["profileReasonConfiguration"] =
	"This version cannot load player data yet. Leave and try again later."
ru["profileReasonConfiguration"] =
	"Эта версия игры пока не может загрузить данные. Выйди и зайди позже."
en["profileReasonInvalidOwner"] = "Your account could not be verified. Leave and rejoin."
ru["profileReasonInvalidOwner"] =
	"Не удалось подтвердить аккаунт. Выйди и зайди снова."
en["contractTutorial"] = "First renovation"
ru["contractTutorial"] = "Первый ремонт"
en["contractMint"] = "Mint living room"
ru["contractMint"] = "Мятная гостиная"
en["contractRose"] = "Rose bedroom"
ru["contractRose"] = "Розовая спальня"
en["briefTutorial"] =
	"A first client needs a fresh warm-white wall. Inspect it, protect the floor and roll on the paint."
ru["briefTutorial"] =
	"Первому клиенту нужна стена тёплого белого цвета. Осмотри её, защити пол и покрась валиком."
en["briefMint"] =
	"Give this living room a calm mint finish. Choose the requested colour and leave no large gaps."
ru["briefMint"] =
	"Обнови гостиную в спокойном мятном цвете. Выбери нужную краску и не оставляй больших пропусков."
en["briefRose"] =
	"The client wants a warm rose bedroom. Prepare the room and paint the wall in the requested shade."
ru["briefRose"] =
	"Клиент хочет спальню в розовых тонах. Подготовь комнату и покрась стену в нужный оттенок."
en["contractAddress"] = "Client apartment · next building"
ru["contractAddress"] = "Квартира клиента · соседний дом"
en["contractMaterial"] = "Requested colour: %s"
ru["contractMaterial"] = "Нужный цвет: %s"
en["contractReward"] = "$%d · +%d XP"
ru["contractReward"] = "$%d · +%d XP"
en["backOffers"] = "Back to jobs"
ru["backOffers"] = "К списку заказов"
en["acceptingJob"] = "Accepting…"
ru["acceptingJob"] = "Принимаем…"
en["offerLocked"] = "Not unlocked yet"
ru["offerLocked"] = "Пока недоступно"
en["offerReady"] = "Available · view details"
ru["offerReady"] = "Доступно · подробнее"
en["offerXPNeeded"] = "%d more painting XP to unlock"
ru["offerXPNeeded"] = "До открытия: ещё %d XP"
en["paintingExperience"] = "Painting mastery: %d XP"
ru["paintingExperience"] = "Мастерство маляра: %d XP"
en["wideRollerGoal"] = "Wide roller unlocks in %d XP"
ru["wideRollerGoal"] = "До широкого валика: %d XP"
en["wideRollerUnlocked"] = "Wide roller unlocked"
ru["wideRollerUnlocked"] = "Широкий валик открыт"
en["offerWaiting"] = "Waiting for confirmed job offers…"
ru["offerWaiting"] = "Ждём подтверждённые предложения…"
en["basicRoller"] = "Standard roller"
ru["basicRoller"] = "Обычный валик"
en["wideRoller"] = "Wide roller"
ru["wideRoller"] = "Широкий валик"
en["wideUnlockedResult"] = "New tool unlocked: wide roller!"
ru["wideUnlockedResult"] =
	"Открыт новый инструмент: широкий валик!"
en["toolSelected"] = "(selected)"
ru["toolSelected"] = "(выбран)"
en["colorRetry"] = "You can choose again."
ru["colorRetry"] = "Можно выбрать заново."
en["jobErrorOfferLocked"] = "Earn more painting XP to unlock this contract."
ru["jobErrorOfferLocked"] =
	"Для этого заказа нужно больше опыта маляра."
en["jobErrorUnknownOffer"] = "This offer is unavailable. Open the job list again."
ru["jobErrorUnknownOffer"] =
	"Это предложение недоступно. Открой список заказов заново."
en["jobErrorToolLocked"] = "This roller is not available for this step or mastery level."
ru["jobErrorToolLocked"] =
	"Этот валик недоступен на этом этапе или уровне мастерства."
en["roomPlan"] = "Room plan"
ru["roomPlan"] = "План комнаты"
en["roomPlanProgress"] = "Furnished: %d / %d"
ru["roomPlanProgress"] = "Обустроено: %d / %d"
en["roomPlanOptional"] = "Optional ideas for your room. Place items to complete them."
ru["roomPlanOptional"] =
	"Идеи по желанию. Установи предметы, чтобы выполнить план."
en["greenHome"] = "A little greenery"
ru["greenHome"] = "Немного зелени"
en["readingCorner"] = "A reading corner"
ru["readingCorner"] = "Уголок для чтения"
en["homeStorage"] = "A place for your books"
ru["homeStorage"] = "Место для книг"
en["roomGoalComplete"] = "Ready"
ru["roomGoalComplete"] = "Готово"
en["reading-chair-v1"] = "Reading chair"
ru["reading-chair-v1"] = "Кресло для чтения"
en["reading-chair-v1Description"] = "A soft chair you can sit in. Jump to get up."
ru["reading-chair-v1Description"] =
	"Мягкое кресло с сиденьем. Прыгни, чтобы встать."
en["bookcase-v1"] = "Bookcase"
ru["bookcase-v1"] = "Книжный шкаф"
en["bookcase-v1Description"] = "Warm wooden shelves with a colourful book collection."
ru["bookcase-v1Description"] =
	"Деревянные полки с коллекцией разноцветных книг."
en["residentNina"] = "Nina"
ru["residentNina"] = "Нина"
en["residentMila"] = "Mila"
ru["residentMila"] = "Мила"
en["residentLev"] = "Leo"
ru["residentLev"] = "Лев"
en["clientResident"] = "Client"
ru["clientResident"] = "Заказчик"
en["talkClient"] = "Talk"
ru["talkClient"] = "Поговорить"
en["meetClient"] = "Meet the client"
ru["meetClient"] = "Поговорить с клиентом"
en["handoverClient"] = "Show the client"
ru["handoverClient"] = "Показать заказчику"
en["meetClientHint"] = "Meet the resident by the wall. They will explain the job."
ru["meetClientHint"] =
	"Подойди к жителю у стены. Он расскажет о работе."
en["handoverClientHint"] = "Show the finished wall to the client and confirm the handover."
ru["handoverClientHint"] =
	"Покажи готовую стену заказчику и подтверди сдачу."
en["residentWelcome"] =
	"Welcome! I would like to refresh this wall. Inspect it first, then protect the floor and choose my requested colour."
ru["residentWelcome"] =
	"Привет! Хочу обновить эту стену. Сначала осмотри её, затем защити пол и выбери указанный цвет."
en["residentProtect"] =
	"Please protect the floor before painting. The furniture is out of your way."
ru["residentProtect"] =
	"Перед покраской защити пол. Мебель не мешает работе."
en["residentColour"] =
	"Choose the colour listed below. You can change a mistaken choice without a penalty."
ru["residentColour"] =
	"Выбери цвет, указанный ниже. Ошибочный выбор можно исправить без штрафа."
en["residentWorking"] = "Take your time with the roller. Cover the gaps, then review your work."
ru["residentWorking"] =
	"Спокойно пройди стену валиком. Закрась пропуски, затем проверь результат."
en["residentReview"] =
	"Ready to show your work? Confirm the handover and I will pay once the checks pass."
ru["residentReview"] =
	"Готов показать работу? Подтверди сдачу — после проверки получишь оплату."
en["residentThanks"] =
	"Thank you! This room feels fresh again. Your payment has been confirmed. Enjoy furnishing your own home!"
ru["residentThanks"] =
	"Спасибо! Комната стала уютнее. Оплата подтверждена. Теперь можно обустроить свой дом!"
en["residentReward"] = "Contract reward: $%d"
ru["residentReward"] = "Награда по заказу: $%d"
en["closeClient"] = "Back to the room"
ru["closeClient"] = "Вернуться в комнату"
en["firstSteps"] = "First steps"
ru["firstSteps"] = "Первые шаги"
en["guideWaiting"] = "Waiting for confirmed progress…"
ru["guideWaiting"] = "Ждём подтверждённый прогресс…"
en["guideWaitAction"] = "Please wait"
ru["guideWaitAction"] = "Подожди"
en["guideCount"] = "First cycle: %d / %d steps completed"
ru["guideCount"] = "Первый цикл: пройдено %d из %d шагов"
en["guideFinished"] = "You have learned the basics!"
ru["guideFinished"] = "Ты освоил основу!"
en["guideFreedom"] = "Choose another job or make your room your own."
ru["guideFreedom"] = "Бери новый заказ или обустраивай комнату."
en["guideAllSteps"] = "All steps"
ru["guideAllSteps"] = "Все шаги"
en["guideDone"] = "Completed"
ru["guideDone"] = "Пройдено"
en["guideNow"] = "Your next step"
ru["guideNow"] = "Следующий шаг"
en["guideLater"] = "You can read ahead"
ru["guideLater"] = "Можно прочитать заранее"
en["guideDoneReview"] = "Already completed. Reading this does not reset progress."
ru["guideDoneReview"] =
	"Уже пройдено. Просмотр не сбрасывает прогресс."
en["guideReturnJob"] = "Return to the job"
ru["guideReturnJob"] = "Вернуться к заказу"
en["guideJob"] = "Choose a job"
ru["guideJob"] = "Выбрать заказ"
en["guideMeet"] = "Meet and inspect"
ru["guideMeet"] = "Познакомиться и осмотреть"
en["guidePrepare"] = "Prepare the room"
ru["guidePrepare"] = "Подготовить комнату"
en["guidePaint"] = "Paint and review"
ru["guidePaint"] = "Покрасить и проверить"
en["guidePay"] = "Hand over the work"
ru["guidePay"] = "Сдать работу"
en["guideBuy"] = "Buy furniture"
ru["guideBuy"] = "Купить мебель"
en["guidePlace"] = "Furnish your home"
ru["guidePlace"] = "Обустроить свой дом"
en["guideJobDetail"] =
	"Press %s or HOME, then Jobs. Read a card's colour and reward before accepting. Accepting a job does not pay you yet."
ru["guideJobDetail"] =
	"Нажми %s или ДОМ, затем Заказы. Прочитай цвет и награду в карточке и прими заказ. Само принятие ещё не даёт денег."
en["guideMeetDetail"] =
	"Follow the arrow to the resident. Talk using the yellow action or E, then choose Inspect wall. You must be close and have a clear view."
ru["guideMeetDetail"] =
	"Иди по стрелке к жителю. Поговори жёлтой кнопкой или E, затем выбери осмотр стены. Нужно подойти близко, без стены между вами."
en["guidePrepareDetail"] =
	"Lay protective film. Open the paint palette, choose your roller and the requested colour. You can correct a wrong colour without a fine."
ru["guidePrepareDetail"] =
	"Постели плёнку. Открой палитру, выбери валик и нужный цвет. Ошибочную краску можно исправить без штрафа."
en["guidePaintDetail"] =
	"Hold and move the roller across the wall. Fill gaps, then Review. You can leave the work view and continue; after death, prepare again."
ru["guidePaintDetail"] =
	"Зажми и веди валик по стене. Закрась пропуски и проверь результат. Можно выйти из рабочего вида и продолжить; после смерти нужна новая подготовка."
en["guidePayDetail"] =
	"Show the checked wall to the resident and confirm the handover. The server pays once; the result shows confirmed dollars and XP."
ru["guidePayDetail"] =
	"Покажи проверенную стену жителю и подтверди сдачу. Сервер платит один раз; итог показывает подтверждённые доллары и опыт."
en["guideBuyDetail"] =
	"Open the furniture shop and use Show shop to walk to the counter. Choose an affordable item. Wait for ownership confirmation before opening inventory."
ru["guideBuyDetail"] =
	"Открой магазин и нажми «Где магазин», чтобы дойти до прилавка. Выбери доступный предмет. После подтверждения покупки открой склад."
en["guidePlaceDetail"] =
	"Open inventory and return home. Choose Place, point at the floor, then confirm a valid position. Grid/Free and rotation help you arrange your room."
ru["guidePlaceDetail"] =
	"Открой склад и вернись домой. Выбери предмет, укажи место на полу и подтверди допустимую позицию. Используй сетку, свободный режим и поворот."
en["contractDuo"] = "Two-tone living room"
ru["contractDuo"] = "Гостиная в двух цветах"
en["briefDuo"] =
	"Two walls, one contract: mint first, rose second. Review each wall. The client pays after both pass."
ru["briefDuo"] =
	"Две стены, один заказ: сначала мятная, затем розовая. Проверь каждую. Оплата — после сдачи обеих."
en["nextSurface"] = "Start the second wall"
ru["nextSurface"] = "Ко второй стене"
en["jobSurfaceReady"] = "First wall accepted · 1 / 2"
ru["jobSurfaceReady"] = "Первая стена принята · 1 / 2"
en["nextSurfaceHint"] =
	"The first wall passed. Start the second, choose rose and paint it. Payment follows both walls."
ru["nextSurfaceHint"] =
	"Первая стена проверена. Перейди ко второй, выбери розовый и покрась. Оплата — за обе."
en["residentNextWall"] =
	"The mint wall looks good! Now paint the side wall rose. I will pay for both walls together at handover."
ru["residentNextWall"] =
	"Мятная стена готова! Теперь покрась боковую в розовый. За обе стены заплачу вместе при сдаче."
en["surfaceProgress"] = "Wall %d / %d"
ru["surfaceProgress"] = "Стена %d / %d"
en["resultAfterDuo"] = "After · 2 walls"
ru["resultAfterDuo"] = "После · 2 стены"
en["resultAcceptedDuo"] =
	"Both colours and walls passed inspection. One payment confirmed for the whole contract."
ru["resultAcceptedDuo"] =
	"Оба цвета и обе стены прошли проверку. Подтверждена одна оплата за весь заказ."
en["storePending"] = "Returning this item to inventory…"
ru["storePending"] = "Возвращаем предмет на склад…"
en["storeUncertain"] = "Confirmation is taking longer. Retry the same item."
ru["storeUncertain"] =
	"Ответ задерживается. Повтори возврат того же предмета."
en["storeBusy"] = "Saving…"
ru["storeBusy"] = "Подождите"
en["retryStore"] = "Retry"
ru["retryStore"] = "Повторить"
en["homeErrorStored"] = "Item returned to inventory. It is still yours."
ru["homeErrorStored"] = "Предмет на складе. Он по-прежнему твой."
en["routeFinding"] = "Finding a path…"
ru["routeFinding"] = "Ищем путь…"
en["routeUnavailable"] = "Path unavailable"
ru["routeUnavailable"] = "Нет маршрута"
en["followPath"] = "Follow the gold marker"
ru["followPath"] = "Иди к золотой метке"
en["stopShopRoute"] = "Stop route"
ru["stopShopRoute"] = "Убрать маршрут"
en["goToShop"] = "Go to the furniture shop"
ru["goToShop"] = "Иди в мебельный магазин"
en["shopRouteHint"] =
	"Follow gold markers through the shop door. At the counter, open the catalogue."
ru["shopRouteHint"] =
	"Иди по золотым меткам через дверь магазина. У прилавка открой каталог."
en["shopArrivalHint"] =
	"You can shop here. Open the catalogue and choose an item; nothing is bought automatically."
ru["shopArrivalHint"] =
	"Ты в магазине. Открой каталог и выбери предмет; покупку нужно подтвердить."
en["mapShop"] = "Shop"
ru["mapShop"] = "Магазин"
en["arrivedShop"] = "At the furniture shop"
ru["arrivedShop"] = "Ты в магазине"
en["masteryNext"] = "Next: %s · %d XP"
ru["masteryNext"] = "Далее: %s · ещё %d XP"
en["masteryAll"] = "All %d orders unlocked"
ru["masteryAll"] = "Открыты все заказы: %d"
en["contractDuoShort"] = "Two walls"
ru["contractDuoShort"] = "Две стены"
en["masteryOpened"] = "New order: %s"
ru["masteryOpened"] = "Новый заказ: %s"
en["masteryView"] = "View an order"
ru["masteryView"] = "Посмотреть заказ"
en["masteryRepeatHint"] =
	"All current orders are open. Choose a repair or keep decorating your room."
ru["masteryRepeatHint"] =
	"Все текущие заказы открыты. Выбери ремонт или продолжай обустраивать комнату."
local Strings = {}
en["roomPlanFinished"] = "All room goals complete. Choose another repair."
ru["roomPlanFinished"] =
	"Все цели готовы. Можно выбрать новый ремонт."
en["abandonTitle"] = "Abandon this order?"
ru["abandonTitle"] = "Отказаться от заказа?"
en["abandonWarning"] =
	"Work on this order will be reset.\nYour money and furniture stay with you.\nUnfinished work does not pay a reward."
ru["abandonWarning"] =
	"Выполнение этого заказа будет сброшено.\nДеньги и мебель сохранятся.\nЗа незавершённую работу награды нет."
en["abandonKeep"] = "Return to order"
ru["abandonKeep"] = "Вернуться к заказу"
en["abandonConfirm"] = "Abandon order"
ru["abandonConfirm"] = "Отказаться"
en["abandonPendingTitle"] = "Confirming cancellation"
ru["abandonPendingTitle"] = "Проверяем отказ"
en["abandonPendingHint"] =
	"Waiting for confirmation. You can close this window.\nIf it takes longer, retry checks this same order. New orders wait until this is resolved."
ru["abandonPendingHint"] =
	"Ждём подтверждения. Это окно можно закрыть.\nПри задержке повтор проверит тот же заказ. Новые заказы пока недоступны."
en["abandonClose"] = "Close"
ru["abandonClose"] = "Закрыть"
en["abandonRetry"] = "Retry cancellation"
ru["abandonRetry"] = "Повторить отказ"
en["roomBudgetCost"] = "Placed %d/%d · To buy $%d"
ru["roomBudgetCost"] = "Поставлено %d/%d · Докупить $%d"
en["roomBudgetNeed"] = "Still needed: $%d"
ru["roomBudgetNeed"] = "Не хватает: $%d"
en["roomBudgetStored"] = "All bought — arrange your furniture"
ru["roomBudgetStored"] = "Всё куплено — расставь мебель"
en["roomBudgetReady"] = "Enough for the remaining furniture"
ru["roomBudgetReady"] = "Хватит на недостающую мебель"
en["roomBudgetEarn"] = "Find work for this goal"
ru["roomBudgetEarn"] = "Найти работу для этой цели"
function Strings.text(language: string, key: string): string
	return (if language == "ru" then ru[key] else en[key]) or en[key] or key
end
return table.freeze(Strings)
