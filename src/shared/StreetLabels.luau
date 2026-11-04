--!strict
local Labels = {}
function Labels.key(key: string, owner: number?, viewer: number): string
	if key == "streetHomeDoor" then
		return if owner == viewer then "streetMyHome" else "streetPrivateHome"
	end
	if key == "streetClientDoor" and owner == viewer then
		return "streetMyClient"
	end
	return key
end
return table.freeze(Labels)
