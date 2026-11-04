--!strict
local Labels = require("../src/shared/StreetLabels")
local Strings = require("../src/shared/Strings")
assert(Labels.key("streetHomeDoor", 1, 1) == "streetMyHome", "Own home not identified")
assert(Labels.key("streetHomeDoor", 1, 2) == "streetPrivateHome", "Foreign home called mine")
assert(Labels.key("streetHomeDoor", nil, 1) == "streetPrivateHome", "Missing owner invented access")
assert(Labels.key("streetClientDoor", 1, 1) == "streetMyClient", "Own client not identified")
assert(Labels.key("streetClientDoor", 1, 2) == "streetClientDoor", "Foreign client called mine")
assert(Labels.key("streetShop", nil, 1) == "streetShop", "Public shop changed")
for _, key in
	{
		"streetHomes",
		"streetClients",
		"streetShop",
		"streetMyHome",
		"streetPrivateHome",
		"streetMyClient",
		"streetClientDoor",
	}
do
	for _, lang in { "en", "ru" } do
		assert(Strings.text(lang, key) ~= key, "Missing sign translation: " .. key)
	end
end
print("StreetLabels: ownership, public labels and EN/RU passed")
