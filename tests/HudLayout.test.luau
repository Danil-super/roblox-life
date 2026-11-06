--!strict
-- Hiding teaching hints must preserve the primary action and route geometry.
local Layout = require("../src/shared/HudLayout")
type Rect = Layout.Rect
local function overlaps(a: Rect, b: Rect): boolean
	return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end
local function inside(rect: Rect, width: number, height: number): ()
	assert(rect.x >= 0 and rect.y >= 0 and rect.w > 0 and rect.h > 0, "Invalid HUD rectangle")
	assert(rect.x + rect.w <= width and rect.y + rect.h <= height, "HUD outside safe area")
end
for _, size in
	{ { 666, 316 }, { 568, 262 }, { 812, 317 }, { 374, 608 }, { 320, 480 }, { 1024, 710 } }
do
	local w, h = size[1], size[2]
	local hud = Layout.compute(w, h, true)
	local joystick: Rect = { x = 0, y = h - 140, w = 140, h = 140 }
	local jump: Rect = { x = w - 120, y = h - 140, w = 120, h = 140 }
	local top = { hud.wallet, hud.language, hud.home, hud.objective }
	for i, rect in top do
		inside(rect, w, h)
		assert(
			not overlaps(rect, joystick) and not overlaps(rect, jump),
			"HUD covers touch controls"
		)
		for j = i + 1, #top do
			assert(not overlaps(rect, top[j]), "HUD cards overlap")
		end
	end
	for _, rect in { hud.navigation } do
		inside(rect, w, h)
		assert(
			not overlaps(rect, joystick) and not overlaps(rect, jump),
			"Route covers touch controls"
		)
		assert(not overlaps(rect, hud.objective), "Route covers objective")
	end
	for _, card in { hud.wallet, hud.language, hud.home } do
		assert(not overlaps(hud.navigation, card), "Route covers a HUD control")
	end
	local action: Rect = {
		x = hud.objective.x + 14,
		y = hud.objective.y + (if hud.minimal then 8 elseif hud.compact then 48 else 92),
		w = hud.objective.w - 28,
		h = 44,
	}
	-- Landscape DynamicThumbstick's capture area starts one third down the safe screen.
	if w > h and h < 560 then
		local capture: Rect = { x = 0, y = h / 3, w = w * 0.4, h = h * 2 / 3 }
		assert(not overlaps(action, capture), "Action overlaps dynamic thumbstick capture area")
	end
	assert(
		hud.home.w >= 44 and hud.home.h >= 44 and hud.language.w >= 44 and hud.language.h >= 44,
		"Touch target too small"
	)
end
local pc = Layout.compute(1280, 720, false)
assert(not pc.compact and pc.wallet.w == 184 and pc.objective.y == 548, "Desktop layout changed")
local rotated = Layout.compute(316, 666, true)
assert(not rotated.compact and rotated.objective.w == 292, "Portrait did not restore details")
local blocked = Layout.compute(568, 262, true, false)
assert(
	not blocked.compact and not blocked.minimal and blocked.objective.h == 156,
	"Profile error collapsed"
)
print("HudLayout: 9 phone/tablet/desktop/rotation/error scenarios passed")
for _, touch in { false, true } do
	local shown = Layout.compute(1280, 720, touch, true, true)
	local hidden = Layout.compute(1280, 720, touch, true, false)
	assert(shown.hintVisible == true and hidden.hintVisible == false, "Hint preference ignored")
	assert(shown.objective.h == hidden.objective.h, "Hiding hints moved primary action")
	assert(shown.navigation.y == hidden.navigation.y, "Hiding hints moved route")
	assert(
		not Layout.compute(1280, 720, touch, false, true).hintVisible,
		"Error became tutorial hint"
	)
end
assert(not Layout.compute(568, 262, true, true, true).hintVisible, "Compact hint overlaps controls")
print("HudLayout: hint preference preserves action/route and profile-error layout")
for _, size in
	{
		{ 1280, 720 },
		{ 926, 403 },
		{ 666, 316 },
		{ 568, 262 },
		{ 374, 608 },
		{ 320, 480 },
		{
			1024,
			710,
		},
	}
do
	for _, touch in { false, true } do
		local w, h = size[1], size[2]
		local quiet = Layout.compute(w, h, touch, true, true, true)
		inside(quiet.objective, w, h)
		assert(
			quiet.compact and not quiet.hintVisible and quiet.objective.h <= 100,
			"Home card did not shrink"
		)
		for _, other in { quiet.wallet, quiet.home, quiet.language } do
			assert(not overlaps(quiet.objective, other), "Quiet goal covers HUD controls")
		end
		if touch then
			assert(
				not overlaps(quiet.objective, { x = 0, y = h - 140, w = 140, h = 140 })
					and not overlaps(
						quiet.objective,
						{ x = w - 120, y = h - 140, w = 120, h = 140 }
					),
				"Quiet goal covers touch buttons"
			)
		end
		local hidden = Layout.compute(w, h, touch, true, false, true)
		assert(
			hidden.objective.h == quiet.objective.h and hidden.objective.y == quiet.objective.y,
			"Hint toggle moved home action"
		)
		assert(
			Layout.compute(w, h, touch, false, false, true).objective.h == 156,
			"Profile error stayed quiet"
		)
	end
end
print("HudLayout: quiet home cards, controls, error priority, hints and rotation passed")
