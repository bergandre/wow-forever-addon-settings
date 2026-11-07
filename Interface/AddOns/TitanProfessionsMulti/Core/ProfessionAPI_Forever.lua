-- Forever uses the modern API with Classic professions. Loaded only by Camelot.
local _, L = ...
local API = L.ProfessionAPI
L.IsForever = true

local CreateSnapshot = API.CreateSnapshot
function API:CreateSnapshot()
	local snapshot = CreateSnapshot(self)
	-- Camelot returns First Aid in the third slot, where Retail has Archaeology.
	snapshot.bySlot[6] = snapshot.bySlot[3]
	snapshot.bySlot[3] = nil
	return snapshot
end

function API:GetMaximumCap()
	return 300
end
