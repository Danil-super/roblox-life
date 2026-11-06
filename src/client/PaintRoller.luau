--!strict
local Motion = require(game:GetService("ReplicatedStorage").Shared.PaintRollerMotion)
local Roller = {}
export type API = {
	sound: Sound,
	update: (BasePart, number, number, boolean, boolean) -> (),
	hide: () -> (),
	destroy: () -> (),
}
type Piece = { part: Part, offset: CFrame, rolling: boolean }
function Roller.new(parent: Instance, color: Color3, scale: number): API
	local model = Instance.new("Model")
	model.Name, model.Parent = "LocalRoller", parent
	local pieces: { Piece } = {}
	local disposed = false
	local motion = Motion.new()
	local width = 1.1 * scale
	local steel, grip = Color3.fromRGB(180, 193, 196), Color3.fromRGB(40, 78, 76)
	local function part(
		name: string,
		size: Vector3,
		tint: Color3,
		offset: CFrame,
		rolling: boolean,
		cylinder: boolean
	): ()
		local p = Instance.new("Part")
		p.Name, p.Size, p.Color = name, size, tint
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow =
			true, false, false, false, false
		p.Transparency = 1
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Material = if name == "Foam" or name == "Seam"
			then Enum.Material.Fabric
			elseif name:find("Wire") or name == "Axle" or name == "Neck" then Enum.Material.Metal
			else Enum.Material.SmoothPlastic
		if cylinder then
			p.Shape = Enum.PartType.Cylinder
		end
		p.Parent = model
		table.insert(pieces, { part = p, offset = offset, rolling = rolling })
	end
	part("Foam", Vector3.new(width, 0.38, 0.38), color, CFrame.identity, true, true)
	part(
		"Seam",
		Vector3.new(width - 0.08, 0.025, 0.05),
		Color3.fromRGB(225, 229, 211),
		CFrame.new(0, 0.186, 0),
		true,
		false
	)
	for _, side in { -1, 1 } do
		part(
			if side < 0 then "CapLeft" else "CapRight",
			Vector3.new(0.06, 0.25, 0.25),
			grip,
			CFrame.new(side * (width / 2 + 0.025), 0, 0),
			true,
			true
		)
	end
	part("Axle", Vector3.new(width + 0.23, 0.07, 0.07), steel, CFrame.identity, false, true)
	part(
		"WireArm",
		Vector3.new(0.07, 0.64, 0.07),
		steel,
		CFrame.new(-width / 2 - 0.11, -0.29, 0),
		false,
		false
	)
	part(
		"WireBridge",
		Vector3.new(width / 2 + 0.14, 0.07, 0.07),
		steel,
		CFrame.new(-width / 4 - 0.05, -0.61, 0),
		false,
		false
	)
	part(
		"Neck",
		Vector3.new(0.08, 0.42, 0.08),
		steel,
		CFrame.new(0, -0.8, 0.08) * CFrame.Angles(-0.4, 0, 0),
		false,
		false
	)
	local handleFrame = CFrame.new(0, -1.27, 0.27) * CFrame.Angles(-0.4, 0, 0)
	part("Grip", Vector3.new(0.23, 0.65, 0.23), grip, handleFrame, false, false)
	part(
		"GripBand",
		Vector3.new(0.24, 0.075, 0.24),
		Color3.fromRGB(241, 183, 79),
		handleFrame * CFrame.new(0, 0.21, 0),
		false,
		false
	)
	part(
		"EndCap",
		Vector3.new(0.24, 0.08, 0.24),
		grip,
		handleFrame * CFrame.new(0, -0.32, 0),
		false,
		false
	)
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxasset://sounds/action_footsteps_plastic.mp3"
	sound.Volume, sound.PlaybackSpeed, sound.Looped, sound.Playing = 0.12, 0.65, true, false
	sound.Parent = model
	local function hide(): ()
		if disposed then
			return
		end
		Motion.reset(motion)
		sound.Playing = false
		for _, piece in pieces do
			piece.part.Transparency = 1
		end
	end
	return {
		sound = sound,
		update = function(
			target: BasePart,
			u: number,
			v: number,
			pressed: boolean,
			animate: boolean
		): ()
			if disposed then
				return
			end
			if not target.Parent or u ~= u or v ~= v or u < 0 or u > 1 or v < 0 or v > 1 then
				hide()
				return
			end
			local x, y = (u - 0.5) * target.Size.X, (0.5 - v) * target.Size.Y
			Motion.step(motion, x, y, pressed, animate)
			local frame = target.CFrame
				* CFrame.new(x, y, target.Size.Z / 2 + 0.21)
				* CFrame.Angles(0, 0, motion.tilt)
			local spin = CFrame.Angles(motion.spin, 0, 0)
			for _, piece in pieces do
				piece.part.CFrame = frame
					* (if piece.rolling then spin * piece.offset else piece.offset)
				piece.part.Transparency = if pressed then 0 else 0.38
			end
		end,
		hide = hide,
		destroy = function(): ()
			if disposed then
				return
			end
			disposed = true
			model:Destroy()
			table.clear(pieces)
		end,
	}
end
return table.freeze(Roller)
