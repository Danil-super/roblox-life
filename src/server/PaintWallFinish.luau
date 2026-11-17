--!strict
local RS = game:GetService("ReplicatedStorage")
local Finish = require(RS.Shared.PaintFinish)
local Config = require(RS.Shared.PaintConfig)
local Contracts = require("./Domain/EconomyConfig")
local Painting = require("./Domain/Painting")
local Profile = require("./Domain/Profile")
local View = {}
export type API = { update: (Painting.State?, Profile.Job?, boolean) -> () }
type Layer = {
	gui: SurfaceGui?,
	cells: { Frame },
	mask: string,
	color: Color3,
	columns: number,
	rows: number,
}
function View.attach(room: Model): API
	local gray = Color3.fromRGB(145, 148, 140)
	local layers: { [BasePart]: Layer } = {}
	local function clear(wall: BasePart, color: Color3?): ()
		local layer = layers[wall]
		if layer and layer.gui then
			layer.gui:Destroy()
		end
		layers[wall] = nil
		wall.Color = color or gray
	end
	local function draw(
		wall: BasePart,
		mask: string,
		color: Color3,
		columns: number,
		rows: number
	): ()
		local _, count = string.gsub(mask, "1", "")
		local painted = count > #mask / 2
		wall.Color = if painted then color else gray
		local layer: Layer = layers[wall]
			or {
				gui = nil,
				cells = {},
				mask = "",
				color = color,
				columns = columns,
				rows = rows,
			}
		if
			layer.mask == mask
			and layer.color == color
			and layer.columns == columns
			and layer.rows == rows
		then
			return
		end
		layers[wall] = layer
		local minority = if painted then "0" else "1"
		local used = 0
		for i = 1, #mask do
			if mask:sub(i, i) == minority then
				if layer.gui == nil then
					local gui = Instance.new("SurfaceGui")
					gui.Name, gui.Adornee, gui.Face = "ConfirmedPaint", wall, Enum.NormalId.Back
					gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
					gui.AlwaysOnTop, gui.ClipsDescendants, gui.Active = false, true, false
					gui.LightInfluence, gui.MaxDistance, gui.ZOffset = 1, 140, 0
					gui.Parent, layer.gui = wall, gui
				end
				used += 1
				local cell: Frame = layer.cells[used] or Instance.new("Frame")
				cell.BorderSizePixel = 0
				layer.cells[used] = cell
				cell.Name, cell.Visible = "Cell" .. i, true
				cell.Position = UDim2.fromScale(
					((i - 1) % columns) / columns,
					math.floor((i - 1) / columns) / rows
				)
				cell.Size = UDim2.fromScale(1 / columns, 1 / rows)
				cell.BackgroundColor3 = if painted then gray else color
				cell.Parent = layer.gui
			end
		end
		if used == 0 and layer.gui then
			layer.gui:Destroy()
			layer.gui, layer.cells = nil, {}
		else
			for i = used + 1, #layer.cells do
				layer.cells[i].Visible = false
			end
		end
		if layer.gui then
			layer.gui.CanvasSize = Vector2.new(columns * 60, rows * 60)
		end
		layer.mask, layer.color, layer.columns, layer.rows = mask, color, columns, rows
	end
	return {
		update = function(work: Painting.State?, job: Profile.Job?, available: boolean): ()
			for wall in layers do
				if room.Parent == nil or wall.Parent ~= room then
					clear(wall, nil)
				end
			end
			if room.Parent == nil then
				return
			end
			local data: Finish.Data? = nil
			local legacy = false
			if available and job and job.status ~= "Abandoned" then
				if job.status == "Completed" then
					local receipt = job.receipt
					if
						receipt
						and receipt.kind == "Reward"
						and receipt.subjectId == job.id
						and receipt.operationId == "job:" .. job.id
					then
						data, legacy = job.finish, job.finish == nil
					end
				elseif work and work.jobId == job.id then
					local masks = table.clone(work.completedMasks)
					if work.phase == "Ready" then
						table.insert(masks, Painting.mask(work))
					elseif work.touchUpBase then
						table.insert(masks, work.touchUpBase)
					end
					data = { columns = work.config.columns, rows = work.config.rows, masks = masks }
				end
			end
			local preview = Finish.preview(data)
			local contract = if job then Contracts.contracts[job.templateId] else nil
			for i, name in { "PaintableWall", "PaintableWallB" } do
				local wall = room:FindFirstChild(name)
				if wall and wall:IsA("BasePart") then
					local id = if contract
						then (if i == 2
							then contract.secondaryColorId or contract.colorId
							else contract.colorId)
						else Config.colorId
					local color = Color3.new(table.unpack(Config.palette[id] or Config.color))
					local mask = if preview then preview.masks[i] else nil
					if mask and preview then
						draw(wall, mask, color, preview.columns, preview.rows)
					else
						clear(wall, if legacy then color else nil)
					end
				end
			end
		end,
	}
end
return table.freeze(View)
