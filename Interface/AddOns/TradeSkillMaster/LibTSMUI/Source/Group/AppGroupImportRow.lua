-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local UIElements = LibTSMUI:Include("UIElements")



-- ============================================================================
-- Element Definition
-- ============================================================================

local AppGroupImportRow = ComponentRegistry.Define("AppGroupImportRow", "BaseFrame")
AppGroupImportRow._STATE_SCHEMA = AppGroupImportRow._STATE_SCHEMA:Extend("AppGroupImportRowState")
	:AddStringField("groupImportId", "")
	:AddStringField("text", "")
	:Commit()
AppGroupImportRow:_AddActionScripts("OnReview")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function AppGroupImportRow:__init()
	self.__super:__init()
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
end

function AppGroupImportRow:Acquire()
	self.__super:Acquire()
	self:SetLayout("HORIZONTAL")
	for _ in self._state:WithAutoStorePaused() do
		self:AddChild(UIElements.New("Text", "text")
			:SetFont("BODY_SMALL")
			:SetText(self._state:Publisher("text"))
		)
		self:AddChild(UIElements.New("SmallSecondaryActionButton", "reviewBtn")
			:SetWidth(100)
			:SetMargin(8, 0, 0, 0)
			:SetText(L["Review"])
			:SetManager(self._childManager)
			:SetAction("OnClick", "ACTION_REVIEW")
		)
	end
end

---Configures the row.
---@param id string The id of the group import
---@param text string The text describing the group import
---@return self
function AppGroupImportRow:Configure(id, text)
	self._state.groupImportId = id
	self._state.text = text
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param manager UIManager<AppGroupImportRowState>
---@param state AppGroupImportRowState
function AppGroupImportRow.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_REVIEW" then
		self:_SendActionScript("OnReview", state.groupImportId)
	else
		error("Unknown action: "..tostring(action))
	end
end
