--!strict
local GuiService = game:GetService("GuiService")
local Controller = {}
function Controller.start(screen: ScreenGui): ()
	local names: { [string]: boolean } = {
		HomePanel = true,
		JobsPanel = true,
		MapPanel = true,
		ResultsPanel = true,
		ShopPanel = true,
		InventoryPanel = true,
		PaintToolbar = true,
		BuildToolbar = true,
		ProfilePanel = true,
		RoomPlanPanel = true,
		ClientPanel = true,
		GuidePanel = true,
	}
	local panels: { GuiObject } = {}
	local previous: boolean? = nil
	local stopped = false
	local function restore(): ()
		screen:SetAttribute("ModalOpen", false)
		if previous ~= nil then
			GuiService.TouchControlsEnabled = previous
			previous = nil
		end
	end
	local function update(): ()
		if stopped then
			return
		end
		for _, panel in panels do
			if screen.Enabled and panel.Visible then
				screen:SetAttribute("ModalOpen", true)
				if previous == nil then
					previous = GuiService.TouchControlsEnabled
				end
				GuiService.TouchControlsEnabled = false
				return
			end
		end
		restore()
	end
	for _, panel in screen:GetChildren() do
		if names[panel.Name] and panel:IsA("GuiObject") then
			table.insert(panels, panel)
			panel:GetPropertyChangedSignal("Visible"):Connect(update)
		end
	end
	screen:GetPropertyChangedSignal("Enabled"):Connect(update)
	screen.Destroying:Once(function()
		stopped = true
		restore()
	end)
	update()
end
return Controller
