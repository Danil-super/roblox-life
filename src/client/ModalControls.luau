--!strict
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")
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
		AbandonPanel = true,
	}
	local panels: { GuiObject } = {}
	local previous: boolean? = nil
	local previousChat: boolean? = nil
	local stopped = false
	local function restoreChat(): ()
		if previousChat ~= nil then
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, previousChat)
			previousChat = nil
		end
	end
	local function restore(): ()
		restoreChat()
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
		local modal, painting = false, false
		for _, panel in panels do
			if screen.Enabled and panel.Visible then
				modal = true
				painting = painting or panel.Name == "PaintToolbar"
			end
		end
		if painting then
			if previousChat == nil then
				previousChat = StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Chat)
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
			end
		else
			restoreChat()
		end
		if modal then
			screen:SetAttribute("ModalOpen", true)
			if previous == nil then
				previous = GuiService.TouchControlsEnabled
			end
			GuiService.TouchControlsEnabled = false
		else
			restore()
		end
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
