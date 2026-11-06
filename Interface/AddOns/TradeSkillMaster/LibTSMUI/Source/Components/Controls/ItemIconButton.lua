-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local BagTracking = LibTSMUI:From("LibTSMService"):Include("Inventory.BagTracking")
local WarbankTracking = LibTSMUI:From("LibTSMService"):Include("Inventory.WarbankTracking")
local ItemInfo = LibTSMUI:From("LibTSMService"):Include("Item.ItemInfo")
local TradeSkill = LibTSMUI:From("LibTSMWoW"):Include("API.TradeSkill")
local private = {}
local HIGHLIGHT_TEXTURE = 130718



-- ============================================================================
-- Element Definition
-- ============================================================================

local ItemIconButton = ComponentRegistry.Define("ItemIconButton", "Element")
ItemIconButton._STATE_SCHEMA = ItemIconButton._STATE_SCHEMA:Extend("ItemIconButtonState")
	:AddOptionalStringField("itemString")
	:AddNumberField("bagQuantity", 0)
	:Commit()
ItemIconButton:_AddActionScripts("OnClick")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function ItemIconButton:__init()
	local frame = self:_CreateButton()
	self.__super:__init(frame)
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
	frame:TSMSetScript("OnClick", self._childManager:CallbackToProcessAction("ACTION_HANDLE_CLICK"))

	local itemStringPublisher = self._state:Publisher("itemString")
		:Share()

	self._highlight = self:_CreateTexture(frame, "HIGHLIGHT")
	self._highlight:SetAllPoints()
	self._highlight:TSMSetTextureAndCoord(HIGHLIGHT_TEXTURE)
	frame:SetHighlightTexture(self._highlight)

	self._icon = self:_CreateTexture(frame, "ARTWORK")
	self._icon:SetPoint("TOPLEFT", frame, 1, -1)
	self._icon:SetPoint("BOTTOMRIGHT", frame, -1, 1)
	self._icon:TSMSetTextureAndCoord(itemStringPublisher:Map(ItemInfo.GetTexture):IgnoreDuplicates())

	self._quality = self:_CreateFontString()
	self._quality:SetSize(20, 20)
	self._quality:TSMSetFont("BODY_SMALL")
	self._quality:SetPoint("TOPLEFT", -2, 2)
	self._quality:SetJustifyH("LEFT")
	self._quality:TSMSetText(itemStringPublisher:IgnoreNil():Map(private.CraftedQualityToTexture))

	self._quantity = self:_CreateFontString()
	self._quantity:SetHeight(16)
	self._quantity:TSMSetFont("TABLE_TABLE1_OUTLINE")
	self._quantity:SetPoint("BOTTOMLEFT", 1, 1)
	self._quantity:SetPoint("BOTTOMRIGHT", -1, 1)
	self._quantity:SetJustifyH("RIGHT")
	self._quantity:TSMSetText(self._state:Publisher("bagQuantity"):Map(tostring))

	itemStringPublisher:EndShare()

	BagTracking.RegisterQuantityCallback(self._childManager:CallbackToProcessAction("ACTION_HANDLE_BAG_UPDATE"))
	WarbankTracking.RegisterQuantityCallback(self._childManager:CallbackToProcessAction("ACTION_HANDLE_BAG_UPDATE"))
end

---Sets the item displayed by the button.
---@param itemString string The item to display
---@return self
function ItemIconButton:SetItem(itemString)
	self._state.itemString = itemString
	self._state.bagQuantity = BagTracking.GetCraftingMatQuantity(itemString) + WarbankTracking.GetQuantity(itemString)
	self:SetTooltip(itemString)
	return self
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

---@param manager UIManager<ItemIconButtonState>
---@param state ItemIconButtonState
function ItemIconButton.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_HANDLE_CLICK" then
		self:_SendActionScript("OnClick", state.itemString)
	elseif action == "ACTION_HANDLE_BAG_UPDATE" then
		local itemsChanged = ...
		if not state.itemString or not itemsChanged[state.itemString] then
			return
		end
		state.bagQuantity = BagTracking.GetCraftingMatQuantity(state.itemString) + WarbankTracking.GetQuantity(state.itemString)
	else
		error("Unknown action: "..tostring(action))
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.CraftedQualityToTexture(itemString)
	local craftedQuality, useMidnightIcon = ItemInfo.GetCraftedQuality(itemString)
	if not craftedQuality or craftedQuality <= 0 then
		return ""
	end
	local large = useMidnightIcon and true or false
	return TradeSkill.GetCraftedQualityChatIcon(craftedQuality, useMidnightIcon, large)
end
