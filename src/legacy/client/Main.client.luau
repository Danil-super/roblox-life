--!strict
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local stats = player:WaitForChild("leaderstats")
local coins = stats:WaitForChild("Coins")
assert(coins:IsA("IntValue"), "leaderstats.Coins must be an IntValue")

local screen = Instance.new("ScreenGui")
screen.Name = "LifeHUD"
screen.ResetOnSpawn = false
screen.Parent = playerGui

local label = Instance.new("TextLabel")
label.Name = "CoinsAndInstructions"
label.Position = UDim2.fromOffset(16, 16)
label.Size = UDim2.new(1, -32, 0, 110)
label.BackgroundColor3 = Color3.fromRGB(27, 40, 49)
label.BackgroundTransparency = 0.15
label.TextColor3 = Color3.fromRGB(240, 247, 243)
label.Font = Enum.Font.Gotham
label.TextSize = 18
label.TextWrapped = true
label.Parent = screen

local function render(): ()
	local instructions = "Подойдите к раковине и нажмите E / кнопку действия.\n"
		.. "Мойка: 2 сек. рядом с раковиной. После попытки: пауза 3 сек."
	if player:GetAttribute("ChoreBusy") == true then
		instructions =
			"Моете посуду… Оставайтесь рядом с раковиной."
	end
	label.Text = string.format("Монеты: %d\n%s", coins.Value, instructions)
end

coins:GetPropertyChangedSignal("Value"):Connect(render)
player:GetAttributeChangedSignal("ChoreBusy"):Connect(render)
render()
