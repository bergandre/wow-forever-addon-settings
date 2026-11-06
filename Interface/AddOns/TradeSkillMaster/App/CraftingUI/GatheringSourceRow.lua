-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local TEXT_COLOR_LOOKUP = {
	DISABLED = "on/surface%40",
	DRAGGING = "accent/main",
	NORMAL = "on/surface",
}



-- ============================================================================
-- Element Definition
-- ============================================================================

local GatheringSourceRow = UIElements.Define("GatheringSourceRow", "BaseFrame")
GatheringSourceRow._STATE_SCHEMA = GatheringSourceRow._STATE_SCHEMA:Extend("GatheringSourceRowState")
	:AddDeferredUIElementField("titleFrame", "BaseFrame")
	:AddOptionalStringField("source")
	:AddNumberField("num", 0)
	:AddStringField("name", "")
	:AddBooleanField("isDragging", false)
	:AddBooleanField("disabled", false)
	:Commit()
GatheringSourceRow:_AddActionScripts("OnDraggingDone")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function GatheringSourceRow:__init()
	self.__super:__init()
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
end

function GatheringSourceRow:Acquire()
	self.__super:Acquire()
	self
		:SetLayout("HORIZONTAL")
	for _ in self._state:WithAutoStorePaused() do
		local draggingPublisher = self._state:Publisher("isDragging")
			:Share()
		self
			:SetRelativeLevel(draggingPublisher:ReplaceBooleanWith(20, 1))
			:AddChild(UIElements.New("Text", "num")
				:SetWidth(20)
				:SetMargin(2, 8, 0, 0)
				:SetFont("BODY_BODY1_EXTRABOLD")
				:SetText(self._state:Publisher([[disabled and "" or num]]))
			)
			:AddChild(UIElements.New("BaseFrame", "title")
				:SetLayout("HORIZONTAL")
				:SetPadding(0, 8, 0, 0)
				:SetWidth(draggingPublisher:ReplaceBooleanWith(200, nil))
				:SetRoundedBackgroundColor("container/high")
				:BindElement(self._state, "titleFrame")
				:SetManager(self._childManager)
				:AddChildNoLayout(UIElements.New("BaseButton", "dragFrame")
					:SetSize(15, 24)
					:AddAnchor("LEFT", 1, 0)
					:SetScript("OnMouseDown", self._childManager:CallbackToProcessAction("ACTION_START_DRAGGING"))
					:SetScript("OnMouseUp", self._childManager:CallbackToProcessAction("ACTION_STOP_DRAGGING"))
				)
				:AddChild(UIElements.New("BaseFrame", "handleBackground")
					:SetSize(18, 28)
					:SetRoundedBackgroundColor("container/medium")
					-- Draw a line along the right to hide the rounded corners on the right of the handle
					:AddChildNoLayout(UIElements.New("BaseTexture", "line")
						:AddAnchor("TOPRIGHT")
						:AddAnchor("BOTTOMRIGHT")
						:SetWidth(6)
						:SetColor("container/medium")
					)
					:AddChildNoLayout(UIElements.New("BaseTexture", "texture")
						:AddAnchor("LEFT")
						:SetTextureAndSize("iconPack.18x18/Grip")
					)
				)
				:AddChild(UIElements.New("Text", "name")
					:SetWidth("AUTO")
					:SetMargin(8, 0, 0, 0)
					:SetFont("BODY_SMALL")
					:SetText(self._state:Publisher("name"))
					:SetTextColor(self._state:Publisher([[(isDragging and "DRAGGING") or (disabled and "DISABLED") or "NORMAL"]]):Map(TEXT_COLOR_LOOKUP))
				)
			)
			:AddCancellable(draggingPublisher:EndShare())
	end
end

---Configures the gathering source row.
---@param source string The source
---@param num number The number
---@param name string The name
---@return self
function GatheringSourceRow:Configure(source, num, name)
	self._state.source = source
	self._state.num = num
	self._state.name = name
	return self
end

---Sets the disabled state.
---@param disabled boolean Whether or not the row is disabled
---@return self
function GatheringSourceRow:SetDisabled(disabled)
	self._state.disabled = disabled
	return self
end

---Gets the source.
---@return string
function GatheringSourceRow:GetSource()
	local source = self._state.source
	assert(source)
	return source
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param manager UIManager<GatheringSourceRowState>
---@param state GatheringSourceRowState
function GatheringSourceRow.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_START_DRAGGING" then
		state.titleFrame:StartMoving()
		state.isDragging = true
		state.titleFrame:Draw()
	elseif action == "ACTION_STOP_DRAGGING" then
		state.isDragging = false
		state.titleFrame:StopMovingOrSizing()
		local container = self:GetParentElement() --[[@as BaseFrame]]
		-- TODO: Refactor
		local targetElement = nil
		for _, v in container:LayoutChildrenIterator() do
			---@cast v BaseFrame
			if v ~= self and v:IsMouseOver(true) then
				targetElement = v
			end
		end
		self:_SendActionScript("OnDraggingDone", state.source, targetElement)
	else
		error("Unknown action: "..tostring(action))
	end
end
