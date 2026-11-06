-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local private = {}

---@event DashboardNewsDialogAction
---| "ACTION_CLOSE"



-- ============================================================================
-- Element Definition
-- ============================================================================

local DashboardNewsDialog = UIElements.Define("DashboardNewsDialog", "BaseFrame")
DashboardNewsDialog._STATE_SCHEMA = DashboardNewsDialog._STATE_SCHEMA:Extend("DashboardNewsDialogState")
	:AddStringField("title", "")
	:AddStringField("content", "")
	:AddStringField("link", "")
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function DashboardNewsDialog:__init()
	self.__super:__init()
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
end

function DashboardNewsDialog:Acquire()
	self.__super:Acquire()
	self
		:SetLayout("VERTICAL")
		:SetPadding(16)
		:SetBackgroundColor("container/low")
		:SetBorderColor("outline/variant")
	for _ in self._state:WithAutoStorePaused() do
		self:AddChild(UIElements.New("Text", "title")
			:SetHeight(44)
			:SetMargin(0, 0, 0, 8)
			:SetFont("BODY_BODY1_EXTRABOLD")
			:SetJustifyH("CENTER")
			:SetText(self._state:Publisher("title"))
		)
		self:AddChild(UIElements.New("Input", "linkInput")
			:SetHeight(24)
			:SetMargin(0, 0, 0, 16)
			:SetValidateFunc(private.LinkValidateFunc, self._state)
			:SetValue(self._state:Publisher("link"))
		)
		self:AddChild(UIElements.New("Text", "content")
			:SetMargin(0, 0, 0, 16)
			:SetFont("BODY_XSMALL")
			:SetJustifyV("TOP")
			:SetText(self._state:Publisher("content"))
		)
		self:AddChild(UIElements.New("BaseFrame", "buttons")
			:SetLayout("HORIZONTAL")
			:SetHeight(28)
			:SetManager(self._childManager)
			:AddChild(UIElements.New("Spacer", "spacer"))
			:AddChild(UIElements.New("MediumPrimaryActionButton", "closeBtn")
				:SetWidth(126)
				:SetText(CLOSE)
				:SetAction("OnClick", "ACTION_CLOSE")
			)
		)
	end
end

---Configures the news entry to show.
---@param title string The title
---@param content string The content
---@param link string The link to the full article
---@return self
function DashboardNewsDialog:Configure(title, content, link)
	self._state.title = title
	self._state.content = content
	self._state.link = link
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param manager UIManager<DashboardNewsDialogState>
---@param state DashboardNewsDialogState
---@param action DashboardNewsDialogAction
---@param ... params<DashboardNewsDialogAction>
function DashboardNewsDialog.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_CLOSE" then
		self:GetBaseElement():HideDialog()
	else
		error("Unknown action: "..tostring(action))
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

---@param state DashboardNewsDialogState
function private.LinkValidateFunc(value, state)
	return value == state.link
end
