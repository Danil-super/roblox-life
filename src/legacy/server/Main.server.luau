--!strict
local ChoreService = require("./ChoreService")
local apartment = workspace:WaitForChild("Apartment")
local sink = apartment:WaitForChild("Sink")
assert(sink:IsA("BasePart"), "Apartment.Sink must be a BasePart")
local prompt = sink:WaitForChild("WashPrompt")
assert(prompt:IsA("ProximityPrompt"), "Sink.WashPrompt must be a ProximityPrompt")

ChoreService.start(sink, prompt)
print("[RobloxLife] Server ready: wash dishes for 10 coins")
