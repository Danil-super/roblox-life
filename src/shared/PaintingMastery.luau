--!strict
local Types = require("./JobTypes")
local Config = require("./PaintConfig")
local Strings = require("./Strings")
export type Offer = Types.Offer
export type Milestone = { id: string, titleKey: string, requiredXP: number }
export type Progress = {
	ready: boolean,
	xp: number,
	fraction: number,
	needed: number,
	nextId: string?,
	nextTitleKey: string?,
	recommendedId: string?,
	recommendedTitleKey: string?,
	openCount: number,
	total: number,
	wide: boolean,
	wideJustUnlocked: boolean,
	opened: { Milestone },
}
local Mastery = {}
local function integer(n: number?): boolean
	return n ~= nil and n == n and n >= 0 and n <= 9007199254740991 and n % 1 == 0
end
function Mastery.evaluate(
	xp: number?,
	offers: { Offer }?,
	available: boolean,
	gained: number?
): Progress
	local p: Progress = {
		ready = false,
		xp = 0,
		fraction = 0,
		needed = 0,
		openCount = 0,
		total = 0,
		wide = false,
		wideJustUnlocked = false,
		opened = {},
	}
	if not available or not integer(xp) or xp == nil or offers == nil or #offers == 0 then
		return p
	end
	local ids: { [string]: boolean } = {}
	for _, o in offers do
		if ids[o.id] or not integer(o.requiredXP) or o.unlocked ~= (xp >= o.requiredXP) then
			return p
		end
		ids[o.id] = true
	end
	p.ready, p.xp, p.total = true, xp, #offers
	p.wide = xp >= Config.wideRollerXP
	local before = if integer(gained) and gained ~= nil and gained <= xp then xp - gained else nil
	p.wideJustUnlocked = before ~= nil and before < Config.wideRollerXP and p.wide
	local nextOffer: Offer? = nil
	local recommended: Offer? = nil
	for _, o in offers do
		if o.unlocked then
			p.openCount += 1
			if
				recommended == nil
				or o.requiredXP > recommended.requiredXP
				or (o.requiredXP == recommended.requiredXP and o.id < recommended.id)
			then
				recommended = o
			end
			if before ~= nil and o.requiredXP > before then
				table.insert(
					p.opened,
					{ id = o.id, titleKey = o.titleKey, requiredXP = o.requiredXP }
				)
			end
		elseif
			nextOffer == nil
			or o.requiredXP < nextOffer.requiredXP
			or (o.requiredXP == nextOffer.requiredXP and o.id < nextOffer.id)
		then
			nextOffer = o
		end
	end
	table.sort(p.opened, function(a: Milestone, b: Milestone): boolean
		return if a.requiredXP == b.requiredXP then a.id < b.id else a.requiredXP < b.requiredXP
	end)
	if recommended then
		p.recommendedId, p.recommendedTitleKey = recommended.id, recommended.titleKey
	end
	if nextOffer then
		p.nextId = nextOffer.id
		p.nextTitleKey = if nextOffer.id == "paint-duo-v1"
			then "contractDuoShort"
			else nextOffer.titleKey
		p.needed = nextOffer.requiredXP - xp
		local previous = 0
		for _, o in offers do
			if o.requiredXP < nextOffer.requiredXP then
				previous = math.max(previous, o.requiredXP)
			end
		end
		if Config.wideRollerXP < nextOffer.requiredXP then
			previous = math.max(previous, Config.wideRollerXP)
		end
		p.fraction = math.clamp((xp - previous) / (nextOffer.requiredXP - previous), 0, 1)
	else
		p.fraction = 1
	end
	return p
end
function Mastery.goalText(p: Progress, language: string): string
	if not p.ready then
		return Strings.text(language, "offerWaiting")
	end
	if p.nextTitleKey then
		return string.format(
			Strings.text(language, "masteryNext"),
			Strings.text(language, p.nextTitleKey),
			p.needed
		)
	end
	return string.format(Strings.text(language, "masteryAll"), p.total)
end
return table.freeze(Mastery)
