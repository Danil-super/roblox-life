--!strict
local RS = game:GetService("ReplicatedStorage")
local Tweens = game:GetService("TweenService")
local Field = require(RS.Shared.PaintSurface)
local Config = require(RS.Shared.PaintConfig)
export type API = {
	update: (string, boolean?) -> (),
	predict: (number, number, number, number) -> (),
	step: (number) -> (),
	destroy: () -> (),
}
local Surface = {}
function Surface.new(gui: SurfaceGui, colour: Color3, light: boolean?, reducedMotion: boolean?): API
	local columns, rows = Field.dimensions(light)
	local ink, predictions = Instance.new("Frame"), Instance.new("Frame")
	for _, layer in { ink, predictions } do
		layer.Size, layer.BackgroundTransparency, layer.Parent = UDim2.fromScale(1, 1), 1, gui
	end
	ink.Name, ink.ZIndex, predictions.Name, predictions.ZIndex = "Ink", 1, "Predictions", 2
	local function pixel(parent: Frame, name: string): Frame
		local frame = Instance.new("Frame")
		frame.Name, frame.BackgroundColor3, frame.BorderSizePixel = name, colour, 0
		frame.BackgroundTransparency, frame.Parent = 1, parent
		return frame
	end
	local frames: { Frame } = {}
	for row = 0, rows - 1 do
		for col = 0, columns - 1 do
			local frame = pixel(ink, "Pixel" .. (#frames + 1))
			frame.Position, frame.Size =
				UDim2.fromScale(col / columns, row / rows), UDim2.fromScale(1 / columns, 1 / rows)
			table.insert(frames, frame)
		end
	end
	local marks: { { frame: Frame, expires: number } } = {}
	for i = 1, if light then Field.lightPredictionLimit else Field.predictionLimit do
		local frame = pixel(predictions, "Mark" .. i)
		frame.AnchorPoint, frame.Visible = Vector2.new(0.5, 0.5), false
		local corner = Instance.new("UICorner")
		corner.CornerRadius, corner.Parent = UDim.new(0.5, 0), frame
		table.insert(marks, { frame = frame, expires = 0 })
	end
	local tweenInfo =
		TweenInfo.new(Field.fadeSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local pending: { [number]: Tween } = {}
	local alphas: { number } = {}
	local lastMask: string? = nil
	local nextMark, closed = 0, false
	local function cancel(index: number): ()
		local tween = pending[index]
		if tween then
			tween:Cancel()
			tween:Destroy()
			pending[index] = nil
		end
	end
	return {
		update = function(mask: string, instant: boolean?): ()
			if closed or mask == lastMask then
				return
			end
			lastMask = mask
			for i, alpha in Field.build(mask, light) do
				if alphas[i] ~= alpha then
					cancel(i)
					alphas[i] = alpha
					if instant or light or reducedMotion then
						frames[i].BackgroundTransparency = alpha
					else
						local tween =
							Tweens:Create(frames[i], tweenInfo, { BackgroundTransparency = alpha })
						pending[i] = tween
						tween:Play()
					end
				end
			end
		end,
		predict = function(u: number, v: number, scale: number, now: number): ()
			if
				closed
				or not (
					u >= 0
					and u <= 1
					and v >= 0
					and v <= 1
					and scale >= 0.5
					and scale <= 2
					and now >= 0
					and now < math.huge
				)
			then
				return
			end
			nextMark = nextMark % #marks + 1
			local mark = marks[nextMark]
			mark.expires = now + 0.35
			mark.frame.Position, mark.frame.Size =
				UDim2.fromScale(u, v),
				UDim2.fromScale(1.3 * scale / Config.columns, 1.3 * scale / Config.rows)
			mark.frame.BackgroundTransparency, mark.frame.Visible = 0.15, true
		end,
		step = function(now: number): ()
			if closed then
				return
			end
			for _, mark in marks do
				if mark.frame.Visible and now >= mark.expires then
					mark.frame.Visible = false
				end
			end
		end,
		destroy = function(): ()
			if closed then
				return
			end
			closed = true
			for index in pending do
				cancel(index)
			end
			ink:Destroy()
			predictions:Destroy()
		end,
	}
end
return Surface
