--!strict
export type ConfigData = {
	columns: number,
	rows: number,
	threshold: number,
	minSeconds: number,
	maxPoints: number,
	packetInterval: number,
	maxSegment: number,
	rollerRadius: number,
	areaPerSecond: number,
	areaBurst: number,
	colorId: string,
}
type Point = { u: number, v: number }
export type State = {
	config: ConfigData,
	jobId: string,
	workId: string,
	phase: string,
	cells: { [number]: boolean },
	count: number,
	seq: number,
	lastAt: number,
	startedAt: number,
	tokens: number,
	lastPoint: Point?,
}
local Painting = {}
local function finite(n: unknown): boolean
	return type(n) == "number" and n == n and math.abs(n) < math.huge
end
local function settings(raw: unknown): ConfigData
	assert(type(raw) == "table", "Painting configuration required")
	local values = raw :: { [string]: unknown }
	local function number(key: string, low: number, high: number): number
		local value = values[key]
		assert(
			finite(value) and (value :: number) >= low and (value :: number) <= high,
			"Invalid paint setting: " .. key
		)
		return value :: number
	end
	local color = values.colorId
	assert(type(color) == "string" and #color > 0 and #color <= 32, "Invalid paint color")
	local config: ConfigData = {
		columns = number("columns", 1, 64),
		rows = number("rows", 1, 64),
		threshold = number("threshold", 0.1, 1),
		minSeconds = number("minSeconds", 1, 600),
		maxPoints = number("maxPoints", 1, 64),
		packetInterval = number("packetInterval", 0.02, 1),
		maxSegment = number("maxSegment", 0.01, 1),
		rollerRadius = number("rollerRadius", 0.1, 2),
		areaPerSecond = number("areaPerSecond", 1, 128),
		areaBurst = number("areaBurst", 1, 4096),
		colorId = color,
	}
	assert(
		config.columns % 1 == 0 and config.rows % 1 == 0 and config.maxPoints % 1 == 0,
		"Integer paint dimensions required"
	)
	return config
end
function Painting.new(jobId: string, workId: string, now: number, rawConfig: unknown): State
	assert(finite(now), "Valid clock required")
	local Config = settings(rawConfig)
	return {
		config = table.clone(Config),
		jobId = jobId,
		workId = workId,
		phase = "Inspect",
		cells = {},
		count = 0,
		seq = 0,
		lastAt = now,
		startedAt = now,
		tokens = Config.areaBurst,
		lastPoint = nil,
	}
end
function Painting.step(
	s: State,
	action: string,
	material: string?,
	now: number,
	eligible: boolean
): boolean
	local Config = s.config
	if not eligible or not finite(now) or now < s.lastAt then
		return false
	end
	if action == "inspect" and s.phase == "Inspect" then
		s.phase = "Prepare"
	elseif action == "prepare" and s.phase == "Prepare" then
		s.phase = "ChooseMaterial"
	elseif action == "choose" and s.phase == "ChooseMaterial" and material == Config.colorId then
		s.phase, s.startedAt, s.lastAt = "Painting", now, now
	elseif
		action == "review"
		and s.phase == "Painting"
		and s.count / (Config.columns * Config.rows) >= Config.threshold
		and now - s.startedAt >= Config.minSeconds
	then
		s.phase = "Ready"
	else
		return false
	end
	return true
end
local function points(Config: ConfigData, raw: unknown): { Point }?
	if type(raw) ~= "table" then
		return nil
	end
	local entries = raw :: { [number]: unknown }
	local result: { Point } = {}
	local count = 0
	for key, value in next, entries do
		count += 1
		if
			count > Config.maxPoints
			or type(key) ~= "number"
			or key % 1 ~= 0
			or key < 1
			or key > Config.maxPoints
			or type(value) ~= "table"
		then
			return nil
		end
		local p = value :: { [string]: unknown }
		local fields = 0
		for field in next, p do
			if field ~= "u" and field ~= "v" then
				return nil
			end
			fields += 1
		end
		if fields ~= 2 or not finite(p.u) or not finite(p.v) then
			return nil
		end
		local u, v = p.u :: number, p.v :: number
		if u < 0 or u > 1 or v < 0 or v > 1 then
			return nil
		end
		result[key] = { u = u, v = v }
	end
	if count < 1 then
		return nil
	end
	for i = 1, count do
		if result[i] == nil then
			return nil
		end
	end
	return result
end
local function mark(Config: ConfigData, cells: { [number]: boolean }, p: Point): ()
	local x, y = p.u * Config.columns, p.v * Config.rows
	local cx, cy =
		math.min(math.floor(x), Config.columns - 1), math.min(math.floor(y), Config.rows - 1)
	cells[cy * Config.columns + cx + 1] = true
	for row = math.max(0, cy - 1), math.min(Config.rows - 1, cy + 1) do
		for col = math.max(0, cx - 1), math.min(Config.columns - 1, cx + 1) do
			if (col + 0.5 - x) ^ 2 + (row + 0.5 - y) ^ 2 <= Config.rollerRadius ^ 2 then
				cells[row * Config.columns + col + 1] = true
			end
		end
	end
end
function Painting.batch(
	s: State,
	sequence: number,
	raw: unknown,
	starts: boolean,
	now: number,
	eligible: boolean
): boolean
	local Config = s.config
	if
		not eligible
		or s.phase ~= "Painting"
		or not finite(now)
		or now - s.lastAt < Config.packetInterval
		or not finite(sequence)
		or sequence % 1 ~= 0
		or sequence ~= s.seq + 1
		or sequence > 1000000000
	then
		return false
	end
	local path = points(Config, raw)
	if path == nil then
		return false
	end
	local previous = if starts then nil else s.lastPoint
	local cells = table.clone(s.cells)
	for _, p in path do
		if previous ~= nil then
			local du, dv = p.u - previous.u, p.v - previous.v
			local distance = math.sqrt(du * du + dv * dv)
			if distance > Config.maxSegment then
				return false
			end
			local from = previous
			local steps = math.max(1, math.ceil(distance / 0.02))
			for i = 1, steps do
				mark(Config, cells, { u = from.u + du * i / steps, v = from.v + dv * i / steps })
			end
		else
			mark(Config, cells, p)
		end
		previous = p
	end
	local count = 0
	for _ in cells do
		count += 1
	end
	local tokens = math.min(Config.areaBurst, s.tokens + (now - s.lastAt) * Config.areaPerSecond)
	if count - s.count > tokens then
		return false
	end
	s.tokens, s.cells, s.count, s.seq, s.lastAt, s.lastPoint =
		tokens - (count - s.count), cells, count, sequence, now, previous
	return true
end
function Painting.mask(s: State): string
	local Config = s.config
	local result = {}
	for i = 1, Config.columns * Config.rows do
		result[i] = if s.cells[i] then "1" else "0"
	end
	return table.concat(result)
end
return Painting
