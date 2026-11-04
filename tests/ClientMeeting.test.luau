--!strict
local Meeting = require("../src/server/Domain/ClientMeeting")
local Dialogue = require("../src/shared/ClientDialogue")
local function describe(key: string, phase: string): Dialogue.Dialogue
	local value = Dialogue.describe(key, phase)
	assert(value, "Missing conversation")
	return value
end
local facts: Meeting.Facts = {
	ownerId = 1,
	actorId = 1,
	available = true,
	alive = true,
	distance = 4,
	visible = true,
	phase = "Inspect",
}
assert(Meeting.allowed(facts), "Valid meeting rejected")
for _, phase in { "Inspect", "Prepare", "ChooseMaterial", "Painting", "Ready", "Completed" } do
	facts.phase = phase
	assert(Meeting.allowed(facts), "Known phase rejected")
	local d = Dialogue.describe("residentNina", phase)
	assert(d and d.speakerKey == "residentNina" and #d.lineKey > 0, "Phase dialogue missing")
end
assert(describe("residentNina", "Ready").action == "submit", "Acceptance bypassed existing submit")
assert(describe("residentNina", "Inspect").action == "inspect", "Meeting lost inspection")
assert(describe("residentNina", "Completed").action == nil, "Completed talk could pay again")
for _, phase in { "Offer", "Missing" } do
	facts.phase = phase
	assert(not Meeting.allowed(facts), "Inactive meeting allowed")
	assert(Dialogue.describe("residentNina", phase) == nil, "Inactive conversation exists")
end
facts.phase = "Inspect"
for _, distance in { 0 / 0, math.huge, -1, 8.01 } do
	facts.distance = distance
	assert(not Meeting.allowed(facts), "Invalid/far distance allowed")
end
facts.distance = 8
assert(Meeting.allowed(facts), "Exact distance limit rejected")
facts.ownerId = 2
assert(not Meeting.allowed(facts), "Foreign resident interacted")
facts.ownerId = 1
facts.available = false
assert(not Meeting.allowed(facts), "Unavailable profile interacted")
facts.available = true
facts.alive = false
assert(not Meeting.allowed(facts), "Dead player interacted")
facts.alive = true
facts.visible = false
assert(not Meeting.allowed(facts), "Wall did not block conversation")
local a = describe("residentMila", "Prepare")
a.lineKey = "tampered"
assert(describe("residentMila", "Prepare").lineKey ~= "tampered", "Dialogue state crossed players")
print(
	"ClientMeeting: phases, existing actions, ownership, distance/NaN, profile, life, LOS and isolation passed"
)
