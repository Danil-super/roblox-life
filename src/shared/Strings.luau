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
en["jobs"] = "Jobs"
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
en["jobColor"] = "Choose the warm-white paint"
ru["jobColor"] = "Выбери тёплый белый цвет"
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
ru["paintDrag"] = "Веди валик по стене"
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
en["jobErrorCoverage"] =
	"Some gaps remain or the paint is still settling. Continue and inspect again."
ru["jobErrorCoverage"] =
	"Есть пропуски или краска ещё не легла. Продолжи и проверь снова."
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
en["colorHint"] = "Open the paint palette and choose Warm white."
ru["colorHint"] = "Открой палитру и выбери «Тёплый белый»."
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
en["jobRouteHint"] = "Follow the large arrow to the marked wall inside your client’s room."
ru["jobRouteHint"] =
	"Иди по большой стрелке к отмеченной стене в комнате клиента."
en["openMap"] = "Open route map"
ru["openMap"] = "Открыть карту маршрута"
en["shopTitle"] = "Furniture shop"
ru["shopTitle"] = "Магазин мебели"
en["inventoryTitle"] = "Your furniture"
ru["inventoryTitle"] = "Твоя мебель"
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
en["clickFloor"] = "Click the floor to lock this position, then confirm"
ru["clickFloor"] =
	"Кликни на пол, чтобы зафиксировать место, затем подтверди"
en["resultTitle"] = "Work accepted"
ru["resultTitle"] = "Работа принята"
en["resultBefore"] = "Before · unpainted"
ru["resultBefore"] = "До · без покраски"
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
en["mapNoJob"] = "Accept a job in Jobs to choose a destination."
ru["mapNoJob"] = "Прими заказ в Jobs, чтобы выбрать цель."
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
local Strings = {}
function Strings.text(language: string, key: string): string
	return (if language == "ru" then ru[key] else en[key]) or en[key] or key
end
return table.freeze(Strings)
