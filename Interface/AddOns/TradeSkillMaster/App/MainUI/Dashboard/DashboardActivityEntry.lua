-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local Money = App:From("LibTSMUtil"):Include("UI.Money")
local TimeFormat = App:From("LibTSMWoW"):Include("UI.TimeFormat")
local Activity = App:From("LibTSMService"):Include("Ledger.Activity")
local Theme = App:From("LibTSMService"):Include("UI.Theme")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local private = {}
local LINE_INDENT = 16
local LINE_NAMES = {
	[Activity.LINE.EXPIRED] = L["Expired"],
	[Activity.LINE.CANCELLED] = L["Cancelled"],
	[Activity.LINE.PURCHASED] = L["Purchased"],
	[Activity.LINE.SOLD] = L["Sold"],
}



-- ============================================================================
-- Element Definition
-- ============================================================================

local DashboardActivityEntry = UIElements.Define("DashboardActivityEntry", "BaseFrame")
DashboardActivityEntry._STATE_SCHEMA = DashboardActivityEntry._STATE_SCHEMA:Extend("DashboardActivityEntryState")
	:AddDeferredUIElementField("linesFrame", "BaseFrame")
	:AddStringField("player", "")
	:AddNumberField("time", 0)
	:AddNumberField("net", 0)
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function DashboardActivityEntry:Acquire()
	self.__super:Acquire()
	self
		:SetLayout("VERTICAL")
		:SetPadding(8, 8, 4, 8)
		:SetRoundedBackgroundColor("container/high")
	for _ in self._state:WithAutoStorePaused() do
		self
			:AddChild(UIElements.New("BaseFrame", "header")
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:AddChild(UIElements.New("BaseTexture", "icon")
					:SetMargin(0, 4, 0, 0)
					:SetTextureAndSize("iconPack.14x14/Mailing#on/surface")
				)
				:AddChild(UIElements.New("Text", "player")
					:SetFont("BODY_XSMALL")
					:SetText(self._state:Publisher("player"))
				)
				:AddChild(UIElements.New("Text", "time")
					:SetWidth("AUTO")
					:SetMargin(8, 0, 0, 0)
					:SetFont("BODY_XSMALL")
					:SetJustifyH("RIGHT")
					:SetText(self._state:PublisherForFunctionWithKeys(TimeFormat.Time, "time"))
				)
			)
			:AddChild(UIElements.New("BaseFrame", "lines")
				:SetLayout("VERTICAL")
				:SetMargin(LINE_INDENT, 0, 4, 0)
				:BindElement(self._state, "linesFrame")
			)
			:AddChild(UIElements.New("Text", "net")
				:SetHeight(16)
				:SetMargin(LINE_INDENT, 0, 8, 0)
				:SetFont("TABLE_XSMALL")
				:SetJustifyH("RIGHT")
				:SetShown(self._state:Publisher("net"):ToBooleanNotEquals(0))
				:SetText(self._state:PublisherForFunctionWithKeys(private.FormatNet, "net"))
			)
	end
end

---Configures the activity entry.
---@param id number The activity id
---@param player string The player name
---@param timestamp number The activity time
---@param net number The net amount of the activity
---@return self
function DashboardActivityEntry:Configure(id, player, timestamp, net)
	self._state.player = player
	self._state.time = timestamp
	self._state.net = net
	local query = Activity.CreateLineQuery()
		:BindParams(id)
	for _, kind, order, quantity, amount in query:Iterator("kind", "order", "quantity", "amount") do
		self:_AddLine(order, kind, quantity, amount)
	end
	query:Release()
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function DashboardActivityEntry.__private:_AddLine(order, kind, quantity, amount)
	self._state.linesFrame:AddChild(UIElements.New("BaseFrame", "line"..order)
		:SetLayout("HORIZONTAL")
		:SetHeight(20)
		:AddChild(UIElements.New("Text", "quantity")
			:SetWidth(26)
			:SetFont("TABLE_XSMALL")
			:SetJustifyH("RIGHT")
			:SetText(quantity)
		)
		:AddChild(UIElements.New("Text", "label")
			:SetMargin(8, 0, 0, 0)
			:SetFont("BODY_XSMALL")
			:SetTextColor("on/surface/low")
			:SetText(LINE_NAMES[kind])
		)
		:AddChild(UIElements.New("Text", "amount")
			:SetWidth("AUTO")
			:SetMargin(8, 0, 0, 0)
			:SetFont("TABLE_XSMALL")
			:SetJustifyH("RIGHT")
			:SetText(amount ~= 0 and Money.ToStringForUI(abs(amount)) or "")
		)
	)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.FormatNet(net)
	if net == 0 then
		return ""
	end
	local color = Theme.GetColor(net > 0 and "positive/main" or "error/main")
	return (net > 0 and color:ColorText("+") or "")..Money.ToStringForUI(net, color:GetTextColorPrefix())
end
