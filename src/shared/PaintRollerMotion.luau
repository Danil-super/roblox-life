--!strict
export type State = { x: number?, y: number?, spin: number, tilt: number }
local Motion = {}
function Motion.new(): State
	return { spin = 0, tilt = 0 }
end
function Motion.reset(state: State): ()
	state.x, state.y, state.spin, state.tilt = nil, nil, 0, 0
end
function Motion.step(state: State, x: number, y: number, pressed: boolean, animate: boolean): ()
	if x ~= x or y ~= y or math.abs(x) == math.huge or math.abs(y) == math.huge then
		Motion.reset(state)
		return
	end
	if not animate then
		state.spin, state.tilt = 0, 0
	elseif pressed and state.x ~= nil and state.y ~= nil then
		-- Foam radius is 0.19 studs; cap cursor jumps without changing game coverage.
		state.spin = (state.spin + math.clamp(y - state.y, -1.5, 1.5) / 0.19) % (math.pi * 2)
		state.tilt = math.clamp((x - state.x) * 0.2, -math.rad(12), math.rad(12))
	else
		state.tilt = 0
	end
	state.x, state.y = if pressed then x else nil, if pressed then y else nil
end
return table.freeze(Motion)
