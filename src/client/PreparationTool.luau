--!strict
local Tweens = game:GetService("TweenService")
local Tool = {}
export type API = { freeze: () -> (), destroy: () -> () }
function Tool.new(parent: Instance, patch: BasePart, animate: boolean): API
	local model = Instance.new("Model")
	model.Name, model.Parent = "LocalScraper", parent
	local tweens: { Tween } = {}
	local disposed = false
	local frame = patch.CFrame * CFrame.new(0, math.min(1.25, patch.Size.Y / 2 - 0.3), 0.16)
	local steel, grip = Color3.fromRGB(188, 202, 205), Color3.fromRGB(40, 78, 76)
	local function part(name: string, size: Vector3, color: Color3, offset: CFrame): ()
		local p = Instance.new("Part")
		p.Name, p.Size, p.Color = name, size, color
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow =
			true, false, false, false, false
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Material = if name == "Blade" or name == "Neck"
			then Enum.Material.Metal
			else Enum.Material.SmoothPlastic
		p.CFrame, p.Parent = frame * offset, model
		if animate then
			local tween = Tweens:Create(
				p,
				TweenInfo.new(0.13, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 2, true),
				{
					CFrame = frame * CFrame.new(0, -0.6, 0.02) * offset,
				}
			)
			table.insert(tweens, tween)
			tween:Play()
		end
	end
	part("Blade", Vector3.new(0.7, 0.5, 0.07), steel, CFrame.identity)
	part("Neck", Vector3.new(0.16, 0.23, 0.09), steel, CFrame.new(0, -0.34, 0.03))
	part("Grip", Vector3.new(0.25, 0.52, 0.18), grip, CFrame.new(0, -0.69, 0.08))
	part(
		"GripBand",
		Vector3.new(0.26, 0.07, 0.19),
		Color3.fromRGB(241, 183, 79),
		CFrame.new(0, -0.47, 0.08)
	)
	part("EndCap", Vector3.new(0.26, 0.08, 0.19), grip, CFrame.new(0, -0.95, 0.08))
	local function freeze(): ()
		for _, tween in tweens do
			tween:Cancel()
		end
		table.clear(tweens)
	end
	return {
		freeze = freeze,
		destroy = function(): ()
			if disposed then
				return
			end
			disposed = true
			freeze()
			model:Destroy()
		end,
	}
end
return table.freeze(Tool)
