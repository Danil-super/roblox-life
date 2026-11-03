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
local Strings = {}
function Strings.text(language: string, key: string): string
	return (if language == "ru" then ru[key] else en[key]) or en[key] or key
end
return table.freeze(Strings)
