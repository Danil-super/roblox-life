--!strict
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Strings = require(RS.Shared.Strings)
local Labels = require(RS.Shared.StreetLabels)
local Controller = {}
function Controller.start(screen: ScreenGui, language: () -> string): { render: () -> () }
	local entries: { [TextLabel]: { RBXScriptConnection } } = {}
	local function update(label: TextLabel): ()
		local key, owner = label:GetAttribute("SignKey"), label:GetAttribute("SignOwnerId")
		if type(key) == "string" then
			label.Text = Strings.text(
				language(),
				Labels.key(
					key,
					if type(owner) == "number" then owner else nil,
					Players.LocalPlayer.UserId
				)
			)
		end
	end
	local function track(instance: Instance): ()
		if not instance:IsA("TextLabel") or instance.Name ~= "WorldLabel" or entries[instance] then
			return
		end
		entries[instance] = {
			instance:GetAttributeChangedSignal("SignKey"):Connect(function()
				update(instance)
			end),
			instance:GetAttributeChangedSignal("SignOwnerId"):Connect(function()
				update(instance)
			end),
			instance.Destroying:Once(function()
				local bound = entries[instance]
				entries[instance] = nil
				if bound then
					for _, c in bound do
						c:Disconnect()
					end
				end
			end),
		}
		update(instance)
	end
	local connection = workspace.DescendantAdded:Connect(track)
	for _, instance in workspace:GetDescendants() do
		track(instance)
	end
	screen.Destroying:Once(function()
		connection:Disconnect()
		for _, bound in entries do
			for _, c in bound do
				c:Disconnect()
			end
		end
		table.clear(entries)
	end)
	return {
		render = function(): ()
			for label in entries do
				update(label)
			end
		end,
	}
end
return Controller
