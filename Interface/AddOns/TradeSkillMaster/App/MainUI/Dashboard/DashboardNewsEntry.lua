-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local Analytics = App:From("LibTSMService"):Include("Util.Analytics")
local UIElements = App:From("LibTSMUI"):Include("UIElements")

---@event DashboardNewsEntryAction
---| "ACTION_SHOW_DIALOG"



-- ============================================================================
-- Element Definition
-- ============================================================================

local DashboardNewsEntry = UIElements.Define("DashboardNewsEntry", "BaseFrame")
DashboardNewsEntry._STATE_SCHEMA = DashboardNewsEntry._STATE_SCHEMA:Extend("DashboardNewsEntryState")
	:AddStringField("title", "")
	:AddStringField("content", "")
	:AddStringField("link", "")
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function DashboardNewsEntry:__init()
	self.__super:__init()
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
end

function DashboardNewsEntry:Acquire()
	self.__super:Acquire()
	self
		:SetLayout("VERTICAL")
		:SetPadding(8)
		:SetRoundedBackgroundColor("container/high")
	for _ in self._state:WithAutoStorePaused() do
		self
			:AddChild(UIElements.New("BaseFrame", "header")
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:AddChild(UIElements.New("Text", "title")
					:SetFont("BODY_BODY1_MEDIUM")
					:SetText(self._state:Publisher("title"))
				)
				:AddChild(UIElements.New("BaseTexture", "icon")
					:SetMargin(8, 5, 0, 0)
					:SetTextureAndSize("iconPack.14x14/Popout#on/surface")
				)
			)
			:AddChild(UIElements.New("Text", "content")
				:SetHeight(52)
				:SetMargin(0, 0, 4, 0)
				:SetFont("BODY_XSMALL")
				:SetJustifyV("TOP")
				:SetText(self._state:Publisher("content"))
			)
			:AddChildNoLayout(UIElements.New("BaseButton", "btn")
				:AddAnchor("TOPLEFT")
				:AddAnchor("BOTTOMRIGHT")
				:SetManager(self._childManager)
				:SetAction("OnClick", "ACTION_SHOW_DIALOG")
			)
	end
end

---Configures the news entry.
---@param entry AppInfoNewsEntry The news entry
---@return self
function DashboardNewsEntry:Configure(entry)
	self._state.title = entry.title
	self._state.content = entry.content
	self._state.link = entry.link
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param manager UIManager<DashboardNewsEntryState>
---@param state DashboardNewsEntryState
---@param action DashboardNewsEntryAction
---@param ... params<DashboardNewsEntryAction>
function DashboardNewsEntry.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_SHOW_DIALOG" then
		Analytics.Action("NEWS_READ_MORE", state.title)
		self:GetBaseElement():ShowDialogFrame(UIElements.New("DashboardNewsDialog", "newsDialog")
			:SetSize(600, 450)
			:AddAnchor("CENTER")
			:Configure(state.title, state.content, state.link)
		)
	else
		error("Unknown action: "..tostring(action))
	end
end
