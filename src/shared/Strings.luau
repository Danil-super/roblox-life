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
local Strings = {}
function Strings.text(language: string, key: string): string
	return (if language == "ru" then ru[key] else en[key]) or en[key] or key
end
return table.freeze(Strings)
