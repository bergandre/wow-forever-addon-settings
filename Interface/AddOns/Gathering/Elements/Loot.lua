local Name, AddOn = ...
local Gathering = AddOn.Gathering
local L = AddOn.L

local GetItemInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
local GetItemInfoInstant = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant

local ValidMessages = {}

for _, Key in ipairs({"LOOT_ITEM_SELF", "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF", "LOOT_ITEM_PUSHED_SELF_MULTIPLE"}) do
	local Template = _G[Key]

	if Template then
		local Prefix = Template:match("^(.-)%%")

		if Prefix then
			ValidMessages[Prefix] = true
		end
	end
end

function Gathering:ProcessLootItem(ID, Name, Quantity)
	local ItemName, _, _, _, _, _, SubType, _, _, _, _, ClassID, SubClassID, BindType = GetItemInfo(ID)

	if (not ClassID or not SubClassID or not SubType) and GetItemInfoInstant and not self.Settings["ignore-bop"] then
		local _, _, InstantSubType, _, _, InstantClass, InstantSubclass = GetItemInfoInstant(ID)
		SubType = SubType or InstantSubType
		ClassID = ClassID or InstantClass
		SubClassID = SubClassID or InstantSubclass
	end

	if (not ClassID or not SubClassID or not SubType) then
		if Item and Item.CreateFromItemID then
			self.PendingLootItems = self.PendingLootItems or {}

			if self.PendingLootItems[ID] then
				self.PendingLootItems[ID].Quantity = self.PendingLootItems[ID].Quantity + Quantity
			else
				self.PendingLootItems[ID] = {Name = Name, Quantity = Quantity}

				Item:CreateFromItemID(ID):ContinueOnItemLoad(function()
					local Pending = self.PendingLootItems and self.PendingLootItems[ID]

					if Pending then
						self.PendingLootItems[ID] = nil
						self:ProcessLootItem(ID, Pending.Name, Pending.Quantity)
					end
				end)
			end
		end

		return
	end

	if self.Ignored[ID] or self.Ignored[ItemName or Name] or not self.TrackedItemTypes[ClassID] or not self.TrackedItemTypes[ClassID][SubClassID] then
		return
	end

	if BindType and BindType ~= 0 and self.Settings["ignore-bop"] then
		return
	end

	local Now = GetTime()

	if not self.Gathered[SubType] then
		self.Gathered[SubType] = {}
	end

	if not self.Gathered[SubType][ID] then
		self.Gathered[SubType][ID] = {Initial = Now}
	end

	local Info = self.Gathered[SubType][ID]

	Info.Collected = (Info.Collected or 0) + Quantity
	Info.Last = Now

	self.TotalGathered = self.TotalGathered + Quantity
	self.TooltipPriceCache = nil

	if self.Settings.DisplayMode == "TOTAL" then
		self.Text:SetFormattedText(L["Total: %s"], self.TotalGathered)
	end

	if not self:GetScript("OnUpdate") then
		self:StartTimer()
	end

	self:AddStat("total", Quantity)
	self:UpdateItemsStat()

	if self.MouseIsOver then
		self.Tooltip:ClearLines()
		self:OnEnter()
	end
end

function Gathering:CHAT_MSG_LOOT(msg)
	if not msg then
		return
	end

	if (self.Settings.IgnoreMailItems and InboxFrame and InboxFrame:IsVisible()) or (GuildBankFrame and GuildBankFrame:IsVisible()) then
		return
	end

	local LinkStart = msg:find("|Hitem:", 1, true)

	if not LinkStart then
		return
	end

	local Prefix = msg:sub(1, LinkStart - 1):gsub("|c[^|]*$", "")

	if not ValidMessages[Prefix] then
		return
	end

	local ID, Name, Suffix = msg:match("|Hitem:(%d+)[^|]*|h%[(.-)%]|h(.*)", LinkStart)

	if not ID then
		ID, Name, Suffix = msg:match("|Hitem:(%d+)[^|]*|h(.-)|h(.*)", LinkStart)
	end

	ID = tonumber(ID)

	if not ID then
		return
	end

	local Quantity = tonumber(Suffix and Suffix:gsub("^|r", ""):match("(%d+)")) or 1

	self:ProcessLootItem(ID, Name, Quantity)
end

Gathering:RegisterEvent("CHAT_MSG_LOOT")