-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local UIElements = LibTSMUI:Include("UIElements")



-- ============================================================================
-- Element Definition
-- ============================================================================

local TaskListCategory = ComponentRegistry.Define("TaskListCategory", "BaseFrame")
TaskListCategory._STATE_SCHEMA = TaskListCategory._STATE_SCHEMA:Extend("TaskListCategoryState")
	:AddDeferredUIElementField("childrenFrame", "BaseFrame")
	:AddOptionalStringField("category")
	:AddBooleanField("expanded", true)
	:AddNumberField("numTasks", 0)
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function TaskListCategory:__init()
	self.__super:__init()
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
end

function TaskListCategory:Acquire()
	self.__super:Acquire()
	self:SetLayout("VERTICAL")
	for _ in self._state:WithAutoStorePaused() do
		local expandedPublisher = self._state:Publisher("expanded")
			:Share()
		self:AddChild(UIElements.New("BaseFrame", "line")
			:SetLayout("HORIZONTAL")
			:SetHeight(28)
			:SetMargin(4, 4, 0, 2)
			:SetManager(self._childManager)
			:AddChild(UIElements.New("BaseButton", "expanderBtn")
				:SetBackgroundAndSize(expandedPublisher:ReplaceBooleanWith("iconPack.18x18/Caret/Down", "iconPack.18x18/Caret/Right"))
				:SetAction("OnClick", "ACTION_EXPANDER_CLICKED")
			)
			:AddChild(UIElements.New("Text", "desc")
				:SetWidth("AUTO")
				:SetMargin(2, 4, 0, 0)
				:SetFont("BODY_BODY1_EXTRABOLD")
				:SetTextColor("on/surface")
				:SetText(self._state:Publisher("category"):IgnoreNil())
			)
			:AddChild(UIElements.New("Text", "count")
				:SetFont("BODY_SMALL_SEMIBOLD")
				:SetText(self._state:Publisher("numTasks"):ToStringFormat("(%d)"))
			)
		)
		self:AddChild(UIElements.New("BaseFrame", "children")
			:SetLayout("VERTICAL")
			:BindElement(self._state, "childrenFrame")
			:SetManager(self._childManager)
			:SetShown(expandedPublisher)
		)
		self:AddCancellable(expandedPublisher:EndShare())
	end
end

---Configures the category line.
---@param category string The category text
---@param contextTable table<string,boolean> The context table to store the collapsed state
---@param numTasks number The number of tasks within the category
---@return self
function TaskListCategory:Configure(category, contextTable, numTasks)
	assert(not self._state.category)
	self._state.category = category
	self._state.expanded = not contextTable[category]
	self._state.numTasks = numTasks
	self._state:Publisher("expanded")
		:InvertBoolean()
		:AssignToTableKey(contextTable, category)
	return self
end

---Adds a child to the category children frame.
---@param child Element
---@return self
function TaskListCategory:AddCategoryChild(child)
	self._state.childrenFrame:AddChild(child)
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param manager UIManager<TaskListCategoryState>
---@param state TaskListCategoryState
function TaskListCategory.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_EXPANDER_CLICKED" then
		state.expanded = not state.expanded
		self:DrawBaseElement()
	else
		error("Unknown action: "..tostring(action))
	end
end
