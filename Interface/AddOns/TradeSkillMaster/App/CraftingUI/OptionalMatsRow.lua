-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local App = select(2, ...).App
local L = App.Locale.GetTable()
local CraftString = App:From("LibTSMTypes"):Include("Crafting.CraftString")
local MatQuantityString = App:From("LibTSMTypes"):Include("Crafting.MatQuantityString")
local MatString = App:From("LibTSMTypes"):Include("Crafting.MatString")
local RecipeString = App:From("LibTSMTypes"):Include("Crafting.RecipeString")
local Profession = App:From("LibTSMService"):Include("Profession")
local UIElements = App:From("LibTSMUI"):Include("UIElements")
local private = {
	optionalMatsTemp = {},
}
local MAX_NUM_OPTIONAL_MATS = 5
local MAX_NUM_FINISHING_MATS = 3
local SLOT_SIZE = 16
local SLOT_SPACING = 4



-- ============================================================================
-- Element Definition
-- ============================================================================

local OptionalMatsRow = UIElements.Define("OptionalMatsRow", "BaseFrame")
OptionalMatsRow._STATE_SCHEMA = OptionalMatsRow._STATE_SCHEMA:Extend("OptionalMatsRowState")
	:AddDeferredUIElementField("optionalLabel", "Text")
	:AddDeferredUIElementField("finishingLabel", "Text")
	:AddOptionalStringField("recipeString")
	:AddNumberField("numOptionalMats", 0)
	:AddNumberField("numFinishingMats", 0)
	:Commit()
OptionalMatsRow:_AddActionScripts("OnRecipeStringChanged")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function OptionalMatsRow:__init()
	self.__super:__init()
	self._childManager = self:_CreateUIManager(self:__closure("_ActionHandler"))
		:SuppressActionLog("ACTION_HANDLE_ITEM_SELECTION_CHANGED")

	-- Set up some computed state properties
	self._state:Publisher("recipeString")
		:MapNonNil(CraftString.FromRecipeString)
		:Share()
		:MapNonNil(Profession.GetNumOptionalMats, MatString.TYPE.OPTIONAL)
		:CoalesceNil(0)
		:AssignToTableKey(self._state, "numOptionalMats")
		:MapNonNil(Profession.GetNumOptionalMats, MatString.TYPE.FINISHING)
		:CoalesceNil(0)
		:AssignToTableKey(self._state, "numFinishingMats")
		:EndShare()
end

function OptionalMatsRow:Acquire()
	self.__super:Acquire()
	self:SetLayout("HORIZONTAL")

	for _ in self._state:WithAutoStorePaused() do
		local numOptionalMatsPublisher = self._state:Publisher("numOptionalMats")
			:Share()
		local numFinishingMatsPublisher = self._state:Publisher("numFinishingMats")
			:Share()
		local recipeStringPublisher = self._state:Publisher("recipeString")
			:IgnoreNil()
			:Share()

		local content = UIElements.New("BaseFrame", "content")
			:SetLayout("HORIZONTAL")
			:SetMargin(0, 24, 0, 0)
			:SetPadding(8, 8, 2, 2)
			:SetRoundedBackgroundColor("container/low")
			:SetShown(self._state:Publisher([[numOptionalMats + numFinishingMats > 0]]))
		self:AddChild(content)

		-- Add optional mats
		content:AddChild(UIElements.New("Text", "optionalLabel")
			:SetFont("BODY_SMALL_SEMIBOLD")
			:BindElement(self._state, "optionalLabel")
			:SetText(L["Optional"]..":")
			:SetShown(numOptionalMatsPublisher:ToBooleanNotEquals(0))
		)
		for i = 1, MAX_NUM_OPTIONAL_MATS do
			content:AddChild(UIElements.New("ItemSelector", "optionalMat"..i)
				:SetSize(SLOT_SIZE, SLOT_SIZE)
				:SetMargin(SLOT_SPACING, 0, 0, 0)
				:SetCompact(true)
				:SetManager(self._childManager)
				:SetOptionalMatInfo(MatString.TYPE.OPTIONAL, i)
				:SetOptionalMatRecipeString(recipeStringPublisher)
				:SetAction("OnSelectionChanged", "ACTION_HANDLE_ITEM_SELECTION_CHANGED")
				:SetShown(numOptionalMatsPublisher:ToBooleanGreaterThanOrEquals(i))
			)
		end

		content:AddChild(UIElements.New("Spacer", "groupSpacer")
			:SetWidth(8)
			:SetShown(self._state:Publisher([[numOptionalMats > 0 and numFinishingMats > 0]]))
		)

		-- Add finishing mats
		content:AddChild(UIElements.New("Text", "finishingLabel")
			:SetFont("BODY_SMALL_SEMIBOLD")
			:BindElement(self._state, "finishingLabel")
			:SetText(L["Finishing"]..":")
			:SetShown(numFinishingMatsPublisher:ToBooleanNotEquals(0))
		)
		for i = 1, MAX_NUM_FINISHING_MATS do
			content:AddChild(UIElements.New("ItemSelector", "finishingMat"..i)
				:SetSize(SLOT_SIZE, SLOT_SIZE)
				:SetMargin(SLOT_SPACING, 0, 0, 0)
				:SetCompact(true)
				:SetManager(self._childManager)
				:SetOptionalMatInfo(MatString.TYPE.FINISHING, i)
				:SetOptionalMatRecipeString(recipeStringPublisher)
				:SetAction("OnSelectionChanged", "ACTION_HANDLE_ITEM_SELECTION_CHANGED")
				:SetShown(numFinishingMatsPublisher:ToBooleanGreaterThanOrEquals(i))
			)
		end

		self:DrawPublisher(self._state:PublisherForKeys("numOptionalMats", "numFinishingMats"):ReplaceWith(nil))

		self:AddCancellable(numOptionalMatsPublisher:EndShare())
		self:AddCancellable(numFinishingMatsPublisher:EndShare())
		self:AddCancellable(recipeStringPublisher:EndShare())
	end
end

function OptionalMatsRow:Draw()
	self._state.optionalLabel:SetWidth(ceil(self._state.optionalLabel:GetStringWidth()))
	self._state.finishingLabel:SetWidth(ceil(self._state.finishingLabel:GetStringWidth()))
	self.__super:Draw()
end

---Sets the recipe string to display optional mats for.
---@param value string|ReactivePublisherSchemaBase The recipe string or a publisher
---@return self
function OptionalMatsRow:SetRecipeString(value)
	if value == nil or type(value) == "string" then
		self._state.recipeString = value
	else
		self:_MethodPublisher(value, "SetRecipeString")
	end
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param manager UIManager<OptionalMatsRowState>
---@param state OptionalMatsRowState
function OptionalMatsRow.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_HANDLE_ITEM_SELECTION_CHANGED" then
		local itemString, matString = ...
		if not matString then
			return
		end
		local slotId = MatString.GetSlotId(matString)
		assert(slotId)

		local recipeString = state.recipeString
		assert(recipeString)
		assert(not next(private.optionalMatsTemp))
		if itemString then
			-- All optional mats are currently single quantity
			local matQuantityString = MatQuantityString.GetForSingleItem(itemString, 1)
			for _, existingSlotId, existingMatQuantityString in RecipeString.OptionalMatIterator(recipeString) do
				-- Remove this item from any existing slots its in
				if existingMatQuantityString ~= matQuantityString then
					private.optionalMatsTemp[existingSlotId] = existingMatQuantityString
				end
			end
			private.optionalMatsTemp[slotId] = matQuantityString
		else
			for _, existingSlotId, existingMatQuantityString in RecipeString.OptionalMatIterator(recipeString) do
				if existingSlotId ~= slotId then
					private.optionalMatsTemp[existingSlotId] = existingMatQuantityString
				end
			end
		end
		recipeString = RecipeString.SetOptionalMats(recipeString, private.optionalMatsTemp)
		wipe(private.optionalMatsTemp)
		if recipeString == state.recipeString then
			return
		end
		state.recipeString = recipeString
		self:_SendActionScript("OnRecipeStringChanged", state.recipeString)
	else
		error("Unknown action: "..tostring(action))
	end
end
