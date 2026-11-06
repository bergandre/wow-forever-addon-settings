-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local UIElements = App:From("LibTSMUI"):Include("UIElements")



-- ============================================================================
-- Element Definition
-- ============================================================================

local CraftingQueueEditDialog = UIElements.Define("CraftingQueueEditDialog", "BaseFrame")
CraftingQueueEditDialog._STATE_SCHEMA = CraftingQueueEditDialog._STATE_SCHEMA:Extend("CraftingQueueEditDialogState")
	:AddDeferredUIElementField("input", "NumberInput")
	:AddStringField("name", "")
	:AddOptionalNumberField("texture")
	:AddOptionalStringField("tooltip")
	:Commit()



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function CraftingQueueEditDialog:__init()
	self.__super:__init()
	self._value = nil
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
end

function CraftingQueueEditDialog:Acquire()
	self.__super:Acquire()
	self
		:SetLayout("HORIZONTAL")
		:SetBackgroundColor("container/low")
	for _ in self._state:WithAutoStorePaused() do
		self
			:AddChild(UIElements.New("BaseButton", "icon")
				:SetSize(12, 12)
				:SetMargin(16, 4, 0, 0)
				:SetBackground(self._state:Publisher("texture"))
				:SetTooltip(self._state:Publisher("tooltip"))
			)
			:AddChild(UIElements.New("Text", "name")
				:SetWidth("AUTO")
				:SetFont("ITEM_XSMALL")
				:SetText(self._state:Publisher("name"))
			)
			:AddChild(UIElements.New("Spacer", "spacer"))
			:AddChild(UIElements.New("NumberInput", "input")
				:SetWidth(75)
				:SetJustifyH("CENTER")
				:BindElement(self._state, "input")
				:SetManager(self._childManager)
				:SetSubAddEnabled(true)
				:SetValidRange(1, 9999)
				:SetAction("OnFocusLost", "ACTION_HANDLE_FOCUS_LOST")
				:SetAction("OnValueChanged", "ACTION_HANDLE_VALUE_CHANGED")
			)
	end
end

function CraftingQueueEditDialog:Release()
	self.__super:Release()
	-- Need to clear the value after the dialog is hidden
	self._value = nil
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Sets the info to display in the dialog.
---@param name string The item name
---@param texture number The item texture
---@param tooltip string The item tooltip
---@param num number The input quantity
---@return self
function CraftingQueueEditDialog:SetInfo(name, texture, tooltip, num)
	self._value = num
	self._state.name = name
	self._state.texture = texture
	self._state.tooltip = tooltip
	self._state.input:SetValue(num)
	return self
end

---Sets the input to be focused.
function CraftingQueueEditDialog:Focus()
	self._state.input:SetFocused(true)
end

---Gets the current value of the input.
---@return number
function CraftingQueueEditDialog:GetValue()
	assert(self._value ~= nil)
	return self._value
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param manager UIManager<CraftingQueueEditDialogState>
---@param state CraftingQueueEditDialogState
function CraftingQueueEditDialog.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_HANDLE_FOCUS_LOST" then
		self:GetBaseElement():HideDialog()
	elseif action == "ACTION_HANDLE_VALUE_CHANGED" then
		self._value = state.input:GetValue()
	else
		error("Unknown action: "..tostring(action))
	end
end
