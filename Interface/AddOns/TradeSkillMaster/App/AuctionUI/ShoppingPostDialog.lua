-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local ItemString = App:From("LibTSMTypes"):Include("Item.ItemString")
local BagTracking = App:From("LibTSMService"):Include("Inventory.BagTracking")
local UIElements = App:From("LibTSMUI"):Include("UIElements")

---@class ShoppingPostDialogAuction
---@correlated itemString, bid, buyout, stackSize, undercut, duration
---@field itemString string?
---@field bid number?
---@field buyout number?
---@field stackSize number?
---@field undercut number?
---@field duration number?



-- ============================================================================
-- Element Definition
-- ============================================================================

local ShoppingPostDialog = UIElements.Define("ShoppingPostDialog", "BaseFrame")
ShoppingPostDialog._STATE_SCHEMA = ShoppingPostDialog._STATE_SCHEMA:Extend("ShoppingPostDialogState")
	:AddDeferredUIElementField("view", "ViewContainer")
	:AddOptionalUIElementField("postingFrame", "ShoppingPostDialogPriceView")
	:Commit()
ShoppingPostDialog:_AddActionScripts("OnPostClicked")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function ShoppingPostDialog:__init()
	self.__super:__init()
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
	self._auction = { ---@type ShoppingPostDialogAuction
		itemString = nil,
		bid = nil,
		buyout = nil,
		stackSize = nil,
		undercut = nil,
		duration = nil,
	}
end

function ShoppingPostDialog:Acquire()
	self.__super:Acquire()
	self
		:SetLayout("VERTICAL")
		:SetPadding(12)
		:SetRoundedBackgroundColor("container/low")
		:SetBorderColor("outline/variant")
		:SetMouseEnabled(true)
		:AddChild(UIElements.New("ViewContainer", "view")
			:SetManager(self._childManager)
			:SetNavCallback(self:__closure("_GetViewContentFrame"))
			:AddPath("posting", true)
			:AddPath("selection")
			:BindElement(self._state, "view")
		)
end

function ShoppingPostDialog:Release()
	wipe(self._auction)
	self.__super:Release()
end

---Sets the auction being posted.
---@param itemString string The item string
---@param bid number The per-item bid
---@param buyout number The per-item buyout
---@param stackSize number The stack size being posted
---@param undercut number The amount to undercut by
---@param duration number The auction duration
---@return self
function ShoppingPostDialog:SetAuction(itemString, bid, buyout, stackSize, undercut, duration)
	self._auction.itemString = itemString
	self._auction.bid = bid
	self._auction.buyout = buyout
	self._auction.stackSize = stackSize
	self._auction.undercut = undercut
	self._auction.duration = duration
	assert(self._state.postingFrame)
	self._state.postingFrame:SetAuction(self._auction.itemString, self._auction.duration, self._auction.bid, self._auction.buyout, self._auction.stackSize, self._auction.undercut)
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function ShoppingPostDialog.__private:_GetViewContentFrame(_, path)
	if path == "posting" then
		local frame = UIElements.New("ShoppingPostDialogPriceView", "posting")
			:SetAction("OnItemEditClicked", "ACTION_ITEM_EDIT_CLICKED")
			:SetAction("OnPostClicked", "ACTION_POST_CLICKED")
			:BindElement(self._state, "postingFrame")
		if self._auction.itemString then
			frame:SetAuction(self._auction.itemString, self._auction.duration, self._auction.bid, self._auction.buyout, self._auction.stackSize, self._auction.undercut)
		end
		return frame
	elseif path == "selection" then
		assert(self._auction.itemString)
		return UIElements.New("BaseFrame", "selection")
			:SetLayout("VERTICAL")
			:AddChild(UIElements.New("BaseFrame", "header")
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:SetMargin(0, 0, -4, 10)
				:AddChild(UIElements.New("Spacer", "spacer")
					:SetWidth(20)
				)
				:AddChild(UIElements.New("Text", "title")
					:SetFont("BODY_BODY1_EXTRABOLD")
					:SetJustifyH("CENTER")
					:SetText(L["Item Selection"])
				)
				:AddChild(UIElements.New("BaseButton", "closeBtn")
					:SetMargin(0, -4, 0, 0)
					:SetBackgroundAndSize("iconPack.24x24/Close/Default")
					:SetAction("OnClick", "ACTION_CLOSE_DIALOG")
				)
			)
			:AddChild(UIElements.New("SimpleItemList", "items")
				:SetQuery(BagTracking.CreateQueryBagsItemAuctionable(ItemString.GetBaseFast(self._auction.itemString)))
				:SetAction("OnItemClick", "ACTION_ITEM_CLICKED")
			)
			:AddChild(UIElements.New("MediumTertiaryActionButton", "backBtn")
				:SetMargin(0, 0, 9, 0)
				:SetText(BACK)
				:SetAction("OnClick", "ACTION_ITEM_BACK")
			)
	else
		error("Unexpected path: "..tostring(path))
	end
end

---@param manager UIManager<ShoppingPostDialogState>
---@param state ShoppingPostDialogState
function ShoppingPostDialog.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_CLOSE_DIALOG" then
		self:GetBaseElement():HideDialog()
	elseif action == "ACTION_ITEM_EDIT_CLICKED" then
		state.view:SetPath("selection", true)
	elseif action == "ACTION_POST_CLICKED" then
		self:_SendActionScript("OnPostClicked", ...)
		manager:ProcessAction("ACTION_CLOSE_DIALOG")
	elseif action == "ACTION_ITEM_CLICKED" then
		self._auction.itemString = ...
		manager:ProcessAction("ACTION_ITEM_BACK")
	elseif action == "ACTION_ITEM_BACK" then
		state.view:SetPath("posting", true)
	else
		error("Unknown action: "..tostring(action))
	end
end
