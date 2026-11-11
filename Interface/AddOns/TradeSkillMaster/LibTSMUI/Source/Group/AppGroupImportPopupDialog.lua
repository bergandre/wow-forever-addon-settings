-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local UIElements = LibTSMUI:Include("UIElements")
local CustomString = LibTSMUI:From("LibTSMTypes"):Include("CustomString")
local GroupImport = LibTSMUI:From("LibTSMTypes"):IncludeClassType("GroupImport")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local private = {
	importObj = nil, ---@type GroupImport?
}
local IGNORED_OPERATION_TYPES = { "Mailing" }



-- ============================================================================
-- Element Definition
-- ============================================================================

local AppGroupImportPopupDialog = ComponentRegistry.Define("AppGroupImportPopupDialog", "PopupDialog")
AppGroupImportPopupDialog._STATE_SCHEMA = AppGroupImportPopupDialog._STATE_SCHEMA:Extend("AppGroupImportPopupDialogState")
	:AddDeferredStringField("groupImportId")
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function AppGroupImportPopupDialog:__init()
	self.__super:__init()
	self._closeCallback = nil ---@type fun(id: string, shouldReview: boolean)!
end

function AppGroupImportPopupDialog:Acquire()
	self.__super:Acquire()
	self._state.buttonsFrame
		:AddChild(UIElements.New("Spacer", "spacer"))
		:AddChild(UIElements.New("SmallPrimaryActionButton", "reviewBtn")
			:SetWidth(150)
			:SetText(L["Review"])
			:SetAction("OnClick", "ACTION_REVIEW")
		)
		:AddChild(UIElements.New("SmallSecondaryActionButton", "laterBtn")
			:SetWidth(150)
			:SetMargin(16, 0, 0, 0)
			:SetText(L["Later"])
			:SetAction("OnClick", "ACTION_LATER")
		)
		:AddChild(UIElements.New("Spacer", "spacer"))
end

function AppGroupImportPopupDialog:Release()
	self._closeCallback = nil
	self.__super:Release()
end

---Configures the dialog.
---@param groupImport AppGroupImport The group import sent from the website
---@param closeCallback fun(id: string, shouldReview: boolean) The callback for when the dialog is closed
---@return self
function AppGroupImportPopupDialog:Configure(groupImport, closeCallback)
	self._state.groupImportId = groupImport.id
	self._closeCallback = closeCallback
	local groupText = Theme.GetGroupColor(1):ColorText(groupImport.name)
	if not private.importObj then
		private.importObj = GroupImport.New(L["Imported Group"], CustomString.IsCustomSourceRegistered, IGNORED_OPERATION_TYPES)
	end
	if private.importObj:Process(groupImport.importString) then
		local numItems, _, _, numOperations = private.importObj:GetTotals()
		local itemsText = numItems == 1 and L["1 item"] or format(L["%d items"], numItems)
		local operationsText = numOperations == 1 and L["1 operation"] or format(L["%d operations"], numOperations)
		groupText = format("%s (%s, %s)", groupText, itemsText, operationsText)
	end
	private.importObj:Reset()
	self:SetMessage(strjoin("\n", L["Your TSM account sent you a group from the website:"], groupText, L["Would you like to review and import it?"]))
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param manager UIManager<AppGroupImportPopupDialogState>
---@param state AppGroupImportPopupDialogState
function AppGroupImportPopupDialog.__protected:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_REVIEW" or action == "ACTION_LATER" then
		local id, closeCallback = state.groupImportId, self._closeCallback
		manager:ProcessAction("ACTION_CLOSE")
		closeCallback(id, action == "ACTION_REVIEW")
	else
		return self.__super:_ActionHandler(manager, state, action, ...)
	end
end
