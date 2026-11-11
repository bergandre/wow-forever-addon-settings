local LibTSMService = select(2, ...).LibTSMService
local CraftingOrders = LibTSMService:InitInternal("Profession.CraftingOrders")
local Database = LibTSMService:From("LibTSMDatabase"):Include("Database")
local Event = LibTSMService:From("LibTSMWoW"):Include("Service.Event")
local TradeSkill = LibTSMService:From("LibTSMWoW"):Include("API.TradeSkill")
local Table = LibTSMService:From("LibTSMUtil"):Include("Lua.Table")
local private = {
	activeScan = nil,
	request = nil,
	restoreSkillLineIds = {},
}
local PROFESSION_ID_EXPANSION_SKILL = {
	[1] = {2872, 2907}, -- Blacksmithing
	[2] = {2880, 2915}, -- Leatherworking
	[3] = {2871, 2906}, -- Alchemy
	[7] = {2883, 2918}, -- Tailoring
	[8] = {2875, 2910}, -- Engineering
	[9] = {2874, 2909}, -- Enchanting
	[12] = {2879, 2914}, -- Jewelcrafting
	[13] = {2878, 2913}, -- Inscription
}



-- ============================================================================
-- Module Loading
-- ============================================================================

CraftingOrders:OnModuleLoad(function()
	private.orderDB = Database.NewSchema("CRAFTING_ORDERS")
		:AddUniqueNumberField("orderId")
		:AddNumberField("profession")
		:AddNumberField("itemId")
		:AddNumberField("spellId")
		:AddNumberField("minQuality")
		:AddNumberField("tipAmount")
		:AddNumberField("consortiumCut")
		:AddNumberField("orderState")
		:AddNumberField("reagentState")
		:AddNumberField("expirationTime")
		:AddBooleanField("isFulfillable")
		:AddIndex("profession")
		:Commit()
	private.rewardDB = Database.NewSchema("CRAFTING_ORDER_REWARDS")
		:AddNumberField("orderId")
		:AddNumberField("profession")
		:AddStringField("itemLink")
		:AddNumberField("currencyType")
		:AddNumberField("count")
		:AddIndex("orderId")
		:AddIndex("profession")
		:Commit()
	if LibTSMService.IsRetail() then
		private.request = {
			orderType = Enum.CraftingOrderType.Npc,
			searchFavorites = false,
			initialNonPublicSearch = false,
			primarySort = {
				sortType = Enum.CraftingOrderSortType.ItemName,
				reversed = false,
			},
			secondarySort = {
				sortType = Enum.CraftingOrderSortType.MaxTip,
				reversed = false,
			},
			forCrafter = true,
			offset = 0,
			callback = C_FunctionContainers.CreateCallback(function() end),
		}
		Event.Register("TRADE_SKILL_DATA_SOURCE_CHANGED", private.ScanCraftingOrders)
		Event.Register("TRADE_SKILL_CLOSE", private.OnTradeSkillClose)
		Event.Register("CRAFTINGORDERS_CAN_REQUEST", private.OnCanRequest)
		Event.Register("CRAFTINGORDERS_UPDATE_ORDER_COUNT", private.OnUpdateOrderCount)
	end
end)



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.OnTradeSkillClose()
	local scan = private.activeScan
	if scan then
		private.StopScan(scan)
	end
end

function private.OnCanRequest()
	local scan = private.activeScan
	if scan and (not scan.awaitingResponse or scan.pendingOrders) then
		private.RequestNextSkillLine(scan)
	end
end

function private.OnUpdateOrderCount(_, orderType)
	local scan = private.activeScan
	if not scan or not scan.awaitingResponse or orderType ~= Enum.CraftingOrderType.Npc then
		return
	end
	scan.pendingOrders = C_CraftingOrders.GetCrafterOrders()
end

function private.CommitPendingOrders(scan)
	local orders = scan.pendingOrders
	if not orders then
		return
	end
	scan.pendingOrders = nil
	scan.awaitingResponse = false
	private.orderDB:BulkInsertStart()
	private.rewardDB:BulkInsertStart()
	for _, order in ipairs(orders) do
		local recipeInfo = C_TradeSkillUI.GetRecipeInfo(order.spellID)
		if recipeInfo and recipeInfo.learned and not private.orderDB:HasUniqueRow("orderId", order.orderID) then
			private.orderDB:BulkInsertNewRow(order.orderID, scan.profession, order.itemID, order.spellID, order.minQuality, order.tipAmount, order.consortiumCut, order.orderState, order.reagentState, order.expirationTime, order.isFulfillable)
			for _, reward in ipairs(order.npcOrderRewards) do
				private.rewardDB:BulkInsertNewRow(order.orderID, scan.profession, reward.itemLink or "", reward.currencyType or -1, reward.count)
			end
		end
	end
	private.rewardDB:BulkInsertEnd()
	private.orderDB:BulkInsertEnd()
end

function private.ScanCraftingOrders()
	local profession = nil
	if TradeSkill.GetType() == TradeSkill.TYPE.PLAYER then
		profession = C_TradeSkillUI.GetChildProfessionInfo().profession
	end
	local activeScan = private.activeScan
	if activeScan then
		private.StopScan(activeScan)
	end
	if not profession then
		return
	end
	local restoreSkillLineId = private.restoreSkillLineIds[profession]
	if restoreSkillLineId then
		private.restoreSkillLineIds[profession] = nil
		private.SetSkillLine(restoreSkillLineId)
	end
	local expansionSkillLineIds = PROFESSION_ID_EXPANSION_SKILL[profession]
	if not expansionSkillLineIds or not C_TradeSkillUI.IsNearProfessionSpellFocus(profession) then
		return
	end
	private.orderDB:NewAutoReleaseQuery():Equal("profession", profession):Delete()
	private.rewardDB:NewAutoReleaseQuery():Equal("profession", profession):Delete()
	local learnedSkillLineIds = {}
	for _, childInfo in ipairs(C_TradeSkillUI.GetChildProfessionInfos()) do
		if childInfo.skillLevel > 0 then
			learnedSkillLineIds[childInfo.professionID] = true
		end
	end
	local skillLineIds = {}
	for _, skillLineId in ipairs(expansionSkillLineIds) do
		if learnedSkillLineIds[skillLineId] then
			tinsert(skillLineIds, skillLineId)
		end
	end
	local selectedSkillLineId = C_TradeSkillUI.GetChildProfessionInfo().professionID
	if Table.RemoveByValue(skillLineIds, selectedSkillLineId) > 0 then
		tinsert(skillLineIds, selectedSkillLineId)
	end
	private.activeScan = {
		profession = profession,
		selectedSkillLineId = selectedSkillLineId,
		requestedSkillLineId = nil,
		skillLineIds = skillLineIds,
		awaitingResponse = false,
	}
	if ProfessionsFrame:GetTab() ~= ProfessionsFrame.craftingOrdersTabID then
		private.RequestNextSkillLine(private.activeScan)
	end
end

function private.RequestNextSkillLine(scan)
	private.CommitPendingOrders(scan)
	local skillLineId = tremove(scan.skillLineIds, 1)
	if not skillLineId then
		private.activeScan = nil
		private.SetSkillLine(scan.selectedSkillLineId)
		return
	end
	scan.requestedSkillLineId = skillLineId
	private.SetSkillLine(skillLineId)
	private.request.profession = scan.profession
	scan.awaitingResponse = true
	C_CraftingOrders.RequestCrafterOrders(private.request)
end

function private.StopScan(scan)
	private.activeScan = nil
	if scan.requestedSkillLineId and scan.requestedSkillLineId ~= scan.selectedSkillLineId then
		private.restoreSkillLineIds[scan.profession] = scan.selectedSkillLineId
	end
end

function private.SetSkillLine(skillLineId)
	if C_TradeSkillUI.GetChildProfessionInfo().professionID == skillLineId then
		return
	end
	C_TradeSkillUI.SetProfessionChildSkillLineID(skillLineId)
	ProfessionsFrame:SetProfessionInfo(Professions.GetProfessionInfo(), false)
end
