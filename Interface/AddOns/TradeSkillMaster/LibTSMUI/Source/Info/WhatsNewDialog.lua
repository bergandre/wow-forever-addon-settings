-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local UIElements = LibTSMUI:Include("UIElements")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local Analytics = LibTSMUI:From("LibTSMService"):Include("Util.Analytics")
local private = {
	contentTemp = {},
}

---@class WhatsNewContentLine
---@field label string
---@field content string



-- ============================================================================
-- Element Definition
-- ============================================================================

local WhatsNewDialog = ComponentRegistry.Define("WhatsNewDialog", "BaseFrame")
WhatsNewDialog._STATE_SCHEMA = WhatsNewDialog._STATE_SCHEMA:Extend("WhatsNewDialogState")
	:AddStringField("content", "")
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function WhatsNewDialog:__init()
	self.__super:__init()
	self._showTime = nil
	self._version = nil
	self._settings = nil ---@type SettingsView!
	self._settingKey = nil ---@type string!
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
end

function WhatsNewDialog:Acquire()
	self.__super:Acquire()

	-- Strip the patch from the version
	local versionStr = LibTSMUI.GetVersionStr()
	versionStr = strmatch(versionStr, "^v%d+%.%d+") or versionStr

	self:SetLayout("VERTICAL")
	self:SetSize(650, 500)
	self:SetPadding(12, 12, 0, 12)
	self:SetRoundedBackgroundColor("container/low")
	self:SetBorderColor("outline/variant")
	self:SetManager(self._childManager)
	for _ in self._state:WithAutoStorePaused() do
		self:AddChild(UIElements.New("BaseFrame", "header")
			:SetLayout("HORIZONTAL")
			:SetHeight(24)
			:SetMargin(0, 0, 8, 16)
			:AddChild(UIElements.New("Spacer", "spacer")
				:SetWidth(20)
			)
			:AddChild(UIElements.New("Text", "title")
				:SetJustifyH("CENTER")
				:SetFont("BODY_BODY1_EXTRABOLD")
				:SetFormattedText(L["TSM %s - What's New"], versionStr)
			)
			:AddChild(UIElements.New("BaseButton", "closeBtn")
				:SetMargin(0, -4, 0, 0)
				:SetBackgroundAndSize("iconPack.24x24/Close/Default")
				:SetAction("OnClick", "ACTION_CLOSE")
			)
		)
		self:AddChild(UIElements.New("BaseScrollFrame", "body")
			:AddChild(UIElements.New("Text", "content")
				:SetHeight(400)
				:SetFont("BODY_SMALL")
				:SetText(self._state:Publisher("content"))
			)
		)
		self:AddChild(UIElements.New("Text", "footer")
			:SetHeight(20)
			:SetMargin(0, 0, 12, 0)
			:SetFont("BODY_XSMALL")
			:SetFormattedText(L["For more info, visit %s. For help, join us in Discord: %s."], Theme.GetColor("accent/main"):ColorText("blog.tradeskillmaster.com"), Theme.GetColor("accent/main"):ColorText("discord.gg/woweconomy"))
		)
	end
end

function WhatsNewDialog:Release()
	self._showTime = nil
	self._version = nil
	self._settings = nil
	self._settingKey = nil
	self.__super:Release()
end

---Configures the dialog.
---@param version number The version being displayed
---@param contentLines WhatsNewContentLine[] The content lines
---@return self
function WhatsNewDialog:Configure(version, contentLines)
	self._version = version
	self._showTime = LibTSMUI.GetTime()
	assert(not next(private.contentTemp))
	for _, line in ipairs(contentLines) do
		tinsert(private.contentTemp, Theme.GetColor("accent/main"):ColorText(line.label).." "..line.content)
	end
	self._state.content = table.concat(private.contentTemp, "\n\n")
	wipe(private.contentTemp)
	return self
end

---Sets the settings view and key for the version.
---@param settings SettingsView The settings object
---@param key string The settings key
---@return self
function WhatsNewDialog:SetSettings(settings, key)
	self._settings = settings
	self._settingKey = key
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param manager UIManager<WhatsNewDialogState>
---@param state WhatsNewDialogState
function WhatsNewDialog.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_CLOSE" then
		assert(self._version)
		self._settings[self._settingKey] = self._version
		assert(self._showTime)
		Analytics.Action("WHATS_NEW_TIME", floor((LibTSMUI.GetTime() - self._showTime) * 1000), self._version)
		self:GetBaseElement():HideDialog()
	else
		error("Unknown action: "..tostring(action))
	end
end
