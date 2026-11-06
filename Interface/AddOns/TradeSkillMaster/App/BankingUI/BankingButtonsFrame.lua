-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local EnumTypes = App:From("LibTSMTypes"):Include("EnumTypes")
local Banking = App:From("LibTSMService"):Include("Banking")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local PATHS = {
	"Warehousing",
	"Auctioning",
	"Mailing",
}



-- ============================================================================
-- Element Definition
-- ============================================================================

local BankingButtonsFrame = UIElements.Define("BankingButtonsFrame", "ViewContainer")
BankingButtonsFrame._STATE_SCHEMA = BankingButtonsFrame._STATE_SCHEMA:Extend("BankingButtonsFrameState")
	:AddBooleanField("isWarbank", false)
	:AddBooleanField("canRestoreBags", false)
	:AddOptionalEnumField("activeMove", EnumTypes.BANKING_MOVE_TYPE)
	:Commit()
BankingButtonsFrame:_AddActionScripts("OnButtonClick")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function BankingButtonsFrame:__init()
	self.__super:__init()
	Banking.RegisterFrameCallback(self:__closure("_HandleBankFrameCallback"))
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
end

function BankingButtonsFrame:Acquire()
	self.__super:Acquire()
	self.__super:SetNavCallback(self:__closure("_GetButtons"))
	for _, path in ipairs(PATHS) do
		self.__super:AddPath(path)
	end
end

---@private
function BankingButtonsFrame:AddPath()
	error("Cannot call on BankingButtonsFrame", 2)
end

---@private
function BankingButtonsFrame:SetNavCallback()
	error("Cannot call on BankingButtonsFrame", 2)
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param manager UIManager<BankingButtonsFrameState>
---@param state BankingButtonsFrameState
function BankingButtonsFrame.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_HANDLE_MOVE_CLICK" then
		local moveType = ...
		self:_SendActionScript("OnButtonClick", moveType)
	else
		error("Unknown action: "..tostring(action))
	end
end

function BankingButtonsFrame.__private:_GetButtons(_, path)
	local frame = nil
	for _ in self._state:WithAutoStorePaused() do
		if path == "Warehousing" then
			frame = UIElements.New("BaseFrame", "buttons")
				:SetLayout("VERTICAL")
				:SetManager(self._childManager)
				:AddChild(UIElements.New("BaseFrame", "row1")
					:SetLayout("HORIZONTAL")
					:AddChild(self:_CreateMoveActionButton(EnumTypes.BANKING_MOVE_TYPE.WAREHOUSING_GROUPS_TO_BANK)
						:SetMargin(0, 8, 8, 0)
						:SetText(self._state:Publisher("isWarbank"):ReplaceBooleanWith(L["Move to Warbank"], L["Move to Bank"]))
					)
					:AddChild(self:_CreateMoveActionButton(EnumTypes.BANKING_MOVE_TYPE.WAREHOUSING_GROUPS_TO_BAGS)
						:SetText(L["Move to Bags"])
					)
				)
				:AddChild(self:_CreateMoveActionButton(EnumTypes.BANKING_MOVE_TYPE.WAREHOUSING_RESTOCK_BAGS)
					:SetText(L["Restock Bags"])
				)
				:AddChildIf(App.IsRetail() or App.IsForever(), self:_CreateMoveActionButton(EnumTypes.BANKING_MOVE_TYPE.WAREHOUSING_DEPOSIT_REAGENTS)
					:SetText(L["Deposit Reagents"])
				)
				:AddChildIf(App.IsRetail(), self:_CreateMoveActionButton(EnumTypes.BANKING_MOVE_TYPE.WAREHOUSING_DEPOSIT_WARBOUND)
					:SetText(L["Deposit Warbound Items"])
				)
				:AddChild(UIElements.New("BaseFrame", "row4")
					:SetLayout("HORIZONTAL")
					:AddChild(self:_CreateMoveActionButton(EnumTypes.BANKING_MOVE_TYPE.EMPTY_BAGS)
						:SetMargin(0, 8, 8, 0)
						:SetText(L["Empty Bags"])
					)
					:AddChild(self:_CreateMoveActionButton(EnumTypes.BANKING_MOVE_TYPE.RESTORE_BAGS)
						:SetText(L["Restore Bags"])
					)
				)
		elseif path == "Auctioning" then
			frame = UIElements.New("BaseFrame", "buttons")
				:SetLayout("VERTICAL")
				:SetManager(self._childManager)
				:AddChild(self:_CreateMoveActionButton(EnumTypes.BANKING_MOVE_TYPE.GROUPS_TO_BANK)
					:SetText(self._state:Publisher("isWarbank"):ReplaceBooleanWith(L["Move to Warbank"], L["Move to Bank"]))
				)
				:AddChild(self:_CreateMoveActionButton(EnumTypes.BANKING_MOVE_TYPE.AUCTIONING_POST_CAP_TO_BAGS)
					:SetText(L["Post Cap to Bags"])
				)
				:AddChild(self:_CreateMoveActionButton(EnumTypes.BANKING_MOVE_TYPE.AUCTIONING_SHORTFALL_TO_BAGS)
					:SetText(L["Shortfall to Bags"])
				)
				:AddChild(self:_CreateMoveActionButton(EnumTypes.BANKING_MOVE_TYPE.AUCTIONING_MAX_EXPIRES_TO_BANK)
					:SetText(L["Max Expires to Bank"])
				)
		elseif path == "Mailing" then
			frame = UIElements.New("BaseFrame", "buttons")
				:SetLayout("VERTICAL")
				:SetManager(self._childManager)
				:AddChild(self:_CreateMoveActionButton(EnumTypes.BANKING_MOVE_TYPE.GROUPS_TO_BANK)
					:SetText(self._state:Publisher("isWarbank"):ReplaceBooleanWith(L["Move to Warbank"], L["Move to Bank"]))
				)
				:AddChild(self:_CreateMoveActionButton(EnumTypes.BANKING_MOVE_TYPE.MAILING_NON_GROUP_TO_BANK)
					:SetText(L["Ungrouped to Bank"])
				)
				:AddChild(self:_CreateMoveActionButton(EnumTypes.BANKING_MOVE_TYPE.MAILING_TARGET_SHORTFALL_TO_BAGS)
					:SetText(L["Target Shortfall to Bags"])
				)
				:AddChild(UIElements.New("BaseFrame", "row4")
					:SetLayout("HORIZONTAL")
					:AddChild(self:_CreateMoveActionButton(EnumTypes.BANKING_MOVE_TYPE.EMPTY_BAGS)
						:SetMargin(0, 8, 8, 0)
						:SetText(L["Empty Bags"])
					)
					:AddChild(self:_CreateMoveActionButton(EnumTypes.BANKING_MOVE_TYPE.RESTORE_BAGS)
						:SetText(L["Restore Bags"])
					)
				)
		else
			error("Unexpected path: "..tostring(path))
		end
	end
	return frame
end

function BankingButtonsFrame.__private:_CreateMoveActionButton(moveType)
	local disabledPublisher = nil
	if moveType == EnumTypes.BANKING_MOVE_TYPE.RESTORE_BAGS then
		disabledPublisher = self._state:Publisher([[activeMove or not canRestoreBags]])
	else
		disabledPublisher = self._state:Publisher("activeMove"):ToBooleanNotEquals(nil)
	end
	return UIElements.New("BankingMoveButton", "button_"..tostring(moveType))
		:SetMargin(0, 0, 8, 0)
		:SetMoveType(moveType)
		:SetDisabled(disabledPublisher:IgnoreDuplicates())
		:SetPressed(self._state:Publisher("activeMove"):ToBooleanEquals(moveType))
		:SetAction("OnClick", "ACTION_HANDLE_MOVE_CLICK")
end

function BankingButtonsFrame.__private:_HandleBankFrameCallback(openFrame)
	self._state.isWarbank = openFrame == Banking.FRAME.CONTAINER.WARBANK
	self._state.canRestoreBags = openFrame and Banking.CanRestoreBags() or false
end
